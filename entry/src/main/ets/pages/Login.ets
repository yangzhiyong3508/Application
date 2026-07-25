import { LoginUtil, LoginResult } from '../utils/LoginUtil'
import promptAction from '@ohos.promptAction'
import { LottieView } from "../utils/LottieView"
import { authService, CommonConstant } from '../utils/GetIotToken'
import { DEFAULT_XFYUN_VOICE } from '../utils/XfyunVoiceUtil'
import { SurfaceCard } from '../components/SurfaceCard'
import { PrimaryButton } from '../components/PrimaryButton'
import { LabeledInput } from '../components/LabeledInput'
import { AppShadow, isTablet } from '../theme/Theme'

@Builder
export function LoginBuilder() {
  Login()
}

@Entry
@Component
struct Login {
  @StorageLink('account') account: number = 0
  @StorageLink('password') psw: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('username') username: string = ''
  @StorageLink('avatar') avatar: number | string = 1

  @StorageLink('per') per: number = 4
  @StorageLink('spd') spd: number = 6
  @StorageLink('pid') pid: number = 10

  @StorageLink('vol') vol: number = 50
  @StorageLink('voiceId') voiceId: string = DEFAULT_XFYUN_VOICE
  @StorageLink('speedRatio') speedRatio: number = 1.0
  @StorageLink('wakeWord') wakeWord: string = '小E'

  @State userName: string = ''
  @State password: string = ''
  @State isLoading: boolean = false
  @State pageWidth: number = 0

  pathStack: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    if (this.account) {
      this.userName = this.account.toString()
    }
    if (this.psw) {
      this.password = this.psw
    }
  }

  private async handleLogin(): Promise<void> {
    if (this.userName === '' || this.password === '') {
      promptAction.showToast({ message: '账号和密码不能为空' })
      return
    }

    const accountNumber: number = Number(this.userName)
    if (isNaN(accountNumber)) {
      promptAction.showToast({ message: '账号必须为数字' })
      return
    }

    this.isLoading = true

    try {
      const result: LoginResult = await LoginUtil.login(accountNumber.toString(), this.password)

      if (result.success && result.user) {
        promptAction.showToast({ message: '登录成功' })

        let userAvatar: string | number = result.user.avatarUrl
        if (!userAvatar || userAvatar.length === 0) {
          userAvatar = 1
        }
        AppStorage.setOrCreate('avatar', userAvatar)

        try {
          const iotToken: string = await authService.login()
          CommonConstant.token = iotToken
          setTimeout((): void => {
            promptAction.showToast({ message: 'IoT平台连接成功' })
          }, 200)
        } catch (iotErr) {
          setTimeout((): void => {
            promptAction.showToast({ message: 'IoT平台连接失败，请检查网络' })
          }, 200)
        }

        setTimeout((): void => {
          this.pathStack.pop()
        }, 800)
      } else {
        promptAction.showToast({ message: result.msg })
      }
    } catch (err) {
      promptAction.showToast({ message: '登录失败：网络或服务器异常' })
    } finally {
      this.isLoading = false
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // 背景渐变：浅蓝 → 页面底
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [$r('app.color.brand_primary_subtle'), 0.0],
              [$r('app.color.page_bg_alt'), 0.55],
              [$r('app.color.page_bg'), 1.0]
            ]
          })

        Scroll() {
          Column({ space: 18 }) {
            // 标题区
            Column({ space: 6 }) {
              Text('欢迎回来')
                .fontSize($r('app.float.font_size_display'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text('登录后继续使用智能宠物狗服务')
                .fontSize($r('app.float.font_size_body'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 6, right: 6 })

            // 主卡片
            SurfaceCard({ contentPadding: 22, radius: 22 }) {
              Column({ space: 16 }) {
                // Lottie
                Column() {
                  LottieView({ name: "login_lottie" })
                    .width(isTablet(this.pageWidth) ? 150 : 124)
                    .height(isTablet(this.pageWidth) ? 150 : 124)
                }
                .width('100%')
                .padding({ top: 8, bottom: 2 })
                .alignItems(HorizontalAlign.Center)

                // 最近账号提示
                if (this.account > 0) {
                  Row({ space: 8 }) {
                    Circle()
                      .width(7)
                      .height(7)
                      .fill($r('app.color.brand_primary'))

                    Text(`最近账号：${this.account}`)
                      .fontSize($r('app.float.font_size_caption'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.brand_primary_subtle'))
                  .borderRadius(12)
                }

                // 输入框
                Column({ space: 14 }) {
                  LabeledInput({
                    icon: $r('app.media.usra'),
                    placeholder: '请输入账号 (数字 ID)',
                    text: $userName,
                    inputType: InputType.Number
                  })

                  LabeledInput({
                    icon: $r('app.media.lock'),
                    placeholder: '请输入密码',
                    text: $password,
                    inputType: InputType.Password
                  })
                }
                .width('100%')

                // 登录按钮
                PrimaryButton({
                  text: '登 录',
                  loading: this.isLoading,
                  loadingText: '登录中...',
                  onTap: (): void => {
                    this.handleLogin()
                  }
                })

                // 注册引导
                Row() {
                  Text('还没有账号？')
                    .fontSize($r('app.float.font_size_body'))
                    .fontColor($r('app.color.text_tertiary'))

                  Text('立即注册')
                    .fontSize($r('app.float.font_size_body'))
                    .fontColor($r('app.color.brand_primary'))
                    .fontWeight(FontWeight.Medium)
                    .margin({ left: 6 })
                    .onClick((): void => {
                      this.pathStack.pushPathByName('Register', null)
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({ top: 2 })
              }
              .width('100%')
            }

            // 协议说明
            Text('登录即代表您同意《用户协议》与《隐私政策》')
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ bottom: 16, top: 10 })
          }
          .width(isTablet(this.pageWidth) ? 480 : '100%')
          .align(Alignment.Center)
          .padding({
            left: isTablet(this.pageWidth) ? 0 : 16,
            right: isTablet(this.pageWidth) ? 0 : 16
          })
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Center)
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
