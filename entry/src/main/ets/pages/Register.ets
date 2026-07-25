import { LottieView } from "../utils/LottieView"
import promptAction from '@ohos.promptAction'
import { SurfaceCard } from '../components/SurfaceCard'
import { PrimaryButton } from '../components/PrimaryButton'
import { LabeledInput } from '../components/LabeledInput'
import { isTablet } from '../theme/Theme'

export interface RegisterParams {
  uname: string
  upass: string
}

@Builder
export function RegisterBuilder() {
  Register()
}

@Entry
@Component
struct Register {
  pathStack: NavPathStack = new NavPathStack()

  @State uname: string = ''
  @State upass: string = ''
  @State confirmPass: string = ''
  @State bgRotateAngle: number = 0
  @State formOpacity: number = 0
  @State formTranslateY: number = 40
  @State pageWidth: number = 0

  aboutToAppear(): void {
    setTimeout((): void => {
      this.startBgAnimation()
    }, 80)

    setTimeout((): void => {
      animateTo({ duration: 680, curve: Curve.EaseOut }, (): void => {
        this.formOpacity = 1
        this.formTranslateY = 0
      })
    }, 180)
  }

  startBgAnimation(): void {
    animateTo({
      duration: 22000,
      curve: Curve.Linear,
      iterations: -1
    }, (): void => {
      this.bgRotateAngle = 360
    })
  }

  private handleNextStep(): void {
    if (this.uname === '' || this.upass === '' || this.confirmPass === '') {
      promptAction.showToast({ message: "请填写完整信息" })
      return
    }
    if (this.upass !== this.confirmPass) {
      promptAction.showToast({ message: "两次密码不一致" })
      return
    }
    const acc: number = Number(this.uname)
    if (isNaN(acc)) {
      promptAction.showToast({ message: "账号必须为数字" })
      return
    }

    const params: RegisterParams = {
      uname: this.uname,
      upass: this.upass
    }
    this.pathStack.pushPath({ name: "UserInfoFill", param: params })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // 背景渐变
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [$r('app.color.brand_primary_subtle'), 0.0],
              [$r('app.color.page_bg_alt'), 0.56],
              [$r('app.color.page_bg'), 1.0]
            ]
          })

        // 装饰圆
        Circle()
          .width(420)
          .height(420)
          .fill('#2E2D7EF0')
          .position({ x: 230, y: -170 })
          .rotate({ angle: this.bgRotateAngle })

        Circle()
          .width(320)
          .height(320)
          .fill('#215B9EFF')
          .position({ x: -130, y: 320 })
          .rotate({ angle: -this.bgRotateAngle * 0.5 })

        Scroll() {
          Column({ space: 16 }) {
            // 返回按钮
            Row() {
              Image($r('app.media.arrow_return'))
                .width(24)
                .height(24)
                .fillColor($r('app.color.text_primary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ top: 18, left: 4 })
            .onClick(() => this.pathStack.pop())

            // 标题
            Column({ space: 6 }) {
              Text('创建账号')
                .fontSize($r('app.float.font_size_display'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text('注册后即可完善宠物信息并登录')
                .fontSize($r('app.float.font_size_body'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 4, right: 4, top: 6 })

            // 表单卡（外层 Column 用于承载 .opacity / .translate）
            Column() {
            SurfaceCard({ contentPadding: 22, radius: 28, emphasized: true }) {
              Column({ space: 20 }) {
                LottieView({ name: "register_lottie" })
                  .width(isTablet(this.pageWidth) ? 190 : 160)
                  .height(isTablet(this.pageWidth) ? 190 : 160)

                Column({ space: 14 }) {
                  LabeledInput({
                    icon: $r('app.media.usra'),
                    placeholder: '请输入账号 (数字 ID)',
                    text: $uname,
                    inputType: InputType.Number,
                    inputHeight: 56
                  })

                  LabeledInput({
                    icon: $r('app.media.lock'),
                    placeholder: '设置密码',
                    text: $upass,
                    inputType: InputType.Password,
                    inputHeight: 56
                  })

                  LabeledInput({
                    icon: $r('app.media.lock'),
                    placeholder: '确认密码',
                    text: $confirmPass,
                    inputType: InputType.Password,
                    inputHeight: 56
                  })
                }
                .width('100%')

                Column({ space: 12 }) {
                  PrimaryButton({
                    text: '下一步',
                    onTap: (): void => {
                      this.handleNextStep()
                    }
                  })

                  Button('已有账号，去登录')
                    .width('100%')
                    .height(52)
                    .backgroundColor($r('app.color.brand_primary_subtle'))
                    .fontColor($r('app.color.brand_primary'))
                    .fontSize($r('app.float.font_size_subtitle'))
                    .fontWeight(FontWeight.Medium)
                    .borderRadius(26)
                    .onClick(() => this.pathStack.pop())
                }
                .width('100%')
              }
            }
            }
            .opacity(this.formOpacity)
            .translate({ y: this.formTranslateY })

            Text('完成本步骤后继续完善头像、昵称与唤醒词')
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ bottom: 16, top: 10 })
          }
          .width(isTablet(this.pageWidth) ? 500 : '100%')
          .align(Alignment.Center)
          .padding({
            left: isTablet(this.pageWidth) ? 0 : 16,
            right: isTablet(this.pageWidth) ? 0 : 16
          })
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .onAreaChange((oldValue: Area, newValue: Area): void => {
          const width: number = Number(newValue.width)
          if (!Number.isNaN(width)) {
            this.pageWidth = width
          }
        })
      }
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pathStack = context.pathStack
      // 字体注册已统一移至 EntryAbility.onCreate
    })
  }
}
