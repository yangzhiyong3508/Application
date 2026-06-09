import { describe, it, expect } from '@ohos/hypium'
import {
  getGamepadActionFromAxis,
  getGamepadActionFromAxisState,
  getGamepadActionFromDirection,
  getGamepadActionFromHat
} from '../main/ets/utils/GamepadControlMapper'

export default function gamepadControlMapperTest() {
  describe('gamepadControlMapperTest', () => {
    it('maps dpad directions to dog motion commands', 0, () => {
      expect(getGamepadActionFromDirection('up').command).assertEqual('trot')
      expect(getGamepadActionFromDirection('down').command).assertEqual('trot_back')
      expect(getGamepadActionFromDirection('left').command).assertEqual('turn_left')
      expect(getGamepadActionFromDirection('right').command).assertEqual('turn_right')
    })

    it('maps axis movement and neutral state', 0, () => {
      expect(getGamepadActionFromAxis(0, -0.8).buttonId).assertEqual('pad_up')
      expect(getGamepadActionFromAxis(0.9, 0).command).assertEqual('turn_right')
      expect(getGamepadActionFromAxis(0.1, -0.1).command).assertEqual('stop')
    })

    it('maps hat axis movement', 0, () => {
      expect(getGamepadActionFromHat(-1, 0).buttonId).assertEqual('pad_left')
      expect(getGamepadActionFromHat(0, 1).command).assertEqual('trot_back')
    })

    it('falls back to stick movement when hat axis is neutral', 0, () => {
      expect(getGamepadActionFromAxisState(0, 0, 0, -0.8).command).assertEqual('trot')
      expect(getGamepadActionFromAxisState(0, 0, 0.9, 0).buttonId).assertEqual('pad_right')
    })
  })
}
