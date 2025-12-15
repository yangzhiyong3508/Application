import { LoginUtil, LoginResult } from '../utils/LoginUtil'
import promptAction from '@ohos.promptAction'
import { LottieView } from "../utils/LottieView"
import { font } from "@kit.ArkUI"

@Builder
export function LoginBuilder() {
  Login()
}

@Entry
@Component
struct Login {
  // ======================== 全局状态绑定 ========================
  @StorageLink('account') account: number = 0
  @StorageLink('password') psw: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('username') username: string = ''
  @StorageLink('avatar') avatar: number | string = 1

  // 运动参数
  @StorageLink('per') per: number = 4
  @StorageLink('spd') spd: number = 6
  @StorageLink('pid') pid: number = 10

  // 🔥 新增：语音参数全局绑定 (与 LoginUtil 中的设置对应)
  @StorageLink('vol') vol: number = 50
  @StorageLink('voiceId') voiceId: string = '7568423452617605174'
  @StorageLink('speedRatio') speedRatio: number = 1.0
  @StorageLink('wakeWord') wakeWord: string = '小狗小狗'

  // ======================== 本地状态 ========================
  @State userName: string = ''
  @State password: string = ''
  @State isLoading: boolean = false

  // 动画状态
  @State bgRotateAngle: number = 0
  @State formOpacity: number = 0
  @State formTranslateY: number = 50

  pathStack: NavPathStack = new NavPathStack()

  aboutToAppear() {
    // 自动填充逻辑
    if (this.account) {
      this.userName = this.account.toString()
    }
    if (this.psw) {
      this.password = this.psw
    }

    // 启动背景流光动画
    setTimeout(() => {
      this.startBgAnimation()
    }, 100)

    // 启动表单入场动画
    setTimeout(() => {
      animateTo({ duration: 800, curve: Curve.EaseOut }, () => {
        this.formOpacity = 1
        this.formTranslateY = 0
      })
    }, 200)
  }

  /**
   * 背景旋转动画
   */
  startBgAnimation() {
    animateTo({
      duration: 20000, // 20秒转一圈
      curve: Curve.Linear,
      iterations: -1,
    }, () => {
      this.bgRotateAngle = 360
    })
  }

