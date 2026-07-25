import {
  ServoCalibrationConfig,
  ServoCalibrationService,
  ServoChannelConfig
} from '../utils/ServoCalibrationService'
import { SurfaceCard } from '../components/SurfaceCard'
import { StatusChip, ChipTone } from '../components/StatusChip'
import { isTablet } from '../theme/Theme'

const QUICK_ANGLE_STEPS: number[] = [-10, -1, 0, 1, 10]

class ServoLegGroup {
  key: string
  label: string

  constructor(key: string, label: string) {
    this.key = key
    this.label = label
  }
}

const SERVO_LEG_GROUPS: ServoLegGroup[] = [
  new ServoLegGroup('LF', 'LF 左前腿'),
  new ServoLegGroup('RF', 'RF 右前腿'),
  new ServoLegGroup('LB', 'LB 左后腿'),
  new ServoLegGroup('RB', 'RB 右后腿')
]

@Builder
export function ServoAdjustBuilder() {
  ServoAdjustPage()
}

@Entry
@Component
struct ServoAdjustPage {
  pathStack: NavPathStack = new NavPathStack()

  @State config: ServoCalibrationConfig = new ServoCalibrationConfig()
  @State activeChannels: ServoChannelConfig[] = []
  @State physicalAngles: number[] = []
  @State selectedChannel: number = -1
  @State isConfigReady: boolean = false
  @State isBusy: boolean = false
  @State statusText: string = '正在读取后端配置'
  @State lastCommandText: string = '尚未发送校准指令'
  @State pageWidth: number = 0

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
      console.error('[ServoAdjust] toast failed: ' + JSON.stringify(error))
    }
  }

  private async loadConfig(showSuccessToast: boolean): Promise<void> {
    if (this.isBusy) {
      return
    }

    this.isBusy = true
    this.statusText = '正在读取后端配置'
    try {
      const loaded: ServoCalibrationConfig = await ServoCalibrationService.loadConfig()
      const active: ServoChannelConfig[] = ServoCalibrationService.activeChannels(loaded.channels)
      this.config = loaded
      this.activeChannels = active
      this.physicalAngles = loaded.physicalAngles.slice()
      this.selectedChannel = active[0].channel
      this.isConfigReady = true
      this.statusText = '后端已连接 · 12 路有效通道'
      this.lastCommandText = '已加载网页端同源的 12DOF 校准配置'
      if (showSuccessToast) {
        this.showToast('12DOF 舵机配置已刷新')
      }
    } catch (error) {
      this.isConfigReady = false
      this.activeChannels = []
      this.physicalAngles = []
      this.selectedChannel = -1
      this.statusText = this.getErrorMessage(error)
      this.showToast(this.statusText)
    } finally {
      this.isBusy = false
    }
  }

  private isSelected(channel: number): boolean {
    return this.selectedChannel === channel
  }

  private selectChannel(channel: number): void {
    this.selectedChannel = channel
  }

  private currentAngle(): number {
    if (this.selectedChannel < 0 || this.selectedChannel >= this.physicalAngles.length) {
      return this.config.servoCenterAngle
    }
    return this.physicalAngles[this.selectedChannel]
  }

  private updateCurrentAngle(angle: number): void {
    if (this.selectedChannel < 0 || this.selectedChannel >= this.physicalAngles.length) {
      return
    }
    const nextAngles: number[] = this.physicalAngles.slice()
    nextAngles[this.selectedChannel] = ServoCalibrationService.clampAngle(angle)
    this.physicalAngles = nextAngles
  }

  private applyQuickStep(step: number): void {
    if (step === 0) {
      this.updateCurrentAngle(this.config.servoCenterAngle)
      return
    }
    this.updateCurrentAngle(this.currentAngle() + step)
  }

  private quickStepLabel(step: number): string {
    if (step === 0) {
      return '中位' + this.config.servoCenterAngle.toString()
    }
    if (step > 0) {
      return '+' + step.toString()
    }
    return step.toString()
  }

  private jointLabel(joint: string): string {
    if (joint === 'HIP') {
      return '髋关节'
    }
    if (joint === 'THIGH') {
      return '大腿'
    }
    if (joint === 'CALF') {
      return '小腿'
    }
    return joint
  }

  private selectedJointLabel(): string {
    for (let index: number = 0; index < this.activeChannels.length; index += 1) {
      if (this.activeChannels[index].channel === this.selectedChannel) {
        return this.activeChannels[index].leg + ' ' + this.jointLabel(this.activeChannels[index].joint)
      }
    }
    return '未选择通道'
  }

  private currentOffset(): number {
    return ServoCalibrationService.calibrationOffset(
      this.currentAngle(),
      this.config.servoCenterAngle
    )
  }

  private signedOffset(): string {
    const offset: number = this.currentOffset()
    return offset > 0 ? '+' + offset.toString() : offset.toString()
  }

  private canSaveCalibration(): boolean {
    return this.isConfigReady && ServoCalibrationService.isCalibrationAngleAllowed(
      this.currentAngle(),
      this.config.servoCenterAngle,
      this.config.servoTrimMaxDeg
    )
  }

  private async sendServoAngle(): Promise<void> {
    if (!this.isConfigReady || this.isBusy || this.selectedChannel < 0) {
      return
    }

    this.isBusy = true
    try {
      const angle: number = this.currentAngle()
      await ServoCalibrationService.setServoAngle(this.selectedChannel, angle)
      this.lastCommandText = '已发送：CH ' + this.selectedChannel.toString() + ' → ' +
        angle.toString() + '°（未保存校准）'
      this.showToast('CH ' + this.selectedChannel.toString() + ' 已发送 ' + angle.toString() + '°')
    } catch (error) {
      this.lastCommandText = '发送失败：' + this.getErrorMessage(error)
      this.showToast(this.lastCommandText)
    } finally {
      this.isBusy = false
    }
  }

  private async saveChannelCalibration(): Promise<void> {
    if (!this.isConfigReady || this.isBusy || this.selectedChannel < 0) {
      return
    }
    if (!this.canSaveCalibration()) {
      this.showToast('校准中位角必须在 45~135° 范围内')
      return
    }

    this.isBusy = true
    try {
      const angle: number = this.currentAngle()
      await ServoCalibrationService.saveChannelCalibration(this.selectedChannel, angle)
      this.lastCommandText = '已保存：CH ' + this.selectedChannel.toString() + ' 物理中位 ' +
        angle.toString() + '°，校准偏移 ' + this.signedOffset() + '°'
      this.showToast('CH ' + this.selectedChannel.toString() + ' 校准已保存并生效')
    } catch (error) {
      this.lastCommandText = '保存失败：' + this.getErrorMessage(error)
      this.showToast(this.lastCommandText)
    } finally {
      this.isBusy = false
    }
  }

  private confirmStraightenLegs(): void {
    if (!this.isConfigReady || this.isBusy) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '确认四腿伸直',
      message: '请先托稳机身并清空机械狗周边，再发送四腿伸直姿态。',
      primaryButton: {
        value: '确认伸直',
        action: () => {
          this.straightenLegs()
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    })
  }

  private async straightenLegs(): Promise<void> {
    if (!this.isConfigReady || this.isBusy) {
      return
    }

    this.isBusy = true
    try {
      await ServoCalibrationService.straightenLegs()
      this.lastCommandText = '已发送：12DOF 四腿伸直姿态'
      this.showToast('四腿伸直姿态已发送')
    } catch (error) {
      this.lastCommandText = '四腿伸直失败：' + this.getErrorMessage(error)
      this.showToast(this.lastCommandText)
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
                  Text('舵机校准')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_on_brand'))

                  Text('EDOG 12DOF · 四腿各 3 个有效通道')
                    .fontSize($r('app.float.font_size_body'))
                    .fontColor('#D1FFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)

              StatusChip({
                label: this.isConfigReady ? '后端已连接' : this.isBusy ? '加载中' : '加载失败',
                tone: this.isConfigReady ? ChipTone.Success : ChipTone.Warning,
                showDot: true
              })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ top: 22, left: 2, right: 2 })

            if (this.isConfigReady) {
              SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
                Column({ space: 14 }) {
                  Text('选择舵机通道')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_primary'))
                    .width('100%')

                  ForEach(SERVO_LEG_GROUPS, (group: ServoLegGroup) => {
                    Column({ space: 8 }) {
                      Text(group.label)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_secondary'))
                        .width('100%')

                      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                        ForEach(ServoCalibrationService.channelsForLeg(this.activeChannels, group.key),
                          (item: ServoChannelConfig) => {
                            Button() {
                              Column({ space: 3 }) {
                                Text('CH ' + item.channel.toString())
                                  .fontSize(16)
                                  .fontWeight(FontWeight.Bold)
                                  .fontColor(this.isSelected(item.channel)
                                    ? $r('app.color.text_on_brand')
                                    : $r('app.color.text_primary'))

                                Text(this.jointLabel(item.joint))
                                  .fontSize(11)
                                  .fontColor(this.isSelected(item.channel)
                                    ? '#D1FFFFFF'
                                    : $r('app.color.text_secondary'))
                              }
                            }
                            .width('31%')
                            .height(58)
                            .backgroundColor(this.isSelected(item.channel)
                              ? $r('app.color.brand_primary')
                              : $r('app.color.brand_primary_subtle'))
                            .borderRadius(16)
                            .onClick(() => this.selectChannel(item.channel))
                          }, (item: ServoChannelConfig) => item.channel.toString())
                      }
                      .width('100%')
                    }
                    .width('100%')
                  }, (group: ServoLegGroup) => group.key)
                }
              }

              SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
                Column({ space: 14 }) {
                  Row() {
                    Column({ space: 4 }) {
                      Text('物理中位角')
                        .fontSize(15)
                        .fontColor($r('app.color.text_secondary'))

                      Text(this.currentAngle().toString() + '°')
                        .fontSize(34)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.text_primary'))
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Column({ space: 4 }) {
                      Text('CH ' + this.selectedChannel.toString())
                        .fontSize(15)
                        .fontColor($r('app.color.brand_primary'))
                        .fontWeight(FontWeight.Medium)

                      Text(this.selectedJointLabel())
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .alignItems(HorizontalAlign.End)
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor($r('app.color.brand_primary_subtle'))
                    .borderRadius(14)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)

                  Slider({
                    value: this.currentAngle(),
                    min: this.config.servoMinAngle,
                    max: this.config.servoMaxAngle,
                    step: 1
                  })
                    .showTips(true)
                    .blockColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .selectedColor($r('app.color.brand_primary'))
                    .onChange((value: number) => this.updateCurrentAngle(value))

                  Row({ space: 8 }) {
                    ForEach(QUICK_ANGLE_STEPS, (step: number) => {
                      Button(this.quickStepLabel(step))
                        .layoutWeight(1)
                        .height(40)
                        .fontSize(12)
                        .fontColor(step === 0
                          ? $r('app.color.brand_primary')
                          : $r('app.color.text_primary'))
                        .backgroundColor(step === 0
                          ? $r('app.color.brand_primary_subtle')
                          : $r('app.color.input_bg'))
                        .borderRadius(14)
                        .onClick(() => this.applyQuickStep(step))
                    }, (step: number) => step.toString())
                  }
                  .width('100%')

                  Row() {
                    Text('校准偏移')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                      .layoutWeight(1)

                    Text(this.signedOffset() + '°')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.canSaveCalibration()
                        ? $r('app.color.state_success')
                        : '#FFD97706')
                  }
                  .width('100%')

                  Text(this.canSaveCalibration()
                    ? '当前角度可保存；偏移按“物理中位角 − 90°”计算。'
                    : '保存校准仅允许 45~135°；临时发送仍可使用 0~180°。')
                    .width('100%')
                    .fontSize(13)
                    .fontColor(this.canSaveCalibration()
                      ? $r('app.color.text_secondary')
                      : '#FFD97706')
                    .lineHeight(20)
                }
              }

              SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
                Column({ space: 12 }) {
                  Button(this.isBusy ? '发送中...' : '发送当前角度')
                    .width('100%')
                    .height(50)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_on_brand'))
                    .backgroundColor($r('app.color.brand_primary'))
                    .borderRadius(18)
                    .enabled(!this.isBusy)
                    .opacity(this.isBusy ? 0.7 : 1)
                    .onClick(() => this.sendServoAngle())

                  Button(this.isBusy ? '请稍候...' : '保存该通道校准')
                    .width('100%')
                    .height(48)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_on_brand'))
                    .backgroundColor(this.canSaveCalibration()
                      ? $r('app.color.state_success')
                      : '#FFB8C2CC')
                    .borderRadius(18)
                    .enabled(!this.isBusy && this.canSaveCalibration())
                    .opacity(!this.isBusy && this.canSaveCalibration() ? 1 : 0.7)
                    .onClick(() => this.saveChannelCalibration())

                  Button(this.isBusy ? '请稍候...' : '四腿伸直')
                    .width('100%')
                    .height(48)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand_primary'))
                    .backgroundColor($r('app.color.brand_primary_subtle'))
                    .borderRadius(18)
                    .enabled(!this.isBusy)
                    .opacity(this.isBusy ? 0.7 : 1)
                    .onClick(() => this.confirmStraightenLegs())

                  Text('四腿伸直会同时驱动 12 个有效通道，发送前会再次要求确认。')
                    .width('100%')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .lineHeight(20)
                }
              }
            }

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
    })
  }
}
