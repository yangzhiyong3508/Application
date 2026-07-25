export type GamepadDirection = 'up' | 'down' | 'left' | 'right' | 'center'

export interface GamepadControlAction {
  command: string
  buttonId: string
}

const AXIS_DEAD_ZONE: number = 0.35

export function getGamepadActionFromDirection(direction: GamepadDirection): GamepadControlAction {
  switch (direction) {
    case 'up':
      return { command: 'trot', buttonId: 'pad_up' }
    case 'down':
      return { command: 'trot_back', buttonId: 'pad_down' }
    case 'left':
      return { command: 'turn_left', buttonId: 'pad_left' }
    case 'right':
      return { command: 'turn_right', buttonId: 'pad_right' }
    default:
      return { command: 'stop', buttonId: '' }
  }
}

export function getGamepadActionFromAxis(axisX: number, axisY: number): GamepadControlAction {
  if (Math.abs(axisX) < AXIS_DEAD_ZONE && Math.abs(axisY) < AXIS_DEAD_ZONE) {
    return getGamepadActionFromDirection('center')
  }

  if (Math.abs(axisY) >= Math.abs(axisX)) {
    return getGamepadActionFromDirection(axisY < 0 ? 'up' : 'down')
  }

  return getGamepadActionFromDirection(axisX < 0 ? 'left' : 'right')
}

export function getGamepadActionFromHat(hatX: number, hatY: number): GamepadControlAction {
  return getGamepadActionFromAxis(hatX, hatY)
}

export function getGamepadActionFromAxisState(
  hatX: number,
  hatY: number,
  axisX: number,
  axisY: number
): GamepadControlAction {
  if (Math.abs(hatX) >= AXIS_DEAD_ZONE || Math.abs(hatY) >= AXIS_DEAD_ZONE) {
    return getGamepadActionFromHat(hatX, hatY)
  }

  return getGamepadActionFromAxis(axisX, axisY)
}
