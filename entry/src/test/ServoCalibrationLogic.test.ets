import { describe, it, expect } from '@ohos/hypium'
import {
  ServoCalibrationService,
  ServoChannelConfig
} from '../main/ets/utils/ServoCalibrationService'

function makeChannel(channel: number, id: string, leg: string, joint: string,
  reserved: boolean): ServoChannelConfig {
  const item: ServoChannelConfig = new ServoChannelConfig()
  item.channel = channel
  item.id = id
  item.leg = leg
  item.joint = joint
  item.reserved = reserved
  return item
}

function makeBackendChannels(): ServoChannelConfig[] {
  const channels: ServoChannelConfig[] = []
  const legs: string[] = ['LF', 'RF', 'LB', 'RB']
  const joints: string[] = ['HIP', 'THIGH', 'CALF', 'RESERVED']
  for (let channel: number = 0; channel < 16; channel += 1) {
    const legIndex: number = Math.floor(channel / 4)
    channels.push(makeChannel(channel, 'CH_' + channel.toString(), legs[legIndex],
      joints[channel % 4], channel % 4 === 3))
  }
  return channels
}

export default function servoCalibrationLogicTest() {
  describe('ServoCalibrationLogic', () => {
    it('clamps physical servo angles to zero through one hundred eighty', 0, () => {
      expect(ServoCalibrationService.clampAngle(-1)).assertEqual(0)
      expect(ServoCalibrationService.clampAngle(95.6)).assertEqual(96)
      expect(ServoCalibrationService.clampAngle(181)).assertEqual(180)
    })

    it('filters reserved channels and keeps twelve active channels in backend order', 0, () => {
      const active: ServoChannelConfig[] = ServoCalibrationService.activeChannels(makeBackendChannels())
      expect(active.length).assertEqual(12)
      expect(active[0].channel).assertEqual(0)
      expect(active[2].channel).assertEqual(2)
      expect(active[3].channel).assertEqual(4)
      expect(active[11].channel).assertEqual(14)
    })

    it('groups each leg into hip thigh and calf channels', 0, () => {
      const active: ServoChannelConfig[] = ServoCalibrationService.activeChannels(makeBackendChannels())
      const leftFront: ServoChannelConfig[] = ServoCalibrationService.channelsForLeg(active, 'LF')
      const rightRear: ServoChannelConfig[] = ServoCalibrationService.channelsForLeg(active, 'RB')
      expect(leftFront.length).assertEqual(3)
      expect(leftFront[0].joint).assertEqual('HIP')
      expect(leftFront[1].joint).assertEqual('THIGH')
      expect(leftFront[2].joint).assertEqual('CALF')
      expect(rightRear[0].channel).assertEqual(12)
      expect(rightRear[2].channel).assertEqual(14)
    })

    it('calculates center offset and permits only center plus or minus trim', 0, () => {
      expect(ServoCalibrationService.calibrationOffset(95, 90)).assertEqual(5)
      expect(ServoCalibrationService.calibrationOffset(85, 90)).assertEqual(-5)
      expect(ServoCalibrationService.isCalibrationAngleAllowed(45, 90, 45)).assertTrue()
      expect(ServoCalibrationService.isCalibrationAngleAllowed(135, 90, 45)).assertTrue()
      expect(ServoCalibrationService.isCalibrationAngleAllowed(44, 90, 45)).assertFalse()
      expect(ServoCalibrationService.isCalibrationAngleAllowed(136, 90, 45)).assertFalse()
    })
  })
}
