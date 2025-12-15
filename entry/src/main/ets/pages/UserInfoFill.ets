import { photoAccessHelper } from '@kit.MediaLibraryKit'
import promptAction from '@ohos.promptAction'
import { PhotoPickerUtil } from '../utils/PhotoPickerUtil'
import { CosHelper } from '../utils/PhotoUploadUtil'
import { RegisterUtil } from '../utils/RegisterUtil'
import { RegisterParams } from './Register'
import common from '@ohos.app.ability.common'
import { font } from '@kit.ArkUI'

@Builder
export function UserInfoFillBuilder() {
  UserInfoFill()
}

@Entry
@Component
struct UserInfoFill {
  pathStack: NavPathStack = new NavPathStack()

  private acc: string = ''
  private pass: string = ''

  @State nickname: string = ''
  @State wakeWord: string = '你好小狗'
  @State avatarPreview: string = ''
  @State isUploading: boolean = false
  @State isSubmitting: boolean = false

  private pickerUtil: PhotoPickerUtil = new PhotoPickerUtil()

  @StorageLink('account') globalAccount: number = 0
  @StorageLink('password') globalPassword: string = ''

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext
    CosHelper.getInstance().init(
      context,
      "ap-nanjing",
      "edog-avatar-1361772203",
      "***",
      "***"
    )
  }

  private async pickAvatar(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result = await picker.select(this.pickerUtil.getPickerOptions())
      if (result && result.photoUris && result.photoUris.length > 0) {
        this.isUploading = true
        promptAction.showToast({ message: "正在上传头像..." })
        const url = await CosHelper.getInstance().uploadFile(result.photoUris[0])
        if (url) {
          this.avatarPreview = String(url)
          promptAction.showToast({ message: "头像上传成功" })
        }
      }
    } catch (e) {
      promptAction.showToast({ message: "上传失败" })
    } finally {
      this.isUploading = false
    }
  }

  private async handleSubmit(): Promise<void> {
    if (!this.avatarPreview) {
      promptAction.showToast({ message: "请先上传头像" })
      return
    }
    if (!this.nickname) {
      promptAction.showToast({ message: "请输入昵称" })
      return
    }

    this.isSubmitting = true
    try {
      const res = await RegisterUtil.register(
        Number(this.acc),
        this.pass,
        this.avatarPreview,
        this.nickname,
        this.wakeWord
      )

      if (res.success) {
        promptAction.showToast({ message: "注册成功，即将跳转登录" })
        this.globalAccount = Number(this.acc)
        this.globalPassword = this.pass

        // 注册成功后，跳转回 Login 页面，而不是 Index
        setTimeout(() => {
          // 清除路由栈直到 Login（或者直接 push Login，取决于架构）
          // 这里我们简单起见，直接退回上一页（Register），再退回 Login
          // 或者直接使用 clear() 然后 push Login
          this.pathStack.clear()
          this.pathStack.pushPath({ name: "Login" })
        }, 1500)
      } else {
        promptAction.showToast({ message: res.msg })
      }
    } catch (e) {
      promptAction.showToast({ message: "注册异常" })
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 标题
        Text("完善个人信息")
          .fontSize(28)
          .fontWeight(600)
          .fontFamily("alibaba")
          .margin({ top: 40, bottom: 40 })

        // 头像上传区
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            // 外层呼吸光环 (仅上传时显示)
            if (this.isUploading) {
              Circle({ width: 110, height: 110 })
                .fill(Color.Transparent)
                .strokeWidth(2)
                .stroke('#1C6AEB')
                .opacity(0.5)
              // 这里可以加个动画
            }

            if (this.avatarPreview) {
              Image(this.avatarPreview)
                .width(100).height(100)
                .borderRadius(50)
                .objectFit(ImageFit.Cover)
                .border({ width: 2, color: '#1C6AEB' })
            } else {
              Circle({ width: 100, height: 100 }).fill("#F0F0F0")
              Column() {
                Image($r('sys.media.ohos_ic_public_add')) // 加号图标
                  .width(30).height(30).fillColor('#999')
                Text("上传头像").fontSize(12).fontColor("#999").margin({top: 5})
              }
            }
          }
          .onClick(() => { if(!this.isUploading) this.pickAvatar() })

          Text(this.isUploading ? "正在上传..." : "点击上方图标上传头像")
            .fontSize(14).fontColor("#999").margin({ top: 12 })
        }
        .margin({ bottom: 40 })

        // 表单区
        Column({ space: 20 }) {
          TextInput({
            placeholder: "给您的爱宠起个昵称吧 (用户名)",
            text: this.nickname
          })
            .onChange((v: string) => this.nickname = v)
            .width("85%")
            .height(55)
            .borderRadius(12)
            .backgroundColor("#F7F9FC")
            .padding({ left: 16 })

          TextInput({
            placeholder: "设置唤醒词 (默认: 你好小狗)",
            text: this.wakeWord
          })
            .onChange((v: string) => this.wakeWord = v)
            .width("85%")
            .height(55)
            .borderRadius(12)
            .backgroundColor("#F7F9FC")
            .padding({ left: 16 })
        }
        .width("100%")
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 50 })

        Button(this.isSubmitting ? "正在注册..." : "完成注册")
          .width("85%")
          .height(56)
          .borderRadius(28)
          .backgroundColor(this.isSubmitting ? "#8FB5F5" : "#1C6AEB")
          .enabled(!this.isSubmitting)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .shadow({ radius: 10, color: 'rgba(28, 106, 235, 0.4)', offsetY: 5 })
          .onClick(() => this.handleSubmit())
      }
      .width("100%")
      .height("100%")
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .onReady(context => {
      this.pathStack = context.pathStack
      // 获取路由参数
      const params = this.pathStack.getParamByName("UserInfoFill")[0] as RegisterParams
      if (params) {
        this.acc = params.uname
        this.pass = params.upass
      }
      try {
        font.registerFont({ familyName: "alibaba", familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf') })
      } catch (e) {}
    })
  }
}