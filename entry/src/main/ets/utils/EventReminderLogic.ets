/**
 * 事件提醒纯逻辑：校验、排序、提前时间、过期校准（无系统 I/O）
 */

import {
  ADVANCE_MINUTES,
  EventReminder,
  INVALID_REMINDER_ID,
  REMINDER_ICON_EVENT,
  REMINDER_ICON_FEED,
  REMINDER_ICON_MED,
  REMINDER_ICON_PLAY,
  REMINDER_ICON_SLEEP,
  REMINDER_ICON_WALK,
  REMINDER_STATUS_FIRED,
  REMINDER_STATUS_PENDING,
  ReminderIconOption,
  ReminderLocalDateTime,
  TITLE_MAX_LEN,
  ValidateResult
} from './EventReminderTypes'

export function validateReminderInput(title: string, triggerAt: number, now: number): ValidateResult {
  const trimmed: string = title.trim()
  if (trimmed.length === 0) {
    return { ok: false, message: '请填写提醒标题' }
  }
  if (trimmed.length > TITLE_MAX_LEN) {
    return { ok: false, message: '标题最多' + TITLE_MAX_LEN.toString() + '个字' }
  }
  if (triggerAt <= now) {
    return { ok: false, message: '提醒时间必须晚于现在' }
  }
  return { ok: true, message: '' }
}

export function computeAdvanceAt(triggerAt: number): number {
  return triggerAt - ADVANCE_MINUTES * 60 * 1000
}

export function shouldScheduleAdvance(advanceEnabled: boolean, triggerAt: number, now: number): boolean {
  if (!advanceEnabled) {
    return false
  }
  const advanceAt: number = computeAdvanceAt(triggerAt)
  return advanceAt > now
}

export function createReminderId(): string {
  const rand: number = Math.floor(Math.random() * 100000)
  return 'er_' + Date.now().toString() + '_' + rand.toString()
}

export function msToLocalDateTime(ms: number): ReminderLocalDateTime {
  const d: Date = new Date(ms)
  const result: ReminderLocalDateTime = {
    year: d.getFullYear(),
    month: d.getMonth() + 1,
    day: d.getDate(),
    hour: d.getHours(),
    minute: d.getMinutes(),
    second: d.getSeconds()
  }
  return result
}

export function localDateTimeToMs(parts: ReminderLocalDateTime): number {
  // Date 构造 month 为 0–11
  return new Date(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second, 0).getTime()
}

export function sortRemindersForDisplay(list: EventReminder[]): EventReminder[] {
  const pending: EventReminder[] = []
  const others: EventReminder[] = []
  for (let i = 0; i < list.length; i++) {
    const item: EventReminder = list[i]
    if (item.status === REMINDER_STATUS_PENDING) {
      pending.push(item)
    } else {
      others.push(item)
    }
  }
  pending.sort((a: EventReminder, b: EventReminder): number => {
    return a.triggerAt - b.triggerAt
  })
  others.sort((a: EventReminder, b: EventReminder): number => {
    return b.triggerAt - a.triggerAt
  })
  const out: EventReminder[] = []
  for (let i = 0; i < pending.length; i++) {
    out.push(pending[i])
  }
  for (let i = 0; i < others.length; i++) {
    out.push(others[i])
  }
  return out
}

/**
 * 将已过期的 pending 标为 fired。返回是否发生变更。
 */
export function markExpiredPending(list: EventReminder[], now: number): boolean {
  let changed: boolean = false
  for (let i = 0; i < list.length; i++) {
    const item: EventReminder = list[i]
    if (item.status === REMINDER_STATUS_PENDING && item.triggerAt <= now) {
      item.status = REMINDER_STATUS_FIRED
      item.updatedAt = now
      changed = true
    }
  }
  return changed
}

export function formatTriggerTime(ms: number): string {
  const d: Date = new Date(ms)
  const y: number = d.getFullYear()
  const m: number = d.getMonth() + 1
  const day: number = d.getDate()
  const h: number = d.getHours()
  const min: number = d.getMinutes()
  return y.toString() + '-' + pad2(m) + '-' + pad2(day) + ' ' + pad2(h) + ':' + pad2(min)
}

