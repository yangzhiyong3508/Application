import {
  MotionTuningConfig,
  MotionTuningService,
  MotionTuningValues
} from '../utils/MotionTuningService'
import { SurfaceCard } from '../components/SurfaceCard'
import { StatusChip, ChipTone } from '../components/StatusChip'
import { isTablet } from '../theme/Theme'

@Builder
export function MotionTuningBuilder() {
  MotionTuningPage()
}

@Entry
@Component
struct MotionTuningPage {
  pathStack: NavPathStack = new NavPathStack()

  @State isConfigReady: boolean = false
  @State isBusy: boolean = false
  @State statusText: string = '正在读取运动参数'
  @State lastCommandText: string = '尚未下发参数'
  @State pageWidth: number = 0

  @State frontBodyHeightDeltaMm: number = 0
  @State rearBodyHeightDeltaMm: number = -10
  @State stepLengthMm: number = 17
  @State stepHeightMm: number = 12
  @State speedLevel: number = 5
  @State frontMinMm: number = -40
  @State frontMaxMm: number = 40
  @State rearMinMm: number = -40
  @State rearMaxMm: number = 40

  private frontHipAdductionDeg: number = 0
  private rearHipAdductionDeg: number = 0
  private thighLengthMm: number = 107
  private calfLengthMm: number = 135

  async aboutToAppear(): Promise<void> {
    await this.loadConfig(false)
  }

