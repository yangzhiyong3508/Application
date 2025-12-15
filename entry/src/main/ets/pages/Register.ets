import { LottieView } from "../utils/LottieView"
import promptAction from '@ohos.promptAction'
import { font } from "@kit.ArkUI"

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

  private handleNextStep() {
    if (this.uname === '' || this.upass === '' || this.confirmPass === '') {
      promptAction.showToast({ message: "请填写完整信息" })
      return
    }
    if (this.upass !== this.confirmPass) {
      promptAction.showToast({ message: "两次密码不一致" })
      return
    }
    const acc = Number(this.uname)
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

  @Styles inputStyle() {
    .width('100%')
    .height(60)
    .borderRadius(12)
    .backgroundColor('#F7F9FC')
    .padding({ left: 16 })
  }

  build() {
    NavDestination() {
      Stack() {
        // 背景
        Column().width('100%').height('100%').backgroundColor(Color.White)

        Scroll() {
          Column() {
            // 返回按钮
            Row() {
              Image($r('app.media.arrow_return'))
                .width(24).height(24).fillColor('#333')
                .onClick(() => this.pathStack.pop())
            }
            .width('100%')
            .padding({ left: 20, top: 20 })

            Text("注册新账号")
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 20, bottom: 20 })
              .fontFamily("alibaba")

            LottieView({ name: "register_lottie" })
              .width(180)
              .height(180)
              .margin({ bottom: 20 })

            Column({ space: 20 }) {
              TextInput({ placeholder: "请输入账号 (数字)", text: this.uname })
                .type(InputType.Number)
                .onChange(v => this.uname = v)
                .inputStyle()

              TextInput({ placeholder: "设置密码", text: this.upass })
                .type(InputType.Password)
                .onChange(v => this.upass = v)
                .inputStyle()

              TextInput({ placeholder: "确认密码", text: this.confirmPass })
                .type(InputType.Password)
                .onChange(v => this.confirmPass = v)
                .inputStyle()
            }
            .width('85%')
            .margin({ top: 20, bottom: 40 })

            Button("下一步")
              .width("85%")
              .height(56)
              .borderRadius(28)
              .backgroundColor("#1C6AEB")
              .fontColor(Color.White)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .shadow({ radius: 15, color: 'rgba(28, 106, 235, 0.4)', offsetY: 5 })
              .onClick(() => this.handleNextStep())

            Row() {
              Text("已有账号？").fontColor('#999')
              Text("去登录")
                .fontColor("#1C6AEB")
                .fontWeight(FontWeight.Bold)
                .onClick(() => this.pathStack.pop()) // 返回到登录页
            }
            .margin({ top: 25 })
          }
          .width('100%')
        }
      }
    }
    .hideTitleBar(true)
    .onReady(context => {
      this.pathStack = context.pathStack
      try {
        font.registerFont({
          familyName: "alibaba",
          familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
        })
      } catch (e) {}
    })
  }
}