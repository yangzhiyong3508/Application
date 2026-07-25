/**
 * 事件提醒列表与新建/编辑 — 美化版
 */

import promptAction from '@ohos.promptAction'
import common from '@ohos.app.ability.common'
import { AppShadow, isTablet } from '../theme/Theme'
import {
  cloneReminder,
  createEmptyReminderDraft,
  createReminderId,
  formatTriggerTime,
  inferIconKeyFromTitle,
  localDateTimeToMs,
  markExpiredPending,
  msToLocalDateTime,
  remainingLabel,
  resolveIconKey,
  shouldScheduleAdvance,
  sortRemindersForDisplay,
  validateReminderInput
} from '../utils/EventReminderLogic'
import { EventReminderScheduler } from '../utils/EventReminderScheduler'
import { EventReminderStore } from '../utils/EventReminderStore'
import {
  EventReminder,
  INVALID_REMINDER_ID,
  REMINDER_ICON_EVENT,
  REMINDER_ICON_FEED,
  REMINDER_ICON_MED,
  REMINDER_ICON_PLAY,
  REMINDER_ICON_SLEEP,
  REMINDER_ICON_WALK,
  REMINDER_STATUS_PENDING,
  ReminderLocalDateTime,
  ScheduleResult,
  TITLE_MAX_LEN
} from '../utils/EventReminderTypes'

@Builder
export function EventRemindersBuilder() {
  EventReminders()
}

@Entry
@Component
struct EventReminders {
  pathStack: NavPathStack = new NavPathStack()

  @State items: EventReminder[] = []
  @State isLoading: boolean = true
  @State saving: boolean = false
  @State showForm: boolean = false
  @State editingId: string = ''
  @State formTitle: string = ''
  @State formAdvance: boolean = false
  @State formYear: number = 2026
  @State formMonth: number = 1
  @State formDay: number = 1
  @State formHour: number = 12
  @State formMinute: number = 0
  @State pageWidth: number = 0
  @State selectedDate: Date = new Date()
  @State pendingCount: number = 0

  private context: common.UIAbilityContext | null = null

  async aboutToAppear(): Promise<void> {
    try {
      this.context = getContext(this) as common.UIAbilityContext
      await EventReminderStore.init(this.context)
      await this.reloadList()
    } catch (e) {
      console.error('[EventReminders] aboutToAppear: ' + JSON.stringify(e))
      this.isLoading = false
    }
  }

  private async reloadList(): Promise<void> {
    this.isLoading = true
    try {
      const list: EventReminder[] = await EventReminderStore.loadAll()
      const now: number = Date.now()
      const changed: boolean = markExpiredPending(list, now)
      if (changed) {
        await EventReminderStore.saveAll(list)
      }
      await EventReminderScheduler.syncSystemWithLocal(list)
      this.items = sortRemindersForDisplay(list)
      let pending: number = 0
      for (let i = 0; i < this.items.length; i++) {
        if (this.items[i].status === REMINDER_STATUS_PENDING) {
          pending++
        }
      }
      this.pendingCount = pending
    } catch (e) {
      console.error('[EventReminders] reloadList: ' + JSON.stringify(e))
      this.items = []
      this.pendingCount = 0
    } finally {
      this.isLoading = false
    }
  }

  private openCreateForm(): void {
    const now: number = Date.now()
    const draft: EventReminder = createEmptyReminderDraft(now)
    this.editingId = ''
    this.formTitle = ''
    this.formAdvance = false
    this.applyTriggerToForm(draft.triggerAt)
    this.showForm = true
  }

  private openEditForm(item: EventReminder): void {
    this.editingId = item.id
    this.formTitle = item.title
    this.formAdvance = item.advanceEnabled
    this.applyTriggerToForm(item.triggerAt)
    this.showForm = true
  }

  private applyTriggerToForm(ms: number): void {
    const parts: ReminderLocalDateTime = msToLocalDateTime(ms)
    this.formYear = parts.year
    this.formMonth = parts.month
    this.formDay = parts.day
    this.formHour = parts.hour
    this.formMinute = parts.minute
    this.selectedDate = new Date(ms)
  }

