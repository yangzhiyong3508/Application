/**
 * 事件提醒本地持久化（preferences JSON）
 */

import common from '@ohos.app.ability.common'
import preferences from '@ohos.data.preferences'
import {
  EventReminder,
  INVALID_REMINDER_ID,
  PREF_KEY_LIST,
  PREF_NAME,
  REMINDER_ICON_EVENT,
  REMINDER_STATUS_PENDING
} from './EventReminderTypes'

export class EventReminderStore {
  private static prefs: preferences.Preferences | null = null

  static async init(context: common.Context): Promise<void> {
    if (EventReminderStore.prefs !== null) {
      return
    }
    EventReminderStore.prefs = await preferences.getPreferences(context, PREF_NAME)
  }

  static async loadAll(): Promise<EventReminder[]> {
    if (EventReminderStore.prefs === null) {
      return []
    }
    try {
      const raw: string = await EventReminderStore.prefs.get(PREF_KEY_LIST, '[]') as string
      if (raw.length === 0) {
        return []
      }
      const parsed: EventReminder[] = JSON.parse(raw) as EventReminder[]
      if (parsed === null || parsed === undefined) {
        return []
      }
      const list: EventReminder[] = []
      for (let i = 0; i < parsed.length; i++) {
        const item: EventReminder | null = EventReminderStore.normalizeItem(parsed[i])
        if (item !== null) {
          list.push(item)
        }
      }
      return list
    } catch (e) {
      console.error('[EventReminderStore] loadAll failed: ' + JSON.stringify(e))
      return []
    }
  }

  static async saveAll(list: EventReminder[]): Promise<void> {
    if (EventReminderStore.prefs === null) {
      return
    }
    try {
      const text: string = JSON.stringify(list)
      await EventReminderStore.prefs.put(PREF_KEY_LIST, text)
      await EventReminderStore.prefs.flush()
    } catch (e) {
      console.error('[EventReminderStore] saveAll failed: ' + JSON.stringify(e))
    }
  }

  static async upsert(item: EventReminder): Promise<void> {
    const list: EventReminder[] = await EventReminderStore.loadAll()
    let found: boolean = false
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === item.id) {
        list[i] = item
        found = true
        break
      }
    }
    if (!found) {
      list.push(item)
    }
    await EventReminderStore.saveAll(list)
  }

  static async removeById(id: string): Promise<void> {
    const list: EventReminder[] = await EventReminderStore.loadAll()
    const next: EventReminder[] = []
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== id) {
        next.push(list[i])
      }
    }
    await EventReminderStore.saveAll(next)
  }

  static async getById(id: string): Promise<EventReminder | null> {
    const list: EventReminder[] = await EventReminderStore.loadAll()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i]
      }
    }
    return null
  }

  private static normalizeItem(raw: EventReminder): EventReminder | null {
    if (raw === null || raw === undefined) {
      return null
    }
    const id: string = raw.id !== undefined && raw.id !== null ? String(raw.id) : ''
    if (id.length === 0) {
      return null
    }
    const title: string = raw.title !== undefined && raw.title !== null ? String(raw.title) : ''
    const triggerAt: number = EventReminderStore.safeNumber(raw.triggerAt, 0)
    const advanceEnabled: boolean = raw.advanceEnabled === true
    const status: string = raw.status !== undefined && raw.status !== null && String(raw.status).length > 0
      ? String(raw.status)
      : REMINDER_STATUS_PENDING
    let iconKey: string = REMINDER_ICON_EVENT
    if (raw.iconKey !== undefined && raw.iconKey !== null && String(raw.iconKey).length > 0) {
      iconKey = String(raw.iconKey)
    }
    const item: EventReminder = {
      id: id,
      title: title,
      triggerAt: triggerAt,
      advanceEnabled: advanceEnabled,
      status: status,
      exactReminderId: EventReminderStore.safeNumber(raw.exactReminderId, INVALID_REMINDER_ID),
      advanceReminderId: EventReminderStore.safeNumber(raw.advanceReminderId, INVALID_REMINDER_ID),
      createdAt: EventReminderStore.safeNumber(raw.createdAt, 0),
      updatedAt: EventReminderStore.safeNumber(raw.updatedAt, 0),
      iconKey: iconKey
    }
    return item
  }

  private static safeNumber(value: number, fallback: number): number {
    if (value === undefined || value === null) {
      return fallback
    }
    const n: number = Number(value)
    if (Number.isNaN(n)) {
      return fallback
    }
    return n
  }
}