function pad2(n: number): string {
  if (n < 10) {
    return '0' + n.toString()
  }
  return n.toString()
}

export function cloneReminder(src: EventReminder): EventReminder {
  const copy: EventReminder = {
    id: src.id,
    title: src.title,
    triggerAt: src.triggerAt,
    advanceEnabled: src.advanceEnabled,
    status: src.status,
    exactReminderId: src.exactReminderId,
    advanceReminderId: src.advanceReminderId,
    createdAt: src.createdAt,
    updatedAt: src.updatedAt,
    iconKey: src.iconKey !== undefined && src.iconKey.length > 0 ? src.iconKey : REMINDER_ICON_EVENT
  }
  return copy
}

export function createEmptyReminderDraft(now: number): EventReminder {
  const draft: EventReminder = {
    id: '',
    title: '',
    triggerAt: now + 60 * 60 * 1000,
    advanceEnabled: false,
    status: REMINDER_STATUS_PENDING,
    exactReminderId: INVALID_REMINDER_ID,
    advanceReminderId: INVALID_REMINDER_ID,
    createdAt: now,
    updatedAt: now,
    iconKey: REMINDER_ICON_EVENT
  }
  return draft
}

export function reminderIconOptions(): ReminderIconOption[] {
  const list: ReminderIconOption[] = [
    { key: REMINDER_ICON_EVENT, label: '日程' },
    { key: REMINDER_ICON_FEED, label: '喂食' },
    { key: REMINDER_ICON_WALK, label: '遛弯' },
    { key: REMINDER_ICON_MED, label: '用药' },
    { key: REMINDER_ICON_PLAY, label: '玩耍' },
    { key: REMINDER_ICON_SLEEP, label: '休息' }
  ]
  return list
}

/** 根据标题关键词推断图标（用户未选手动类型时） */
export function inferIconKeyFromTitle(title: string): string {
  const t: string = title.trim()
  if (t.indexOf('喂') >= 0 || t.indexOf('食') >= 0 || t.indexOf('饭') >= 0) {
    return REMINDER_ICON_FEED
  }
  if (t.indexOf('遛') >= 0 || t.indexOf('散步') >= 0 || t.indexOf('走') >= 0) {
    return REMINDER_ICON_WALK
  }
  if (t.indexOf('药') >= 0 || t.indexOf('医') >= 0 || t.indexOf('疫苗') >= 0) {
    return REMINDER_ICON_MED
  }
  if (t.indexOf('玩') >= 0 || t.indexOf('逗') >= 0 || t.indexOf('球') >= 0) {
    return REMINDER_ICON_PLAY
  }
  if (t.indexOf('睡') >= 0 || t.indexOf('休息') >= 0 || t.indexOf('午休') >= 0) {
    return REMINDER_ICON_SLEEP
  }
  return REMINDER_ICON_EVENT
}

export function resolveIconKey(iconKey: string, title: string): string {
  if (iconKey !== undefined && iconKey.length > 0 && iconKey !== REMINDER_ICON_EVENT) {
    return iconKey
  }
  // event 时仍可用标题推断
  if (iconKey === REMINDER_ICON_EVENT || iconKey === undefined || iconKey.length === 0) {
    const inferred: string = inferIconKeyFromTitle(title)
    if (iconKey === REMINDER_ICON_EVENT && inferred !== REMINDER_ICON_EVENT) {
      return inferred
    }
    if (iconKey === undefined || iconKey.length === 0) {
      return inferred
    }
  }
  return iconKey.length > 0 ? iconKey : REMINDER_ICON_EVENT
}

export function remainingLabel(triggerAt: number, now: number): string {
  const diff: number = triggerAt - now
  if (diff <= 0) {
    return '已到时'
  }
  const mins: number = Math.floor(diff / 60000)
  if (mins < 60) {
    return mins <= 0 ? '即将提醒' : mins.toString() + ' 分钟后'
  }
  const hours: number = Math.floor(mins / 60)
  if (hours < 48) {
    return hours.toString() + ' 小时后'
  }
  const days: number = Math.floor(hours / 24)
  return days.toString() + ' 天后'
}
