import promptAction from '@ohos.promptAction'
import { CommonConstant } from '../utils/GetIotToken'
import {
  ServoCalibrationService,
  ServoPreset,
  SUPPORTED_SERVO_IDS,
  SUPPORTED_SERVO_PRESETS
} from '../utils/ServoCalibrationService'
import { SurfaceCard } from '../components/SurfaceCard'
import { StatusChip, ChipTone } from '../components/StatusChip'
import { isTablet } from '../theme/Theme'

const QUICK_ANGLE_STEPS: number[] = [-10, -1, 0, 1, 10]

@Builder
export function ServoAdjustBuilder() {
  ServoAdjustPage()
}

@Entry
@Component
struct ServoAdjustPage {
  pathStack: NavPathStack = new NavPathStack()

  @State selectedServoId: number = SUPPORTED_SERVO_IDS[0]
  @State angle: number = 0
  @State isTokenReady: boolean = false
  @State isSending: boolean = false
  @State lastCommandText: string = '尚未发送校准指令'
  @State pageWidth: number = 0

  private getErrorMessage(err: Object): string {
    if (err instanceof Error) {
      return err.message
    }
    return `${err}`
  }

  async aboutToAppear(): Promise<void> {
    await this.prepareIotToken()
  }

  private async prepareIotToken(showSuccessToast: boolean = false): Promise<void> {
    if (CommonConstant.token && CommonConstant.token.length > 0) {
      this.isTokenReady = true
      return
    }

    try {
      await ServoCalibrationService.ensureTokenReady()
      this.isTokenReady = true
      if (showSuccessToast) {
        promptAction.showToast({ message: '物联网连接已就绪' })
      }
    } catch (err) {
      this.isTokenReady = false
      promptAction.showToast({ message: this.getErrorMessage(err) })
    }
  }

  private isServoSelected(servoId: number): boolean {
    return this.selectedServoId === servoId
  }

  private updateAngle(angle: number): void {
    this.angle = ServoCalibrationService.clampAngle(angle)
  }

  private applyQuickStep(step: number): void {
    if (step === 0) {
      this.updateAngle(0)
      return
    }
    this.updateAngle(this.angle + step)
  }

  private async sendServoAngle(): Promise<void> {
    if (this.isSending) return

    this.isSending = true
    try {
      if (!this.isTokenReady) {
        await this.prepareIotToken()
      }

      await ServoCalibrationService.setServoAngle(this.selectedServoId, this.angle)
      this.lastCommandText = `已发送：舵机 ${this.selectedServoId} -> ${this.angle} 度`
      promptAction.showToast({ message: `舵机 ${this.selectedServoId} 已设置为 ${this.angle} 度` })
    } catch (err) {
      promptAction.showToast({ message: this.getErrorMessage(err) })
    } finally {
      this.isSending = false
    }
  }