  private getErrorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return JSON.stringify(error)
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (error) {
      console.error('[MotionTuning] toast failed: ' + JSON.stringify(error))
    }
  }

  private currentValues(): MotionTuningValues {
    const values: MotionTuningValues = new MotionTuningValues()
    values.frontBodyHeightDeltaMm = this.frontBodyHeightDeltaMm
    values.rearBodyHeightDeltaMm = this.rearBodyHeightDeltaMm
    values.stepLengthMm = this.stepLengthMm
    values.stepHeightMm = this.stepHeightMm
    values.speedLevel = this.speedLevel
    values.frontHipAdductionDeg = this.frontHipAdductionDeg
    values.rearHipAdductionDeg = this.rearHipAdductionDeg
    values.thighLengthMm = this.thighLengthMm
    values.calfLengthMm = this.calfLengthMm
    return values
  }

  private applyValuesToState(values: MotionTuningValues): void {
    this.frontBodyHeightDeltaMm = values.frontBodyHeightDeltaMm
    this.rearBodyHeightDeltaMm = values.rearBodyHeightDeltaMm
    this.stepLengthMm = values.stepLengthMm
    this.stepHeightMm = values.stepHeightMm
    this.speedLevel = values.speedLevel
    this.frontHipAdductionDeg = values.frontHipAdductionDeg
    this.rearHipAdductionDeg = values.rearHipAdductionDeg
    this.thighLengthMm = values.thighLengthMm
    this.calfLengthMm = values.calfLengthMm
  }

  private formatSignedMm(value: number): string {
    if (value > 0) {
      return '+' + value.toString() + ' mm'
    }
    return value.toString() + ' mm'
  }

  private async loadConfig(showSuccessToast: boolean): Promise<void> {
    if (this.isBusy) {
      return
    }
    this.isBusy = true
    this.statusText = '正在读取运动参数'
    try {
      const config: MotionTuningConfig = await MotionTuningService.loadConfig()
      this.frontMinMm = config.frontBodyHeightDeltaMinMm
      this.frontMaxMm = config.frontBodyHeightDeltaMaxMm
      this.rearMinMm = config.rearBodyHeightDeltaMinMm
      this.rearMaxMm = config.rearBodyHeightDeltaMaxMm
      const values: MotionTuningValues = MotionTuningService.valuesFromConfig(config)
      this.applyValuesToState(values)
      MotionTuningService.saveLocalValues(values)
      this.isConfigReady = true
      this.statusText = '后端已连接 · 可调整姿态与步态'
      this.lastCommandText = '已同步设备当前俯仰/速度，步长步高使用本机设置'
      if (showSuccessToast) {
        this.showToast('运动参数已刷新')
      }
    } catch (error) {
      const local: MotionTuningValues = MotionTuningService.loadLocalValues()
      this.applyValuesToState(local)
      this.isConfigReady = false
      this.statusText = this.getErrorMessage(error)
      this.lastCommandText = '后端未连接，仅可改本地步长/步高；俯仰与速度需联网下发'
      this.showToast(this.statusText)
    } finally {
      this.isBusy = false
    }
  }

  private async applyAll(): Promise<void> {
    if (this.isBusy) {
      return
    }
    this.isBusy = true
    try {
      const values: MotionTuningValues = this.currentValues()
      values.frontBodyHeightDeltaMm =
        MotionTuningService.clampBodyHeightMm(values.frontBodyHeightDeltaMm)
      values.rearBodyHeightDeltaMm =
        MotionTuningService.clampBodyHeightMm(values.rearBodyHeightDeltaMm)
      values.stepLengthMm = MotionTuningService.clampStepLengthMm(values.stepLengthMm)
      values.stepHeightMm = MotionTuningService.clampStepHeightMm(values.stepHeightMm)
      values.speedLevel = MotionTuningService.clampSpeedLevel(values.speedLevel)
      this.applyValuesToState(values)
      MotionTuningService.saveLocalValues(values)

      await MotionTuningService.applyRuntimeTuning(values)
      this.isConfigReady = true
      this.statusText = '参数已下发'
      this.lastCommandText = '前俯仰 ' + values.frontBodyHeightDeltaMm.toString() +
        'mm / 后俯仰 ' + values.rearBodyHeightDeltaMm.toString() +
        'mm / 速度 ' + values.speedLevel.toString() +
        ' / 步长 ' + values.stepLengthMm.toString() +
        'mm / 步高 ' + values.stepHeightMm.toString() + 'mm'
      this.showToast('运动参数已保存并下发')
    } catch (error) {
      const message: string = this.getErrorMessage(error)
      this.lastCommandText = '下发失败：' + message
      this.showToast(message)
    } finally {
      this.isBusy = false
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg_alt'))

        Column()
          .width('100%')
          .height(250)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [$r('app.color.brand_gradient_start'), 0],
              [$r('app.color.brand_gradient_end'), 1]
            ]
          })

        Scroll() {
          Column({ space: 16 }) {
            Row() {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Circle()
                    .width(38)
                    .height(38)
                    .fill('#2EFFFFFF')

                  Image($r('app.media.arrow_return'))
                    .width(18)
                    .height(18)
                    .fillColor($r('app.color.text_on_brand'))
                }
                .onClick(() => this.pathStack.pop())

                Column({ space: 4 }) {
                  Text('运动调参')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_on_brand'))

                  Text('前后俯仰 · 步长步高 · 速度')
                    .fontSize($r('app.float.font_size_body'))
                    .fontColor('#D1FFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)

              StatusChip({
                label: this.isConfigReady ? '后端已连接' : this.isBusy ? '加载中' : '本地模式',
                tone: this.isConfigReady ? ChipTone.Success : ChipTone.Warning,
                showDot: true
              })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ top: 22, left: 2, right: 2 })

            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 10 }) {
                Text('状态')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                Text(this.statusText)
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
                Text(this.lastCommandText)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SurfaceCard({ contentPadding: 18, radius: 24 }) {
              Column({ space: 18 }) {
                Text('前后俯仰角')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Text('通过前后机身高度差形成俯仰；正值抬高对应端')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                Column({ space: 8 }) {
                  Row() {
                    Text('前俯仰')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Text(this.formatSignedMm(this.frontBodyHeightDeltaMm))
                      .fontSize(14)
                      .fontColor($r('app.color.brand_primary'))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Slider({
                    value: this.frontBodyHeightDeltaMm,
                    min: this.frontMinMm,
                    max: this.frontMaxMm,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .width('100%')
                    .selectedColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .blockColor($r('app.color.brand_primary'))
                    .onChange((v: number) => {
                      this.frontBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(v)
                    })
                }
                .width('100%')

                Column({ space: 8 }) {
                  Row() {
                    Text('后俯仰')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Text(this.formatSignedMm(this.rearBodyHeightDeltaMm))
                      .fontSize(14)
                      .fontColor($r('app.color.brand_primary'))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Slider({
                    value: this.rearBodyHeightDeltaMm,
                    min: this.rearMinMm,
                    max: this.rearMaxMm,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .width('100%')
                    .selectedColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .blockColor($r('app.color.brand_primary'))
                    .onChange((v: number) => {
                      this.rearBodyHeightDeltaMm = MotionTuningService.clampBodyHeightMm(v)
                    })
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SurfaceCard({ contentPadding: 18, radius: 24 }) {
              Column({ space: 18 }) {
                Text('步态参数')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Text('遥控前进/后退时随指令下发；转向与停止不带步长步高')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                Column({ space: 8 }) {
                  Row() {
                    Text('步长')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Text(this.stepLengthMm.toString() + ' mm')
                      .fontSize(14)
                      .fontColor($r('app.color.brand_primary'))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Slider({
                    value: this.stepLengthMm,
                    min: 0,
                    max: 50,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .width('100%')
                    .selectedColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .blockColor($r('app.color.brand_primary'))
                    .onChange((v: number) => {
                      this.stepLengthMm = MotionTuningService.clampStepLengthMm(v)
                    })
                }
                .width('100%')

                Column({ space: 8 }) {
                  Row() {
                    Text('步高')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Text(this.stepHeightMm.toString() + ' mm')
                      .fontSize(14)
                      .fontColor($r('app.color.brand_primary'))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Slider({
                    value: this.stepHeightMm,
                    min: 0,
                    max: 50,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .width('100%')
                    .selectedColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .blockColor($r('app.color.brand_primary'))
                    .onChange((v: number) => {
                      this.stepHeightMm = MotionTuningService.clampStepHeightMm(v)
                    })
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SurfaceCard({ contentPadding: 18, radius: 24 }) {
              Column({ space: 18 }) {
                Text('运动速度')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Text('设备 speed_level，范围 0~6（与语音语速无关）')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                Column({ space: 8 }) {
                  Row() {
                    Text('速度等级')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Text('Lv ' + this.speedLevel.toString())
                      .fontSize(14)
                      .fontColor($r('app.color.brand_primary'))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Slider({
                    value: this.speedLevel,
                    min: 0,
                    max: 6,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .width('100%')
                    .selectedColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .blockColor($r('app.color.brand_primary'))
                    .onChange((v: number) => {
                      this.speedLevel = MotionTuningService.clampSpeedLevel(v)
                    })
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Row({ space: 12 }) {
              Button('刷新')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.surface_card'))
                .fontColor($r('app.color.text_primary'))
                .borderRadius(16)
                .enabled(!this.isBusy)
                .onClick(() => {
                  this.loadConfig(true)
                })

              Button(this.isBusy ? '处理中…' : '保存并下发')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .backgroundColor($r('app.color.brand_primary'))
                .fontColor($r('app.color.text_on_brand'))
                .borderRadius(16)
                .enabled(!this.isBusy)
                .onClick(() => {
                  this.applyAll()
                })
            }
            .width('100%')
            .padding({ bottom: 28 })
          }
          .width('100%')
          .padding({
            left: isTablet(this.pageWidth) ? 28 : 18,
            right: isTablet(this.pageWidth) ? 28 : 18,
            top: 8,
            bottom: 12
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const width: number = Number(newValue.width)
      if (width > 0) {
        this.pageWidth = width
      }
    })
  }
}
