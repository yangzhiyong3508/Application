/**
 * 事件提醒调度
 *
 * 优先：reminderAgentManager 系统代理（官方推荐）
 * 回退：本地定时 + notificationManager（进程存活时有效）
 *
 * 设备日志显示 validCount=0 仍报 1700002，常见原因：
 * - slot 类型与官方示例不一致（应用 CONTENT_INFORMATION）
 * - 设备/模拟器对代理提醒支持不完整
 * 因此 publish 失败时自动走本地回退，保证功能可用。
 */

import common from '@ohos.app.ability.common'
import { BusinessError } from '@kit.BasicServicesKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  cloneReminder,
  computeAdvanceAt,
  shouldScheduleAdvance
} from './EventReminderLogic'
import {
  ABILITY_NAME,
  BUNDLE_NAME,
  EventReminder,
  INVALID_REMINDER_ID,
  NOTIFY_TITLE,
  REMINDER_STATUS_FIRED,
  REMINDER_STATUS_PENDING,
  ScheduleResult,
  SystemReminderStats
} from './EventReminderTypes'

const LOG_DOMAIN: number = 0x0E00
const LOG_TAG: string = 'EventReminder'

/** 本地倒计时句柄：key = localId + ':exact'|':advance' */
interface LocalTimerEntry {
  key: string
  timerId: number
  fireAt: number
  title: string
  isAdvance: boolean
  localId: string
}

export class EventReminderScheduler {
  private static slotReady: boolean = false
  private static localTimers: LocalTimerEntry[] = []
  /** 代理提醒是否可用；失败后降级为 false，避免反复刷 1700002 */
  private static agentUsable: boolean = true
  private static notificationIdSeq: number = 2000