  private async straightenLegs(): Promise<void> {
    if (this.isSending) return

    this.isSending = true
    try {
      if (!this.isTokenReady) {
        await this.prepareIotToken()
      }

      await ServoCalibrationService.straightenLegs()
      this.lastCommandText = '已发送：四腿伸直校准姿态'
      promptAction.showToast({ message: '四腿伸直校准姿态已发送' })
    } catch (err) {
      promptAction.showToast({ message: this.getErrorMessage(err) })
    } finally {
      this.isSending = false
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // 页面底
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg_alt'))

        // 顶部蓝色渐变
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
            // 标题栏
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
                  Text('舵机校准')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_on_brand'))

                  Text('只显示实物已接线的 8 个舵机通道')
                    .fontSize($r('app.float.font_size_body'))
                    .fontColor('#D1FFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)

              StatusChip({
                label: this.isTokenReady ? '已连接' : '未连接',
                tone: this.isTokenReady ? ChipTone.Success : ChipTone.Warning,
                showDot: true
              })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ top: 22, left: 2, right: 2 })

            // 说明卡
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 12 }) {
                Text('页面用于矫正舵机零点位置')
                  .fontSize($r('app.float.font_size_body'))
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(22)

                Button('重新连接')
                  .height(40)
                  .fontSize($r('app.float.font_size_body'))
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.brand_primary_subtle'))
                  .borderRadius(20)
                  .onClick(() => this.prepareIotToken(true))
              }
            }

            // 舵机位置（带文字）
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 12 }) {
                Text('舵机位置')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(SUPPORTED_SERVO_PRESETS, (item: ServoPreset) => {
                    Button() {
                      Column({ space: 4 }) {
                        Text(`#${item.id}`)
                          .fontSize(17)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.isServoSelected(item.id)
                            ? $r('app.color.text_on_brand')
                            : $r('app.color.text_primary'))

                        Text(item.label)
                          .fontSize(10)
                          .fontColor(this.isServoSelected(item.id)
                            ? '#D1FFFFFF'
                            : $r('app.color.text_secondary'))
                      }
                      .width('100%')
                    }
                    .width('48%')
                    .height(58)
                    .margin({ bottom: 10 })
                    .backgroundColor(this.isServoSelected(item.id)
                      ? $r('app.color.brand_primary')
                      : $r('app.color.brand_primary_subtle'))
                    .borderRadius(16)
                    .onClick(() => this.selectedServoId = item.id)
                  }, (item: ServoPreset) => `${item.id}`)
                }
                .width('100%')
              }
            }

            // 可用通道编号
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 12 }) {
                Text('可用通道编号')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(SUPPORTED_SERVO_IDS, (item: number) => {
                    Button(`#${item}`)
                      .width('23%')
                      .height(44)
                      .margin({ bottom: 10 })
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.isServoSelected(item)
                        ? $r('app.color.text_on_brand')
                        : $r('app.color.text_secondary'))
                      .backgroundColor(this.isServoSelected(item)
                        ? $r('app.color.brand_primary')
                        : $r('app.color.brand_primary_subtle'))
                      .borderRadius(14)
                      .onClick(() => this.selectedServoId = item)
                  }, (item: number) => `${item}`)
                }
                .width('100%')
              }
            }

            // 角度调节
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 14 }) {
                Row() {
                  Column({ space: 4 }) {
                    Text('目标角度')
                      .fontSize(15)
                      .fontColor($r('app.color.text_secondary'))

                    Text(`${this.angle} 度`)
                      .fontSize(34)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(`舵机 #${this.selectedServoId}`)
                    .fontSize(15)
                    .fontColor($r('app.color.brand_primary'))
                    .fontWeight(FontWeight.Medium)
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor($r('app.color.brand_primary_subtle'))
                    .borderRadius(14)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Slider({ value: this.angle, min: -90, max: 90, step: 1 })
                  .showTips(true)
                  .blockColor($r('app.color.brand_primary'))
                  .trackColor($r('app.color.divider'))
                  .selectedColor($r('app.color.brand_primary'))
                  .onChange((value: number) => this.updateAngle(value))

                Row({ space: 8 }) {
                  ForEach(QUICK_ANGLE_STEPS, (step: number) => {
                    Button(step > 0 ? `+${step}` : step === 0 ? '归零' : `${step}`)
                      .layoutWeight(1)
                      .height(40)
                      .fontSize($r('app.float.font_size_body'))
                      .fontColor(step === 0
                        ? $r('app.color.brand_primary')
                        : $r('app.color.text_primary'))
                      .backgroundColor(step === 0
                        ? $r('app.color.brand_primary_subtle')
                        : $r('app.color.input_bg'))
                      .borderRadius(14)
                      .onClick(() => this.applyQuickStep(step))
                  }, (step: number) => `${step}`)
                }
                .width('100%')
              }
            }

            // 操作按钮
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 12 }) {
                Button(this.isSending ? '发送中...' : '发送当前角度')
                  .width('100%')
                  .height(50)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.brand_primary'))
                  .borderRadius(18)
                  .enabled(!this.isSending)
                  .opacity(this.isSending ? 0.7 : 1)
                  .onClick(() => this.sendServoAngle())

                Button(this.isSending ? '请稍候...' : '发送四腿伸直姿态')
                  .width('100%')
                  .height(48)
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.state_success'))
                  .borderRadius(18)
                  .enabled(!this.isSending)
                  .opacity(this.isSending ? 0.7 : 1)
                  .onClick(() => this.straightenLegs())

                Text('四腿伸直会把 8 个已接线通道同时打到 0 度，适合作为机械零位校准起点。')
                  .width('100%')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(20)
              }
            }

            // 最近操作
            SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
              Column({ space: 8 }) {
                Text('最近操作')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Text(this.lastCommandText)
                  .fontSize($r('app.float.font_size_body'))
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(21)
              }
            }
          }
          .width(isTablet(this.pageWidth) ? 760 : '100%')
          .align(Alignment.Center)
          .padding({
            left: isTablet(this.pageWidth) ? 0 : 16,
            right: isTablet(this.pageWidth) ? 0 : 16,
            top: isTablet(this.pageWidth) ? 18 : 8,
            bottom: 28
          })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
      }
      .backgroundColor($r('app.color.page_bg_alt'))
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      // 字体注册已统一移至 EntryAbility.onCreate
    })
  }
}