  private formTriggerMs(): number {
    const parts: ReminderLocalDateTime = {
      year: this.formYear,
      month: this.formMonth,
      day: this.formDay,
      hour: this.formHour,
      minute: this.formMinute,
      second: 0
    }
    return localDateTimeToMs(parts)
  }

  private iconResource(iconKey: string): Resource {
    const key: string = iconKey !== undefined && iconKey.length > 0 ? iconKey : REMINDER_ICON_EVENT
    if (key === REMINDER_ICON_FEED) {
      return $r('app.media.rem_feed')
    }
    if (key === REMINDER_ICON_WALK) {
      return $r('app.media.rem_walk')
    }
    if (key === REMINDER_ICON_MED) {
      return $r('app.media.rem_med')
    }
    if (key === REMINDER_ICON_PLAY) {
      return $r('app.media.rem_play')
    }
    if (key === REMINDER_ICON_SLEEP) {
      return $r('app.media.rem_sleep')
    }
    return $r('app.media.rem_event')
  }

  private iconTint(iconKey: string): ResourceColor {
    const key: string = resolveIconKey(iconKey, '')
    if (key === REMINDER_ICON_FEED) {
      return '#FFF3E8'
    }
    if (key === REMINDER_ICON_WALK) {
      return '#E8F8EF'
    }
    if (key === REMINDER_ICON_MED) {
      return '#FDECEE'
    }
    if (key === REMINDER_ICON_PLAY) {
      return '#FFF8E6'
    }
    if (key === REMINDER_ICON_SLEEP) {
      return '#EEF0FF'
    }
    return '#EEF2FF'
  }

  private async saveForm(): Promise<void> {
    if (this.saving) {
      return
    }
    const now: number = Date.now()
    const title: string = this.formTitle.trim()
    const triggerAt: number = this.formTriggerMs()
    const validation = validateReminderInput(title, triggerAt, now)
    if (!validation.ok) {
      promptAction.showToast({ message: validation.message })
      return
    }

    this.saving = true
    try {
      if (this.context !== null) {
        await EventReminderScheduler.ensureNotificationReady(this.context)
      }

      // 不再展示事件类型选择，按标题关键词推断图标
      const iconKey: string = inferIconKeyFromTitle(title)

      let item: EventReminder
      if (this.editingId.length > 0) {
        const existing: EventReminder | null = await EventReminderStore.getById(this.editingId)
        if (existing === null) {
          promptAction.showToast({ message: '提醒不存在，请刷新后重试' })
          return
        }
        item = cloneReminder(existing)
        item.title = title
        item.triggerAt = triggerAt
        item.advanceEnabled = this.formAdvance
        item.status = REMINDER_STATUS_PENDING
        item.updatedAt = now
        item.iconKey = iconKey
      } else {
        item = {
          id: createReminderId(),
          title: title,
          triggerAt: triggerAt,
          advanceEnabled: this.formAdvance,
          status: REMINDER_STATUS_PENDING,
          exactReminderId: INVALID_REMINDER_ID,
          advanceReminderId: INVALID_REMINDER_ID,
          createdAt: now,
          updatedAt: now,
          iconKey: iconKey
        }
      }

      if (this.formAdvance && !shouldScheduleAdvance(true, triggerAt, now)) {
        promptAction.showToast({ message: '已过提前窗口，将仅在到点提醒' })
      }

      const localSnapshot: EventReminder[] = await EventReminderStore.loadAll()
      const result: ScheduleResult =
        await EventReminderScheduler.schedule(item, now, localSnapshot, true)
      if (!result.ok || result.item === null) {
        const tip: string = result.message.length > 0 ? result.message : '设置提醒失败'
        console.error('[EventReminders] schedule fail detail=' + result.detail +
          ' code=' + result.errorCode.toString())
        promptAction.showToast({ message: tip })
        return
      }

      await EventReminderStore.upsert(result.item)

      if (result.message === 'CLEANED_ALL' || result.message === 'LOCAL') {
        await this.rescheduleAllPendingExcept(result.item.id)
      }

      this.showForm = false
      await this.reloadList()

      let tip: string = '已设置提醒'
      if (result.detail.indexOf('local') >= 0 || result.detail.indexOf('fallbackLocal') >= 0 ||
        result.message === 'LOCAL') {
        tip = '已设置（应用内提醒：请保持应用在后台）'
      }
      promptAction.showToast({ message: tip })
    } catch (e) {
      console.error('[EventReminders] saveForm: ' + JSON.stringify(e))
      promptAction.showToast({ message: '保存失败，请稍后重试' })
    } finally {
      this.saving = false
    }
  }

