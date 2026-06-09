import { authService, CommonConstant, ServoAngleCommandParas } from './GetIotToken'
import { IotConnector } from './IotConnector'

export interface ServoPreset {
  id: number
  label: string
}

class ServoCommandMessage {
  command_name: string = ''
  paras: ServoAngleCommandParas = new ServoAngleCommandParas()
}

class StraightLegCommandParas {
}

class StraightLegCommandMessage {
  command_name: string = ''
  paras: StraightLegCommandParas = new StraightLegCommandParas()
}

export const SUPPORTED_SERVO_ID_TEXT: string = '0、2、4、6、8、10、12、14'

export const SUPPORTED_SERVO_IDS: number[] = [
  0, 2, 4, 6,
  8, 10, 12, 14
]

export const SUPPORTED_SERVO_PRESETS: ServoPreset[] = [
  { id: 0, label: '左前大腿' },
  { id: 2, label: '左前小腿' },
  { id: 4, label: '右前大腿' },
  { id: 6, label: '右前小腿' },
  { id: 8, label: '右后大腿' },
  { id: 10, label: '右后小腿' },
  { id: 12, label: '左后大腿' },
  { id: 14, label: '左后小腿' }
]

const MIN_SERVO_ANGLE: number = -90
const MAX_SERVO_ANGLE: number = 90

export class ServoCalibrationService {
  static async ensureTokenReady(): Promise<void> {
    if (CommonConstant.token && CommonConstant.token.length > 0) {
      return
    }

    const token: string = await authService.login()
    CommonConstant.token = token
  }

  static clampAngle(angle: number): number {
    const roundedAngle: number = Math.round(angle)
    return Math.max(MIN_SERVO_ANGLE, Math.min(MAX_SERVO_ANGLE, roundedAngle))
  }

  static validateServoId(servoId: number): void {
    if (!Number.isInteger(servoId) || SUPPORTED_SERVO_IDS.indexOf(servoId) < 0) {
      throw new Error(`当前设备仅接了 8 个舵机，可用通道为 ${SUPPORTED_SERVO_ID_TEXT}`)
    }
  }

  static async setServoAngle(servoId: number, angle: number): Promise<void> {
    ServoCalibrationService.validateServoId(servoId)
    await ServoCalibrationService.ensureTokenReady()

    const paras: ServoAngleCommandParas = new ServoAngleCommandParas()
    paras.servo_id = servoId
    paras.angle = ServoCalibrationService.clampAngle(angle)

    const payload: ServoCommandMessage = new ServoCommandMessage()
    payload.command_name = 'servo_set'
    payload.paras = paras
    await IotConnector.sendMessage(payload)
  }

  static async straightenLegs(): Promise<void> {
    await ServoCalibrationService.ensureTokenReady()

    const payload: StraightLegCommandMessage = new StraightLegCommandMessage()
    payload.command_name = 'legs_straight'
    await IotConnector.sendMessage(payload)
  }
}