  static async ensureNotificationReady(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context)
      hilog.info(LOG_DOMAIN, LOG_TAG, 'requestEnableNotification ok')
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'requestEnableNotification fail %{public}s', JSON.stringify(e))
    }
    await EventReminderScheduler.ensureSlots()
    return true
  }

  static async ensureSlotOnly(): Promise<void> {
    await EventReminderScheduler.ensureSlots()
  }

  private static async ensureSlots(): Promise<void> {
    if (EventReminderScheduler.slotReady) {
      return
    }
    // 官方示例使用 CONTENT_INFORMATION；同时尝试 SOCIAL 提高兼容
    const types: notificationManager.SlotType[] = [
      notificationManager.SlotType.CONTENT_INFORMATION,
      notificationManager.SlotType.SOCIAL_COMMUNICATION
    ]
    for (let i = 0; i < types.length; i++) {
      try {
        const slot: notificationManager.NotificationSlot = {
          notificationType: types[i]
        }
        await reminderAgentManager.addNotificationSlot(slot)
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'addNotificationSlot %{public}s', JSON.stringify(e))
      }
      try {
        await notificationManager.addSlot(types[i])
      } catch (e2) {
        // 部分 API 用 addSlot
      }
    }
    EventReminderScheduler.slotReady = true
  }

  static async cancelLinked(item: EventReminder): Promise<void> {
    await EventReminderScheduler.cancelOne(item.exactReminderId)
    await EventReminderScheduler.cancelOne(item.advanceReminderId)
    EventReminderScheduler.clearLocalTimersFor(item.id)
  }

  static async querySystemStats(): Promise<SystemReminderStats> {
    const stats: SystemReminderStats = {
      count: 0,
      ids: [],
      error: ''
    }
    try {
      const infos: Array<reminderAgentManager.ReminderInfo> =
        await reminderAgentManager.getAllValidReminders()
      stats.count = infos.length
      for (let i = 0; i < infos.length; i++) {
        stats.ids.push(infos[i].reminderId)
      }
    } catch (e) {
      stats.error = JSON.stringify(e)
      try {
        const oldList: Array<reminderAgentManager.ReminderRequest> =
          await reminderAgentManager.getValidReminders()
        stats.count = oldList.length
        stats.error = ''
      } catch (e2) {
        stats.error = JSON.stringify(e2)
      }
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'querySystemStats count=%{public}d agentUsable=%{public}s',
      stats.count, EventReminderScheduler.agentUsable ? '1' : '0')
    return stats
  }

  static async forceClearAll(): Promise<string> {
    let detail: string = ''
    const before: SystemReminderStats = await EventReminderScheduler.querySystemStats()
    detail = detail + 'before=' + before.count.toString() + ';'
    try {
      await reminderAgentManager.cancelAllReminders()
      detail = detail + 'cancelAll=ok;'
    } catch (e) {
      detail = detail + 'cancelAll=fail;'
    }
    try {
      const infos: Array<reminderAgentManager.ReminderInfo> =
        await reminderAgentManager.getAllValidReminders()
      for (let i = 0; i < infos.length; i++) {
        await EventReminderScheduler.cancelOne(infos[i].reminderId)
      }
      detail = detail + 'oneByOne=' + infos.length.toString() + ';'
    } catch (e) {
      detail = detail + 'oneByOne=fail;'
    }
    EventReminderScheduler.clearAllLocalTimers()
    const after: SystemReminderStats = await EventReminderScheduler.querySystemStats()
    detail = detail + 'after=' + after.count.toString()
    hilog.info(LOG_DOMAIN, LOG_TAG, 'forceClearAll %{public}s', detail)
    return detail
  }

  static async cancelAllSystemReminders(): Promise<void> {
    await EventReminderScheduler.forceClearAll()
  }

  static async cancelOrphanSystemReminders(_localList: EventReminder[]): Promise<number> {
    await EventReminderScheduler.forceClearAll()
    return 0
  }

  static async syncSystemWithLocal(localList: EventReminder[]): Promise<void> {
    // 本地无 pending 时清理系统 + 本地定时器
    let pending: number = 0
    for (let i = 0; i < localList.length; i++) {
      if (localList[i].status === REMINDER_STATUS_PENDING) {
        pending++
      }
    }
    if (pending === 0) {
      await EventReminderScheduler.forceClearAll()
      return
    }
    // 有 pending：为本地模式重建定时器（代理 id 若有效则保留）
    const now: number = Date.now()
    for (let i = 0; i < localList.length; i++) {
      const item: EventReminder = localList[i]
      if (item.status !== REMINDER_STATUS_PENDING || item.triggerAt <= now) {
        continue
      }
      // 仅本地模式（系统 id 无效）才挂 setTimeout
      if (item.exactReminderId < 0) {
        EventReminderScheduler.armLocalTimers(item, now)
      }
    }
  }

  /**
   * 保存一条：优先系统代理；失败则本地回退。
   * allowLimitRecovery=false 时只发布一条（重建用）。
   */
  static async schedule(
    item: EventReminder,
    now: number,
    localList: EventReminder[],
    allowLimitRecovery: boolean = true
  ): Promise<ScheduleResult> {
    if (!allowLimitRecovery) {
      return await EventReminderScheduler.publishItemSmart(item, now)
    }

    // 新建/编辑：先清再挂，避免脏数据
    const clearDetail: string = await EventReminderScheduler.forceClearAll()
    hilog.info(LOG_DOMAIN, LOG_TAG, 'schedule after clear rebuildCount=%{public}d',
      localList.length + 1)

    let main: ScheduleResult = await EventReminderScheduler.publishItemSmart(item, now)
    main.detail = clearDetail + '|' + main.detail

    if (main.ok) {
      main.message = 'CLEANED_ALL'
      return main
    }

    // 代理失败已在 publishItemSmart 内回退本地；若仍失败则原样返回
    return main
  }

  static async scheduleOncePublic(item: EventReminder, now: number): Promise<ScheduleResult> {
    return await EventReminderScheduler.publishItemSmart(item, now)
  }

  /**
   * 智能发布：代理可用则代理；否则本地。
   * 代理 1700002 且系统 count=0 时标记 agentUsable=false 并本地回退。
   */
  private static async publishItemSmart(item: EventReminder, now: number): Promise<ScheduleResult> {
    if (EventReminderScheduler.agentUsable) {
      const agentResult: ScheduleResult = await EventReminderScheduler.publishViaAgent(item, now)
      if (agentResult.ok) {
        return agentResult
      }
      // 有效数为 0 仍 1700002 → 设备侧代理不可用，永久降级本地（本进程）
      if (agentResult.errorCode === 1700002) {
        const stats: SystemReminderStats = await EventReminderScheduler.querySystemStats()
        if (stats.count === 0) {
          EventReminderScheduler.agentUsable = false
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'agent disabled: 1700002 with validCount=0, fallback to local')
        }
      }
      // 其它错误也尝试本地回退
      const localResult: ScheduleResult = await EventReminderScheduler.publishViaLocal(item, now)
      if (localResult.ok) {
        localResult.message = 'LOCAL'
        localResult.detail = agentResult.detail + '|fallbackLocal'
        return localResult
      }
      agentResult.detail = agentResult.detail + '|localAlsoFail=' + localResult.detail
      return agentResult
    }

    const onlyLocal: ScheduleResult = await EventReminderScheduler.publishViaLocal(item, now)
    if (onlyLocal.ok) {
      onlyLocal.message = 'LOCAL'
    }
    return onlyLocal
  }

  /** 系统代理发布（对齐官方示例：TIMER + CONTENT_INFORMATION） */
  private static async publishViaAgent(item: EventReminder, now: number): Promise<ScheduleResult> {
    const working: EventReminder = cloneReminder(item)
    working.exactReminderId = INVALID_REMINDER_ID
    working.advanceReminderId = INVALID_REMINDER_ID

    const secondsExact: number = Math.floor((working.triggerAt - now) / 1000)
    if (secondsExact < 1) {
      return EventReminderScheduler.failResult('提醒时间必须晚于现在', 0, 'seconds<1')
    }

    try {
      const exactId: number = await EventReminderScheduler.publishTimerAgent(
        secondsExact,
        working.title,
        false,
        EventReminderScheduler.nextNotificationId()
      )
      working.exactReminderId = exactId
      hilog.info(LOG_DOMAIN, LOG_TAG, 'agent exact id=%{public}d sec=%{public}d',
        exactId, secondsExact)

      if (shouldScheduleAdvance(working.advanceEnabled, working.triggerAt, now)) {
        const advanceAt: number = computeAdvanceAt(working.triggerAt)
        const secondsAdv: number = Math.floor((advanceAt - now) / 1000)
        if (secondsAdv >= 1) {
          const advanceId: number = await EventReminderScheduler.publishTimerAgent(
            secondsAdv,
            working.title,
            true,
            EventReminderScheduler.nextNotificationId()
          )
          working.advanceReminderId = advanceId
        }
      }

      working.updatedAt = now
      return EventReminderScheduler.okResult(working, 'agent')
    } catch (e) {
      const err: BusinessError = e as BusinessError
      const code: number = err.code !== undefined ? err.code : -1
      const msg: string = err.message !== undefined ? err.message : JSON.stringify(e)
      hilog.error(LOG_DOMAIN, LOG_TAG, 'publishViaAgent fail code=%{public}d msg=%{public}s',
        code, msg)
      try {
        await EventReminderScheduler.cancelLinked(working)
      } catch (_c) {
      }
      return EventReminderScheduler.failResult(
        EventReminderScheduler.userMessageForCode(code),
        code,
        msg
      )
    }
  }

  /**
   * 本地回退：setTimeout + notificationManager.publish
   * 进程存活时（前台/后台未杀）可提醒；杀进程后无法保证。
   * exactReminderId 使用负数标记本地模式：-2 exact, -3 advance 已挂起
   */
  private static async publishViaLocal(item: EventReminder, now: number): Promise<ScheduleResult> {
    const working: EventReminder = cloneReminder(item)
    EventReminderScheduler.clearLocalTimersFor(working.id)

    if (working.triggerAt <= now) {
      return EventReminderScheduler.failResult('提醒时间必须晚于现在', 0, 'past')
    }

    try {
      EventReminderScheduler.armLocalTimers(working, now)
      // 本地模式：用负数标记，避免误 cancel 系统 id
      working.exactReminderId = -2
      working.advanceReminderId = working.advanceEnabled &&
        shouldScheduleAdvance(true, working.triggerAt, now) ? -3 : INVALID_REMINDER_ID
      working.updatedAt = now
      hilog.info(LOG_DOMAIN, LOG_TAG, 'local armed id=%{public}s triggerAt=%{public}d',
        working.id, working.triggerAt)
      return EventReminderScheduler.okResult(working, 'local')
    } catch (e) {
      return EventReminderScheduler.failResult(
        '本地提醒设置失败',
        -1,
        JSON.stringify(e)
      )
    }
  }

  private static armLocalTimers(item: EventReminder, now: number): void {
    EventReminderScheduler.clearLocalTimersFor(item.id)

    const exactDelay: number = item.triggerAt - now
    if (exactDelay > 0) {
      EventReminderScheduler.armOneLocal(
        item.id,
        'exact',
        exactDelay,
        item.triggerAt,
        item.title,
        false
      )
    }

    if (shouldScheduleAdvance(item.advanceEnabled, item.triggerAt, now)) {
      const advanceAt: number = computeAdvanceAt(item.triggerAt)
      const advDelay: number = advanceAt - now
      if (advDelay > 0) {
        EventReminderScheduler.armOneLocal(
          item.id,
          'advance',
          advDelay,
          advanceAt,
          item.title,
          true
        )
      }
    }
  }

  private static armOneLocal(
    localId: string,
    kind: string,
    delayMs: number,
    fireAt: number,
    title: string,
    isAdvance: boolean
  ): void {
    // setTimeout 最大延迟在部分引擎约 24.8 天；超长则到点靠 onForeground 扫描
    const maxDelay: number = 24 * 60 * 60 * 1000
    const useDelay: number = delayMs > maxDelay ? maxDelay : delayMs
    const key: string = localId + ':' + kind
    // 先去掉同 key
    EventReminderScheduler.removeLocalTimerByKey(key)
    const timerId: number = setTimeout((): void => {
      EventReminderScheduler.removeLocalTimerByKey(key)
      const stillMs: number = fireAt - Date.now()
      if (stillMs > 2000) {
        EventReminderScheduler.armOneLocal(localId, kind, stillMs, fireAt, title, isAdvance)
        return
      }
      EventReminderScheduler.fireLocalNotification(title, isAdvance, localId)
    }, useDelay)

    const entry: LocalTimerEntry = {
      key: key,
      timerId: timerId,
      fireAt: fireAt,
      title: title,
      isAdvance: isAdvance,
      localId: localId
    }
    EventReminderScheduler.localTimers.push(entry)
  }

  private static removeLocalTimerByKey(key: string): void {
    const next: LocalTimerEntry[] = []
    for (let i = 0; i < EventReminderScheduler.localTimers.length; i++) {
      const entry: LocalTimerEntry = EventReminderScheduler.localTimers[i]
      if (entry.key === key) {
        clearTimeout(entry.timerId)
      } else {
        next.push(entry)
      }
    }
    EventReminderScheduler.localTimers = next
  }

  private static async fireLocalNotification(
    title: string,
    isAdvance: boolean,
    localId: string
  ): Promise<void> {
    const content: string = isAdvance ? ('还有10分钟：' + title) : title
    const id: number = EventReminderScheduler.nextNotificationId()
    try {
      // 注意：notificationManager 与 reminderAgent 的 SlotType 类型可能冲突，此处不写 slotType
      const req: notificationManager.NotificationRequest = {
        id: id,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: NOTIFY_TITLE,
            text: content,
            additionalText: ''
          }
        },
        deliveryTime: Date.now(),
        showDeliveryTime: true,
        tapDismissed: true
      }
      await notificationManager.publish(req)
      hilog.info(LOG_DOMAIN, LOG_TAG, 'local notification published id=%{public}d title=%{public}s',
        id, title)
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'local notification fail %{public}s', JSON.stringify(e))
    }

    // 到点后尝试把本地状态标 fired（best-effort，不阻塞）
    if (!isAdvance) {
      try {
        // 动态 import 避免循环依赖：直接用 store 会更好，这里延迟 require 不行
        // 由页面 onShow 校准；此处仅通知
      } catch (_e) {
      }
    }
  }

  /**
   * 前台恢复时扫描：已到期则立即弹通知并标记。
   * 由 EntryAbility / 列表页调用。
   */
  static async checkDueAndNotify(
    list: EventReminder[],
    now: number
  ): Promise<EventReminder[]> {
    const out: EventReminder[] = []
    for (let i = 0; i < list.length; i++) {
      const item: EventReminder = cloneReminder(list[i])
      if (item.status !== REMINDER_STATUS_PENDING) {
        out.push(item)
        continue
      }
      // 补挂本地定时器（进程重启后）
      if (item.triggerAt > now) {
        if (item.exactReminderId < 0 || !EventReminderScheduler.agentUsable) {
          EventReminderScheduler.armLocalTimers(item, now)
        }
        out.push(item)
        continue
      }
      // 已过期：补发一次通知（避免漏提醒）
      await EventReminderScheduler.fireLocalNotification(item.title, false, item.id)
      item.status = REMINDER_STATUS_FIRED
      item.updatedAt = now
      out.push(item)
    }
    return out
  }

  private static clearLocalTimersFor(localId: string): void {
    const next: LocalTimerEntry[] = []
    for (let i = 0; i < EventReminderScheduler.localTimers.length; i++) {
      const entry: LocalTimerEntry = EventReminderScheduler.localTimers[i]
      if (entry.localId === localId) {
        clearTimeout(entry.timerId)
      } else {
        next.push(entry)
      }
    }
    EventReminderScheduler.localTimers = next
  }

  private static clearAllLocalTimers(): void {
    for (let i = 0; i < EventReminderScheduler.localTimers.length; i++) {
      clearTimeout(EventReminderScheduler.localTimers[i].timerId)
    }
    EventReminderScheduler.localTimers = []
  }

  private static async publishTimerAgent(
    triggerTimeInSeconds: number,
    title: string,
    isAdvance: boolean,
    notificationId: number
  ): Promise<number> {
    const content: string = isAdvance ? ('还有10分钟：' + title) : title
    // 对齐官方文档示例字段
    const req: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: triggerTimeInSeconds,
      ringDuration: 5,
      title: NOTIFY_TITLE,
      content: content,
      wantAgent: {
        pkgName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      },
      notificationId: notificationId,
      slotType: notificationManager.SlotType.CONTENT_INFORMATION
    }
    const id: number = await reminderAgentManager.publishReminder(req)
    return id
  }

  private static async cancelOne(reminderId: number): Promise<void> {
    // 负数是本地模式标记
    if (reminderId === INVALID_REMINDER_ID || reminderId < 0) {
      return
    }
    try {
      await reminderAgentManager.cancelReminder(reminderId)
    } catch (e) {
      const err: BusinessError = e as BusinessError
      if (err.code !== 1700003) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'cancelReminder %{public}d fail %{public}s',
          reminderId, JSON.stringify(e))
      }
    }
  }

  private static nextNotificationId(): number {
    EventReminderScheduler.notificationIdSeq++
    if (EventReminderScheduler.notificationIdSeq > 900000) {
      EventReminderScheduler.notificationIdSeq = 2000
    }
    return EventReminderScheduler.notificationIdSeq
  }

  private static userMessageForCode(code: number): string {
    if (code === 1700001) {
      return '通知未开启，请在系统设置中允许本应用通知'
    }
    if (code === 1700002) {
      return '系统代理提醒不可用，将使用应用内提醒'
    }
    if (code === 201) {
      return '缺少发布提醒权限(201)'
    }
    if (code === 401) {
      return '提醒参数无效(401)'
    }
    return '设置系统提醒失败(' + code.toString() + ')'
  }

  private static okResult(item: EventReminder, detail: string): ScheduleResult {
    const r: ScheduleResult = {
      ok: true,
      message: '',
      item: item,
      errorCode: 0,
      detail: detail
    }
    return r
  }

  private static failResult(message: string, errorCode: number, detail: string): ScheduleResult {
    const r: ScheduleResult = {
      ok: false,
      message: message,
      item: null,
      errorCode: errorCode,
      detail: detail
    }
    return r
  }
}
