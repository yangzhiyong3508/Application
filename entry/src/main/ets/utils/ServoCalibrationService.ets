import http from '@ohos.net.http'

const DEFAULT_BACKEND_HOST: string = '118.195.133.25'
const BACKEND_PORT: number = 8080
const DOG_DEBUG_API_PATH: string = '/api/dog-debug'
const SERVO_CHANNEL_COUNT: number = 16
const ACTIVE_SERVO_CHANNEL_COUNT: number = 12
const MIN_SERVO_ANGLE: number = 0
const MAX_SERVO_ANGLE: number = 180

export class ServoChannelConfig {
  channel: number = 0
  id: string = ''
  leg: string = ''
  joint: string = ''
  reserved: boolean = false
}

export class ServoCalibrationConfig {
  servoMinAngle: number = MIN_SERVO_ANGLE
  servoMaxAngle: number = MAX_SERVO_ANGLE
  servoCenterAngle: number = 90
  servoTrimMaxDeg: number = 45
  channels: ServoChannelConfig[] = []
  offsets: number[] = []
  physicalAngles: number[] = []
}

export class ServoCommandResult {
  ok: boolean = false
  payloads: string[] = []
}

class ServoErrorResponse {
  error: string = ''
}

class ServoAngleRequestBody {
  channel: number = 0
  angle: number = 90
}

class ServoCalibrationRequestBody {
  channel: number = 0
  physicalAngle: number = 90
  applyNow: boolean = true
}

export class ServoCalibrationService {
  static activeChannels(channels: ServoChannelConfig[]): ServoChannelConfig[] {
    const active: ServoChannelConfig[] = []
    for (let index: number = 0; index < channels.length; index += 1) {
      if (!channels[index].reserved) {
        active.push(channels[index])
      }
    }
    return active
  }

  static channelsForLeg(channels: ServoChannelConfig[], leg: string): ServoChannelConfig[] {
    const grouped: ServoChannelConfig[] = []
    for (let index: number = 0; index < channels.length; index += 1) {
      if (channels[index].leg === leg) {
        grouped.push(channels[index])
      }
    }
    return grouped
  }

  static calibrationOffset(physicalAngle: number, centerAngle: number): number {
    return Math.round(physicalAngle) - Math.round(centerAngle)
  }

  static isCalibrationAngleAllowed(physicalAngle: number, centerAngle: number,
    maxTrim: number): boolean {
    return Math.abs(ServoCalibrationService.calibrationOffset(physicalAngle, centerAngle)) <= maxTrim
  }

  static clampAngle(angle: number): number {
    const roundedAngle: number = Math.round(angle)
    return Math.max(MIN_SERVO_ANGLE, Math.min(MAX_SERVO_ANGLE, roundedAngle))
  }

  static async loadConfig(): Promise<ServoCalibrationConfig> {
    const request: http.HttpRequest = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: { 'Content-Type': 'application/json' },
      connectTimeout: 5000,
      readTimeout: 8000
    }

    try {
      const response = await request.request(
        ServoCalibrationService.backendUrl('/config'),
        options
      )
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(ServoCalibrationService.responseError(
          response.result,
          '读取舵机配置失败，HTTP ' + response.responseCode.toString()
        ))
      }

      const resultText: string = ServoCalibrationService.resultText(response.result)
      const config: ServoCalibrationConfig = JSON.parse(resultText)
      ServoCalibrationService.validateConfig(config)
      return config
    } catch (error) {
      if (error instanceof Error) {
        throw error
      }
      throw new Error('读取舵机配置失败：' + JSON.stringify(error))
    } finally {
      request.destroy()
    }
  }

  static async setServoAngle(channel: number, angle: number): Promise<ServoCommandResult> {
    ServoCalibrationService.validateChannel(channel)
    const body: ServoAngleRequestBody = new ServoAngleRequestBody()
    body.channel = channel
    body.angle = ServoCalibrationService.clampAngle(angle)
    return ServoCalibrationService.postCommand('/servo', JSON.stringify(body))
  }

  static async saveChannelCalibration(channel: number,
    physicalAngle: number): Promise<ServoCommandResult> {
    ServoCalibrationService.validateChannel(channel)
    const body: ServoCalibrationRequestBody = new ServoCalibrationRequestBody()
    body.channel = channel
    body.physicalAngle = ServoCalibrationService.clampAngle(physicalAngle)
    body.applyNow = true
    return ServoCalibrationService.postCommand('/calibration', JSON.stringify(body))
  }

  static async straightenLegs(): Promise<ServoCommandResult> {
    return ServoCalibrationService.postCommand('/straight', '{}')
  }

  private static backendUrl(path: string): string {
    const host: string = AppStorage.get<string>('localhost') || DEFAULT_BACKEND_HOST
    return 'http://' + host + ':' + BACKEND_PORT.toString() + DOG_DEBUG_API_PATH + path
  }

  private static validateChannel(channel: number): void {
    if (!Number.isInteger(channel) || channel < 0 || channel >= SERVO_CHANNEL_COUNT) {
      throw new Error('舵机通道必须在 0~15 范围内')
    }
  }

  private static validateConfig(config: ServoCalibrationConfig): void {
    if (!config.channels || config.channels.length !== SERVO_CHANNEL_COUNT) {
      throw new Error('后端舵机配置必须包含 16 个通道')
    }
    const active: ServoChannelConfig[] = ServoCalibrationService.activeChannels(config.channels)
    if (active.length !== ACTIVE_SERVO_CHANNEL_COUNT) {
      throw new Error('后端舵机配置必须包含 12 个有效通道')
    }
    if (!config.physicalAngles || config.physicalAngles.length !== SERVO_CHANNEL_COUNT) {
      throw new Error('后端舵机配置必须包含 16 个物理中位角')
    }
    if (config.servoMinAngle !== MIN_SERVO_ANGLE || config.servoMaxAngle !== MAX_SERVO_ANGLE) {
      throw new Error('后端舵机物理角度范围必须为 0~180 度')
    }
  }

  private static async postCommand(path: string, bodyText: string): Promise<ServoCommandResult> {
    const request: http.HttpRequest = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: bodyText,
      connectTimeout: 5000,
      readTimeout: 10000
    }

    try {
      const response = await request.request(ServoCalibrationService.backendUrl(path), options)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(ServoCalibrationService.responseError(
          response.result,
          '校准命令请求失败，HTTP ' + response.responseCode.toString()
        ))
      }

      const resultText: string = ServoCalibrationService.resultText(response.result)
      const result: ServoCommandResult = JSON.parse(resultText)
      if (!result.ok) {
        throw new Error('后端未确认校准命令')
      }
      return result
    } catch (error) {
      if (error instanceof Error) {
        throw error
      }
      throw new Error('校准命令请求失败：' + JSON.stringify(error))
    } finally {
      request.destroy()
    }
  }

  private static resultText(result: string | Object): string {
    if (typeof result === 'string') {
      return result
    }
    return JSON.stringify(result)
  }

  private static responseError(result: string | Object, fallback: string): string {
    const text: string = ServoCalibrationService.resultText(result)
    if (text.length === 0) {
      return fallback
    }
    try {
      const errorResponse: ServoErrorResponse = JSON.parse(text)
      if (errorResponse.error && errorResponse.error.length > 0) {
        return errorResponse.error
      }
    } catch (error) {
      return fallback
    }
    return fallback
  }
}
