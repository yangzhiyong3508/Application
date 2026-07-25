/**
 * 事件提醒：常量与数据模型
 */

export const INVALID_REMINDER_ID: number = -1
export const ADVANCE_MINUTES: number = 10
export const TITLE_MAX_LEN: number = 30
export const REMINDER_STATUS_PENDING: string = 'pending'
export const REMINDER_STATUS_FIRED: string = 'fired'
export const REMINDER_STATUS_CANCELLED: string = 'cancelled'
export const PREF_NAME: string = 'event_reminder_prefs'
export const PREF_KEY_LIST: string = 'event_reminders'
export const NOTIFY_TITLE: string = '日程临近'
export const BUNDLE_NAME: string = 'com.example.application'
export const ABILITY_NAME: string = 'EntryAbility'

/** 事件类型图标 key：feed/walk/med/play/sleep/event */
export const REMINDER_ICON_EVENT: string = 'event'
export const REMINDER_ICON_FEED: string = 'feed'
export const REMINDER_ICON_WALK: string = 'walk'
export const REMINDER_ICON_MED: string = 'med'
export const REMINDER_ICON_PLAY: string = 'play'
export const REMINDER_ICON_SLEEP: string = 'sleep'

export interface EventReminder {
  id: string
  title: string
  triggerAt: number
  advanceEnabled: boolean
  status: string
  exactReminderId: number
  advanceReminderId: number
  createdAt: number
  updatedAt: number
  /** 事件类型图标，见 REMINDER_ICON_* */
  iconKey: string
}

export interface ReminderIconOption {
  key: string
  label: string
}

export interface ValidateResult {
  ok: boolean
  message: string
}

/** 日历提醒用本地时间分量（month 为 1–12） */
export interface ReminderLocalDateTime {
  year: number
  month: number
  day: number
  hour: number
  minute: number
  second: number
}

export interface ScheduleResult {
  ok: boolean
  message: string
  item: EventReminder | null
  /** 原始错误码，便于排查（0 表示无） */
  errorCode: number
  /** 清理/诊断信息 */
  detail: string
}

export interface SystemReminderStats {
  count: number
  ids: number[]
  error: string
}