  private async confirmDelete(item: EventReminder): Promise<void> {
    try {
      const result = await promptAction.showDialog({
        title: '删除提醒',
        message: '确定删除「' + item.title + '」吗？删除后将不再通知。',
        buttons: [
          { text: '取消', color: '#FF62758F' },
          { text: '删除', color: '#FFDF4B45' }
        ]
      })
      if (result.index !== 1) {
        return
      }
      await EventReminderScheduler.cancelLinked(item)
      await EventReminderStore.removeById(item.id)
      await this.reloadList()
      promptAction.showToast({ message: '已删除' })
    } catch (e) {
      console.info('[EventReminders] delete canceled or failed: ' + JSON.stringify(e))
    }
  }

  private async rescheduleAllPendingExcept(excludeId: string): Promise<void> {
    const list: EventReminder[] = await EventReminderStore.loadAll()
    const now: number = Date.now()
    for (let i = 0; i < list.length; i++) {
      const row: EventReminder = list[i]
      if (row.id === excludeId) {
        continue
      }
      if (row.status !== REMINDER_STATUS_PENDING) {
        continue
      }
      if (row.triggerAt <= now) {
        continue
      }
      row.exactReminderId = INVALID_REMINDER_ID
      row.advanceReminderId = INVALID_REMINDER_ID
      const rebuilt: ScheduleResult =
        await EventReminderScheduler.scheduleOncePublic(row, now)
      if (rebuilt.ok && rebuilt.item !== null) {
        await EventReminderStore.upsert(rebuilt.item)
      }
    }
  }

  private async manualClearSystem(): Promise<void> {
    try {
      const before = await EventReminderScheduler.querySystemStats()
      const detail: string = await EventReminderScheduler.forceClearAll()
      const after = await EventReminderScheduler.querySystemStats()
      promptAction.showToast({
        message: '已清理：' + before.count.toString() + '→' + after.count.toString() + ' 条'
      })
      console.info('[EventReminders] manualClear ' + detail)
      const list: EventReminder[] = await EventReminderStore.loadAll()
      const now: number = Date.now()
      for (let i = 0; i < list.length; i++) {
        const row: EventReminder = list[i]
        if (row.status !== REMINDER_STATUS_PENDING || row.triggerAt <= now) {
          continue
        }
        row.exactReminderId = INVALID_REMINDER_ID
        row.advanceReminderId = INVALID_REMINDER_ID
        const rebuilt: ScheduleResult =
          await EventReminderScheduler.scheduleOncePublic(row, now)
        if (rebuilt.ok && rebuilt.item !== null) {
          await EventReminderStore.upsert(rebuilt.item)
        }
      }
      await this.reloadList()
    } catch (e) {
      promptAction.showToast({ message: '清理失败' })
    }
  }

  private statusLabel(item: EventReminder): string {
    if (item.status === REMINDER_STATUS_PENDING) {
      return item.advanceEnabled ? '待提醒 · 提前10分钟' : '待提醒'
    }
    return '已结束'
  }

