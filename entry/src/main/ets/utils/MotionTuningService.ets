import http from '@ohos.net.http'

const DEFAULT_BACKEND_HOST: string = '118.195.133.25'
const BACKEND_PORT: number = 8080
const DOG_DEBUG_API_PATH: string = '/api/dog-debug'

const STEP_LENGTH_MIN_MM: number = 0
const STEP_LENGTH_MAX_MM: number = 50
const STEP_HEIGHT_MIN_MM: number = 0
const STEP_HEIGHT_MAX_MM: number = 50
const DEFAULT_STEP_LENGTH_MM: number = 17
const DEFAULT_STEP_HEIGHT_MM: number = 12
const SPEED_LEVEL_MIN: number = 0
const SPEED_LEVEL_MAX: number = 6
const BODY_HEIGHT_MIN_MM: number = -40
const BODY_HEIGHT_MAX_MM: number = 40

export class MotionTuningConfig {
  frontBodyHeightDeltaMinMm: number = BODY_HEIGHT_MIN_MM
  frontBodyHeightDeltaMaxMm: number = BODY_HEIGHT_MAX_MM
  frontBodyHeightDeltaCurrentMm: number = 0
  rearBodyHeightDeltaMinMm: number = BODY_HEIGHT_MIN_MM
  rearBodyHeightDeltaMaxMm: number = BODY_HEIGHT_MAX_MM
  rearBodyHeightDeltaCurrentMm: number = -10
  gaitStepLengthDefaultMm: number = DEFAULT_STEP_LENGTH_MM
  gaitStepHeightDefaultMm: number = DEFAULT_STEP_HEIGHT_MM
  speedLevel: number = 5
  frontHipAdductionDefaultDeg: number = 0
  rearHipAdductionDefaultDeg: number = 0
  thighLengthDefaultMm: number = 107
  calfLengthDefaultMm: number = 135
}

export class MotionTuningValues {
  frontBodyHeightDeltaMm: number = 0
  rearBodyHeightDeltaMm: number = -10
  stepLengthMm: number = DEFAULT_STEP_LENGTH_MM
  stepHeightMm: number = DEFAULT_STEP_HEIGHT_MM
  speedLevel: number = 5
  frontHipAdductionDeg: number = 0
  rearHipAdductionDeg: number = 0
  thighLengthMm: number = 107
  calfLengthMm: number = 135
}

export class MotionCommandResult {
  ok: boolean = false
  payloads: string[] = []
}

class MotionErrorResponse {
  error: string = ''
}

class RuntimeTuningRequestBody {
  frontHipAdductionDeg: number = 0
  rearHipAdductionDeg: number = 0
  bodyPitchDeg: number = 0
  frontBodyHeightDeltaMm: number = 0
  rearBodyHeightDeltaMm: number = -10
  imuBalanceStrengthPercent: number = 0
  thighLengthMm: number = 107
  calfLengthMm: number = 135
  speedLevel: number = 5
}

class SpeedRequestBody {
  level: number = 5
}

class BodyHeightRequestBody {
  frontBodyHeightDeltaMm: number = 0
  rearBodyHeightDeltaMm: number = -10
}

export class MotionTuningService {
  static clampStepLengthMm(value: number): number {
    return Math.max(STEP_LENGTH_MIN_MM, Math.min(STEP_LENGTH_MAX_MM, Math.round(value)))
  }

  static clampStepHeightMm(value: number): number {
    return Math.max(STEP_HEIGHT_MIN_MM, Math.min(STEP_HEIGHT_MAX_MM, Math.round(value)))
  }

  static clampSpeedLevel(value: number): number {
    return Math.max(SPEED_LEVEL_MIN, Math.min(SPEED_LEVEL_MAX, Math.round(value)))
  }

  static clampBodyHeightMm(value: number): number {
    return Math.max(BODY_HEIGHT_MIN_MM, Math.min(BODY_HEIGHT_MAX_MM, Math.round(value)))
  }

  static stepLengthMinMm(): number {
    return STEP_LENGTH_MIN_MM
  }

  static stepLengthMaxMm(): number {
    return STEP_LENGTH_MAX_MM
  }

  static stepHeightMinMm(): number {
    return STEP_HEIGHT_MIN_MM
  }

  static stepHeightMaxMm(): number {
    return STEP_HEIGHT_MAX_MM
  }

  static speedLevelMin(): number {
    return SPEED_LEVEL_MIN
  }

  static speedLevelMax(): number {
    return SPEED_LEVEL_MAX
  }

  static bodyHeightMinMm(): number {
    return BODY_HEIGHT_MIN_MM
  }

  static bodyHeightMaxMm(): number {
    return BODY_HEIGHT_MAX_MM
  }

  static defaultStepLengthMm(): number {
    return DEFAULT_STEP_LENGTH_MM
  }

  static defaultStepHeightMm(): number {
    return DEFAULT_STEP_HEIGHT_MM
  }

