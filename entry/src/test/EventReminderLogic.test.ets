import { describe, it, expect } from '@ohos/hypium'
import {
  computeAdvanceAt,
  markExpiredPending,
  shouldScheduleAdvance,
  sortRemindersForDisplay,
  validateReminderInput
} from '../main/ets/utils/EventReminderLogic'
import {
  EventReminder,
  INVALID_REMINDER_ID,
  REMINDER_STATUS_FIRED,
  REMINDER_STATUS_PENDING
} from '../main/ets/utils/EventReminderTypes'

function makeItem(id: string, triggerAt: number, status: string): EventReminder {
  const item: EventReminder = {
    id: id,
    title: 't',
    triggerAt: triggerAt,
    advanceEnabled: false,
    status: status,
    exactReminderId: INVALID_REMINDER_ID,
    advanceReminderId: INVALID_REMINDER_ID,
    createdAt: 0,
    updatedAt: 0,
    iconKey: 'event'
  }
  return item
}

export default function eventReminderLogicTest() {
  describe('EventReminderLogic', () => {
    it('rejects empty title and past time', 0, () => {
      const now: number = 1700000000000
      expect(validateReminderInput('', now + 60000, now).ok).assertFalse()
      expect(validateReminderInput('喂食', now - 1000, now).ok).assertFalse()
      expect(validateReminderInput('喂食', now + 60000, now).ok).assertTrue()
    })

    it('computes advance 10 minutes earlier', 0, () => {
      const t: number = 1700000600000
      expect(computeAdvanceAt(t)).assertEqual(t - 10 * 60 * 1000)
    })

    it('gates advance scheduling', 0, () => {
      const now: number = 1000000
      const trigger: number = now + 12 * 60 * 1000
      expect(shouldScheduleAdvance(false, trigger, now)).assertFalse()
      expect(shouldScheduleAdvance(true, now + 5 * 60 * 1000, now)).assertFalse()
      expect(shouldScheduleAdvance(true, trigger, now)).assertTrue()
    })

    it('sorts pending first by trigger time', 0, () => {
      const list: EventReminder[] = [
        makeItem('f1', 300, REMINDER_STATUS_FIRED),
        makeItem('p2', 200, REMINDER_STATUS_PENDING),
        makeItem('p1', 100, REMINDER_STATUS_PENDING)
      ]
      const sorted: EventReminder[] = sortRemindersForDisplay(list)
      expect(sorted[0].id).assertEqual('p1')
      expect(sorted[1].id).assertEqual('p2')
      expect(sorted[2].id).assertEqual('f1')
    })

    it('marks expired pending as fired', 0, () => {
      const now: number = 1000
      const list: EventReminder[] = [
        makeItem('a', 500, REMINDER_STATUS_PENDING),
        makeItem('b', 2000, REMINDER_STATUS_PENDING)
      ]
      const changed: boolean = markExpiredPending(list, now)
      expect(changed).assertTrue()
      expect(list[0].status).assertEqual(REMINDER_STATUS_FIRED)
      expect(list[1].status).assertEqual(REMINDER_STATUS_PENDING)
    })
  })
}