  /**
   * 登录逻辑
   */
  private async handleLogin() {
    if (this.userName === '' || this.password === '') {
      promptAction.showToast({ message: '账号和密码不能为空' })
      return
    }

    const accountNumber = Number(this.userName)
    if (isNaN(accountNumber)) {
      promptAction.showToast({ message: '账号必须为数字' })
      return
    }

    this.isLoading = true

    try {
      // 1. 调用 LoginUtil.login (内部会自动更新 AppStorage)
      const result: LoginResult = await LoginUtil.login(accountNumber.toString(), this.password)

      if (result.success && result.user) {
        promptAction.showToast({ message: '登录成功' })

        // 2. 更新特定的本地逻辑状态 (如果需要)
        // LoginUtil 已经处理了 account, username, voiceId 等大部分状态

        // 处理头像特殊逻辑
        let userAvatar: string | number = result.user.avatarUrl;
        if (!userAvatar || userAvatar.length === 0) {
          userAvatar = 1;
        }
        AppStorage.setOrCreate('avatar', userAvatar)

        // 3. 页面跳转
        setTimeout(() => {
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

  // ---- 样式封装 ----
  @Styles inputContainerStyle() {
    .width('100%')
    .height(60)
    .borderRadius(16)
    .backgroundColor('#F7F9FC')
  }

  build() {
    NavDestination() {
      Stack() {
        // ... (背景层代码保持不变) ...
        // 1. 动态背景层
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#F0F4F8')
          Circle({ width: '150%', height: '80%' })
            .linearGradient({ angle: 135, colors: [['#E0C3FC', 0], ['#8EC5FC', 1]] })
            .blur(60).position({ x: '-20%', y: '-20%' })
            .rotate({ angle: this.bgRotateAngle, centerX: '50%', centerY: '50%' }).opacity(0.6)
          Circle({ width: '120%', height: '60%' })
            .linearGradient({ angle: 45, colors: [['#a18cd1', 0], ['#fbc2eb', 1]] })
            .blur(80).position({ x: '10%', y: '40%' })
            .rotate({ angle: -this.bgRotateAngle * 0.5, centerX: '50%', centerY: '50%' }).opacity(0.5)
        }.width('100%').height('100%').clip(true)

        // 2. 前景内容层
        Scroll() {
          Column() {
            Blank().height(60)

            Column() {
              Column() {
                LottieView({ name: "login_lottie" }).width(160).height(160)
              }.margin({ top: 10, bottom: 10 })

              Text('智能宠物狗')
                .fontSize(32).fontColor('#333').fontWeight(FontWeight.Bold).fontFamily('alibaba')
                .textShadow({ radius: 10, color: 'rgba(0,0,0,0.1)', offsetY: 5 })

              Text('登录开启您的智能生活')
                .fontSize(16).fontColor('#888').margin({ top: 10, bottom: 40 }).fontFamily('alibaba')

              // 输入框区域
              Column({ space: 20 }) {
                Row() {
                  Image($r('app.media.usra')).width(24).height(24).fillColor('#999').margin({ left: 16, right: 10 })
                  TextInput({ placeholder: '请输入账号 (数字 ID)', text: this.userName })
                    .type(InputType.Number).layoutWeight(1).height('100%')
                    .backgroundColor(Color.Transparent).fontSize(18).fontFamily('alibaba')
                    .onChange((value) => this.userName = value)
                }.inputContainerStyle().border({ width: 1, color: '#EEE' })

                Row() {
                  Image($r('app.media.lock')).width(24).height(24).fillColor('#999').margin({ left: 16, right: 10 })
                  TextInput({ placeholder: '请输入密码', text: this.password })
                    .type(InputType.Password).layoutWeight(1).height('100%')
                    .backgroundColor(Color.Transparent).fontSize(18).fontFamily('alibaba')
                    .onChange((value) => this.password = value)
                }.inputContainerStyle().border({ width: 1, color: '#EEE' })
              }.width('100%').margin({ bottom: 40 })

              // 按钮区域
              Column({ space: 15 }) {
                Button() {
                  if (this.isLoading) {
                    Row({ space: 6 }) {
                      LoadingProgress().width(20).height(20).color('#FFF')
                      Text('登录中...').fontColor('#FFF').fontSize(18)
                    }
                  } else {
                    Text('登 录').fontSize(18).fontColor('#FFF').fontWeight(FontWeight.Bold).fontFamily('alibaba')
                  }
                }
                .width('100%').height(56)
                .backgroundColor(this.isLoading ? '#A0CFFF' : '#4158D0')
                .linearGradient({
                  direction: GradientDirection.Right,
                  colors: this.isLoading ? [['#A0CFFF', 0], ['#A0CFFF', 1]] : [['#4158D0', 0], ['#C850C0', 1]]
                })
                .borderRadius(28).shadow({ radius: 15, color: 'rgba(65, 88, 208, 0.4)', offsetY: 8 })
                .enabled(!this.isLoading)
                .onClick(() => this.handleLogin())

                Button('注册新账号')
                  .width('100%').height(56).backgroundColor(Color.Transparent)
                  .fontColor('#666').fontSize(16).fontWeight(FontWeight.Medium).fontFamily('alibaba')
                  .onClick(() => { this.pathStack.pushPathByName('Register', null) })
              }.width('100%')

            }
            .width('90%')
            .backgroundColor('rgba(255, 255, 255, 0.75)').backdropBlur(40)
            .borderRadius(30).padding({ left: 25, right: 25, top: 40, bottom: 40 })
            .shadow({ radius: 40, color: 'rgba(0,0,0,0.08)', offsetY: 20 })
            .margin({ top: 20 }).opacity(this.formOpacity).translate({ y: this.formTranslateY })

            Row() {
              Text('登录即代表您同意《用户协议》与《隐私政策》').fontSize(12).fontColor('#999')
            }.margin({ top: 40, bottom: 20 }).opacity(0.8)

          }.width('100%').constraintSize({ minHeight: '100%' })
        }.scrollBar(BarState.Off).width('100%').height('100%')
      }
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      try {
        font.registerFont({ familyName: "alibaba", familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf') })
      } catch (e) {}
    })
  }
}