  static loadLocalValues(): MotionTuningValues {
    const values: MotionTuningValues = new MotionTuningValues()
    const front: number | undefined = AppStorage.get<number>('frontBodyHeightDeltaMm')
    const rear: number | undefined = AppStorage.get<number>('rearBodyHeightDeltaMm')
    const stepLength: number | undefined = AppStorage.get<number>('gaitStepLengthMm')
    const stepHeight: number | undefined = AppStorage.get<number>('gaitStepHeightMm')
    const speed: number | undefined = AppStorage.get<number>('motionSpeedLevel')
    if (front !== undefined) {
      values.frontBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(front)
    }
    if (rear !== undefined) {
      values.rearBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(rear)
    }
    if (stepLength !== undefined) {
      values.stepLengthMm = MotionTuningService.clampStepLengthMm(stepLength)
    }
    if (stepHeight !== undefined) {
      values.stepHeightMm = MotionTuningService.clampStepHeightMm(stepHeight)
    }
    if (speed !== undefined) {
      values.speedLevel = MotionTuningService.clampSpeedLevel(speed)
    }
    return values
  }

  static saveLocalValues(values: MotionTuningValues): void {
    AppStorage.setOrCreate('frontBodyHeightDeltaMm',
      MotionTuningService.clampBodyHeightMm(values.frontBodyHeightDeltaMm))
    AppStorage.setOrCreate('rearBodyHeightDeltaMm',
      MotionTuningService.clampBodyHeightMm(values.rearBodyHeightDeltaMm))
    AppStorage.setOrCreate('gaitStepLengthMm',
      MotionTuningService.clampStepLengthMm(values.stepLengthMm))
    AppStorage.setOrCreate('gaitStepHeightMm',
      MotionTuningService.clampStepHeightMm(values.stepHeightMm))
    AppStorage.setOrCreate('motionSpeedLevel',
      MotionTuningService.clampSpeedLevel(values.speedLevel))
  }