  private nextHint(): string {
    if (this.pendingCount <= 0) {
      return '还没有待办日程'
    }
    const now: number = Date.now()
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].status === REMINDER_STATUS_PENDING) {
        return '最近：' + remainingLabel(this.items[i].triggerAt, now)
      }
    }
    return this.pendingCount.toString() + ' 条待提醒'
  }

  @Builder
  private HeroCard() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.nextHint())
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          Text(this.pendingCount.toString() + ' 待办')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.brand_primary_subtle'))
            .borderRadius(10)

          Text(this.items.length.toString() + ' 全部')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.input_bg'))
            .borderRadius(10)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.surface_border') })
  }

  @Builder
  private ReminderCard(item: EventReminder) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(56)
          .height(56)
          .borderRadius(18)
          .backgroundColor(this.iconTint(item.iconKey))

        Image(this.iconResource(resolveIconKey(item.iconKey, item.title)))
          .width(44)
          .height(44)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
      }

      Column({ space: 5 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          Text(formatTriggerTime(item.triggerAt))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          if (item.status === REMINDER_STATUS_PENDING) {
            Text('·')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
            Text(remainingLabel(item.triggerAt, Date.now()))
              .fontSize(12)
              .fontColor($r('app.color.brand_primary'))
          }
        }

        Text(this.statusLabel(item))
          .fontSize(11)
          .fontColor(item.status === REMINDER_STATUS_PENDING
            ? $r('app.color.brand_primary')
            : $r('app.color.text_tertiary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(item.status === REMINDER_STATUS_PENDING
            ? $r('app.color.brand_primary_subtle')
            : $r('app.color.input_bg'))
          .borderRadius(8)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.text_tertiary'))
          .opacity(item.status === REMINDER_STATUS_PENDING ? 1 : 0.4)

        Text('删除')
          .fontSize(11)
          .fontColor($r('app.color.state_danger'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.state_danger_subtle'))
          .borderRadius(10)
          .onClick((): void => {
            this.confirmDelete(item)
          })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.End)
      .height(56)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface_card_solid'))
    .border({ width: 1, color: $r('app.color.surface_border') })
    .borderRadius(20)
    .shadow(AppShadow.card)
    .opacity(item.status === REMINDER_STATUS_PENDING ? 1 : 0.7)
    .onClick((): void => {
      if (item.status === REMINDER_STATUS_PENDING) {
        this.openEditForm(item)
      } else {
        promptAction.showToast({ message: '已结束的提醒不可编辑，可删除' })
      }
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg'))

        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Image($r('app.media.arrow_return'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
              .padding(4)
              .onClick((): void => {
                this.pathStack.pop()
              })

            Text('提醒')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            Row({ space: 8 }) {
              Image($r('app.media.pet_reset'))
                .width(18)
                .height(18)
                .fillColor($r('app.color.text_secondary'))
                .padding(8)
                .backgroundColor($r('app.color.input_bg'))
                .borderRadius(12)
                .onClick((): void => {
                  this.manualClearSystem()
                })

              Row({ space: 4 }) {
                Image($r('app.media.add'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_on_brand'))
                Text('新建')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_on_brand'))
              }
              .height(36)
              .padding({ left: 12, right: 14 })
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius(12)
              .onClick((): void => {
                this.openCreateForm()
              })
            }
          }
          .width('100%')
          .height(52)
          .alignItems(VerticalAlign.Center)

          this.HeroCard()

          if (this.isLoading) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(34)
                .height(34)
                .color($r('app.color.brand_primary'))
              Text('加载中...')
                .fontSize(15)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.items.length === 0) {
            Column({ space: 12 }) {
              Image($r('app.media.rem_empty'))
                .width(140)
                .height(140)
                .borderRadius(16)
                .objectFit(ImageFit.Cover)

              Text('暂无提醒')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))

              Button('新建')
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor($r('app.color.brand_primary'))
                .borderRadius(12)
                .padding({ left: 24, right: 24 })
                .margin({ top: 4 })
                .onClick((): void => {
                  this.openCreateForm()
                })
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Text('日程')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 4 })

            Scroll() {
              Column({ space: 12 }) {
                ForEach(this.items, (item: EventReminder): void => {
                  this.ReminderCard(item)
                }, (item: EventReminder): string => item.id + '_' + item.iconKey)
              }
              .width('100%')
              .padding({ top: 2, bottom: 32 })
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
          }
        }
        .width(isTablet(this.pageWidth) ? 720 : '100%')
        .height('100%')
        .padding({
          left: isTablet(this.pageWidth) ? 0 : 18,
          right: isTablet(this.pageWidth) ? 0 : 18,
          top: isTablet(this.pageWidth) ? 20 : 28,
          bottom: 18
        })
        .align(Alignment.Top)

        // 表单弹层
        if (this.showForm) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.overlay_bg'))
              .onClick((): void => {
                if (!this.saving) {
                  this.showForm = false
                }
              })

            Column({ space: 0 }) {
              Row() {
                Column()
                  .width(40)
                  .height(4)
                  .borderRadius(2)
                  .backgroundColor($r('app.color.surface_border'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 10, bottom: 8 })

              Text(this.editingId.length > 0 ? '编辑提醒' : '新建提醒')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .padding({ left: 20, right: 20, bottom: 10 })

              // 可滚动内容区，避免底部「保存」被导航栏挡住
              Scroll() {
                Column({ space: 14 }) {
                  TextInput({ text: this.formTitle, placeholder: '标题' })
                    .width('100%')
                    .height(48)
                    .backgroundColor($r('app.color.input_bg'))
                    .border({ width: 1, color: $r('app.color.input_border') })
                    .borderRadius(14)
                    .padding({ left: 14, right: 14 })
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .maxLength(TITLE_MAX_LEN)
                    .onChange((value: string): void => {
                      this.formTitle = value
                    })

                  Text('日期')
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')

                  DatePicker({
                    start: new Date('2024-1-1'),
                    end: new Date('2035-12-31'),
                    selected: this.selectedDate
                  })
                    .onChange((value: DatePickerResult): void => {
                      const month1: number = (value.month !== undefined ? value.month : 0) + 1
                      this.formYear = value.year !== undefined ? value.year : this.formYear
                      this.formMonth = month1
                      this.formDay = value.day !== undefined ? value.day : this.formDay
                      this.selectedDate = new Date(
                        this.formYear,
                        this.formMonth - 1,
                        this.formDay,
                        this.formHour,
                        this.formMinute,
                        0
                      )
                    })
                    .height(100)
                    .width('100%')

                  Text('时间')
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')

                  TimePicker({ selected: this.selectedDate })
                    .useMilitaryTime(true)
                    .onChange((value: TimePickerResult): void => {
                      this.formHour = value.hour !== undefined ? value.hour : this.formHour
                      this.formMinute = value.minute !== undefined ? value.minute : this.formMinute
                      this.selectedDate = new Date(
                        this.formYear,
                        this.formMonth - 1,
                        this.formDay,
                        this.formHour,
                        this.formMinute,
                        0
                      )
                    })
                    .height(88)
                    .width('100%')

                  Row() {
                    Column({ space: 2 }) {
                      Text('提前 10 分钟提醒')
                        .fontSize(15)
                        .fontColor($r('app.color.text_primary'))
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Toggle({ type: ToggleType.Switch, isOn: this.formAdvance })
                      .selectedColor($r('app.color.brand_primary'))
                      .onChange((isOn: boolean): void => {
                        this.formAdvance = isOn
                      })
                  }
                  .width('100%')
                  .padding({
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: 10
                  })
                  .backgroundColor($r('app.color.input_bg'))
                  .borderRadius(14)
                }
                .width('100%')
                .padding({ left: 20, right: 20, bottom: 12 })
              }
              .layoutWeight(1)
              .width('100%')
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)

              // 固定底部操作栏，保证「保存」始终可点
              Row({ space: 12 }) {
                Button('取消')
                  .layoutWeight(1)
                  .height(48)
                  .fontSize(16)
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.input_bg'))
                  .borderRadius(24)
                  .enabled(!this.saving)
                  .onClick((): void => {
                    this.showForm = false
                  })

                Button(this.saving ? '保存中…' : '保存')
                  .layoutWeight(1)
                  .height(48)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.brand_primary'))
                  .borderRadius(24)
                  .shadow(AppShadow.subtle)
                  .enabled(!this.saving)
                  .onClick((): void => {
                    this.saveForm()
                  })
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 28 })
              .backgroundColor($r('app.color.surface_card_solid'))
            }
            .width('100%')
            .constraintSize({ maxHeight: '88%' })
            .backgroundColor($r('app.color.surface_card_solid'))
            .borderRadius({ topLeft: 28, topRight: 28 })
            .shadow(AppShadow.dialog)
          }
          .width('100%')
          .height('100%')
          .zIndex(99)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pathStack = context.pathStack
    })
  }
}