  static async loadConfig(): Promise<MotionTuningConfig> {
    const request: http.HttpRequest = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: { 'Content-Type': 'application/json' },
      connectTimeout: 5000,
      readTimeout: 8000
    }
    try {
      const response = await request.request(MotionTuningService.backendUrl('/config'), options)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(MotionTuningService.responseError(
          response.result,
          '读取运动参数失败，HTTP ' + response.responseCode.toString()
        ))
      }
      const resultText: string = MotionTuningService.resultText(response.result)
      const config: MotionTuningConfig = JSON.parse(resultText)
      return MotionTuningService.normalizeConfig(config)
    } catch (error) {
      if (error instanceof Error) {
        throw error
      }
      throw new Error('读取运动参数失败：' + JSON.stringify(error))
    } finally {
      request.destroy()
    }
  }

  static valuesFromConfig(config: MotionTuningConfig): MotionTuningValues {
    const values: MotionTuningValues = new MotionTuningValues()
    values.frontBodyHeightDeltaMm =
      MotionTuningService.clampBodyHeightMm(config.frontBodyHeightDeltaCurrentMm)
    values.rearBodyHeightDeltaMm =
      MotionTuningService.clampBodyHeightMm(config.rearBodyHeightDeltaCurrentMm)
    values.speedLevel = MotionTuningService.clampSpeedLevel(config.speedLevel)
    values.frontHipAdductionDeg = Math.round(config.frontHipAdductionDefaultDeg)
    values.rearHipAdductionDeg = Math.round(config.rearHipAdductionDefaultDeg)
    values.thighLengthMm = Math.round(config.thighLengthDefaultMm)
    values.calfLengthMm = Math.round(config.calfLengthDefaultMm)

    const local: MotionTuningValues = MotionTuningService.loadLocalValues()
    values.stepLengthMm = local.stepLengthMm
    values.stepHeightMm = local.stepHeightMm
    if (AppStorage.get<number>('gaitStepLengthMm') === undefined &&
      config.gaitStepLengthDefaultMm > 0) {
      // Prefer app remote default 17mm over debug page 10mm when first open.
      values.stepLengthMm = MotionTuningService.defaultStepLengthMm()
    }
    if (AppStorage.get<number>('gaitStepHeightMm') === undefined &&
      config.gaitStepHeightDefaultMm > 0) {
      values.stepHeightMm = MotionTuningService.defaultStepHeightMm()
    }
    return values
  }

  static async applyRuntimeTuning(values: MotionTuningValues): Promise<MotionCommandResult> {
    const body: RuntimeTuningRequestBody = new RuntimeTuningRequestBody()
    body.frontHipAdductionDeg = Math.round(values.frontHipAdductionDeg)
    body.rearHipAdductionDeg = Math.round(values.rearHipAdductionDeg)
    body.bodyPitchDeg = 0
    body.frontBodyHeightDeltaMm =
      MotionTuningService.clampBodyHeightMm(values.frontBodyHeightDeltaMm)
    body.rearBodyHeightDeltaMm =
      MotionTuningService.clampBodyHeightMm(values.rearBodyHeightDeltaMm)
    body.imuBalanceStrengthPercent = 0
    body.thighLengthMm = Math.round(values.thighLengthMm)
    body.calfLengthMm = Math.round(values.calfLengthMm)
    body.speedLevel = MotionTuningService.clampSpeedLevel(values.speedLevel)
    return MotionTuningService.postCommand('/runtime-tuning', JSON.stringify(body))
  }

  static async applySpeed(level: number): Promise<MotionCommandResult> {
    const body: SpeedRequestBody = new SpeedRequestBody()
    body.level = MotionTuningService.clampSpeedLevel(level)
    return MotionTuningService.postCommand('/speed', JSON.stringify(body))
  }

  static async applyBodyHeight(frontMm: number, rearMm: number): Promise<MotionCommandResult> {
    const body: BodyHeightRequestBody = new BodyHeightRequestBody()
    body.frontBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(frontMm)
    body.rearBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(rearMm)
    return MotionTuningService.postCommand('/body-height', JSON.stringify(body))
  }

  private static normalizeConfig(config: MotionTuningConfig): MotionTuningConfig {
    const normalized: MotionTuningConfig = new MotionTuningConfig()
    if (config.frontBodyHeightDeltaMinMm !== undefined) {
      normalized.frontBodyHeightDeltaMinMm = config.frontBodyHeightDeltaMinMm
    }
    if (config.frontBodyHeightDeltaMaxMm !== undefined) {
      normalized.frontBodyHeightDeltaMaxMm = config.frontBodyHeightDeltaMaxMm
    }
    if (config.frontBodyHeightDeltaCurrentMm !== undefined) {
      normalized.frontBodyHeightDeltaCurrentMm = config.frontBodyHeightDeltaCurrentMm
    }
    if (config.rearBodyHeightDeltaMinMm !== undefined) {
      normalized.rearBodyHeightDeltaMinMm = config.rearBodyHeightDeltaMinMm
    }
    if (config.rearBodyHeightDeltaMaxMm !== undefined) {
      normalized.rearBodyHeightDeltaMaxMm = config.rearBodyHeightDeltaMaxMm
    }
    if (config.rearBodyHeightDeltaCurrentMm !== undefined) {
      normalized.rearBodyHeightDeltaCurrentMm = config.rearBodyHeightDeltaCurrentMm
    }
    if (config.gaitStepLengthDefaultMm !== undefined && config.gaitStepLengthDefaultMm > 0) {
      normalized.gaitStepLengthDefaultMm = config.gaitStepLengthDefaultMm
    }
    if (config.gaitStepHeightDefaultMm !== undefined && config.gaitStepHeightDefaultMm > 0) {
      normalized.gaitStepHeightDefaultMm = config.gaitStepHeightDefaultMm
    }
    if (config.speedLevel !== undefined) {
      normalized.speedLevel = MotionTuningService.clampSpeedLevel(config.speedLevel)
    }
    if (config.frontHipAdductionDefaultDeg !== undefined) {
      normalized.frontHipAdductionDefaultDeg = config.frontHipAdductionDefaultDeg
    }
    if (config.rearHipAdductionDefaultDeg !== undefined) {
      normalized.rearHipAdductionDefaultDeg = config.rearHipAdductionDefaultDeg
    }
    if (config.thighLengthDefaultMm !== undefined) {
      normalized.thighLengthDefaultMm = config.thighLengthDefaultMm
    }
    if (config.calfLengthDefaultMm !== undefined) {
      normalized.calfLengthDefaultMm = config.calfLengthDefaultMm
    }
    return normalized
  }

  private static backendUrl(path: string): string {
    const host: string = AppStorage.get<string>('localhost') || DEFAULT_BACKEND_HOST
    return 'http://' + host + ':' + BACKEND_PORT.toString() + DOG_DEBUG_API_PATH + path
  }

  private static async postCommand(path: string, bodyText: string): Promise<MotionCommandResult> {
    const request: http.HttpRequest = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: bodyText,
      connectTimeout: 5000,
      readTimeout: 15000
    }
    try {
      const response = await request.request(MotionTuningService.backendUrl(path), options)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(MotionTuningService.responseError(
          response.result,
          '运动参数下发失败，HTTP ' + response.responseCode.toString()
        ))
      }
      const resultText: string = MotionTuningService.resultText(response.result)
      const result: MotionCommandResult = JSON.parse(resultText)
      if (!result.ok) {
        throw new Error('后端未确认运动参数')
      }
      return result
    } catch (error) {
      if (error instanceof Error) {
        throw error
      }
      throw new Error('运动参数下发失败：' + JSON.stringify(error))
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
    const text: string = MotionTuningService.resultText(result)
    if (text.length === 0) {
      return fallback
    }
    try {
      const errorResponse: MotionErrorResponse = JSON.parse(text)
      if (errorResponse.error && errorResponse.error.length > 0) {
        return errorResponse.error
      }
    } catch (error) {
      return fallback
    }
    return fallback
  }
}
