import { photoAccessHelper } from '@kit.MediaLibraryKit'
import promptAction from '@ohos.promptAction'
import { PhotoPickerUtil } from '../utils/PhotoPickerUtil'
import { CosHelper } from '../utils/PhotoUploadUtil'
import { RegisterUtil } from '../utils/RegisterUtil'
import { RegisterParams } from './Register'
import common from '@ohos.app.ability.common'
import { PrimaryButton } from '../components/PrimaryButton'
import { isTablet } from '../theme/Theme'

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
  @State wakeWord: string = '小E'
  @State avatarPreview: string = ''
  @State isUploading: boolean = false
  @State isSubmitting: boolean = false
  @State pageWidth: number = 0

  private pickerUtil: PhotoPickerUtil = new PhotoPickerUtil()

  @StorageLink('account') globalAccount: number = 0
  @StorageLink('password') globalPassword: string = ''

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext
    CosHelper.getInstance().init(
      context,
      "ap-nanjing",
      "edog-avatar-1361772203",
      "",
      ""
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

        setTimeout((): void => {
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
        // 返回按钮
        Row() {
          Image($r('app.media.arrow_return'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_primary'))
            .onClick(() => this.pathStack.pop())
        }
        .width('100%')
        .padding({ left: 20, top: 20 })
        .justifyContent(FlexAlign.Start)

        // 标题
        Text("完善个人信息")
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 20, bottom: 40 })

        // 头像上传区
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            if (this.isUploading) {
              Circle({ width: 110, height: 110 })
                .fill(Color.Transparent)
                .strokeWidth(2)
                .stroke($r('app.color.brand_primary'))
                .opacity(0.5)
            }

            if (this.avatarPreview) {
              Image(this.avatarPreview)
                .width(100)
                .height(100)
                .borderRadius(50)
                .objectFit(ImageFit.Cover)
                .border({ width: 2, color: $r('app.color.brand_primary') })
            } else {
              Circle({ width: 100, height: 100 }).fill($r('app.color.input_bg'))
              Column() {
                Image($r('sys.media.ohos_ic_public_add'))
                  .width(30)
                  .height(30)
                  .fillColor($r('app.color.text_tertiary'))

                Text("上传头像")
                  .fontSize($r('app.float.font_size_caption'))
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 5 })
              }
            }
          }
          .onClick(() => {
            if (!this.isUploading) this.pickAvatar()
          })

          Text(this.isUploading ? "正在上传..." : "点击上方图标上传头像")
            .fontSize($r('app.float.font_size_body'))
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 12 })
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
            .backgroundColor($r('app.color.input_bg'))
            .border({ width: 1, color: $r('app.color.input_border') })
            .padding({ left: 16 })
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))

          TextInput({
            placeholder: "设置唤醒词 (默认: 小E)",
            text: this.wakeWord
          })
            .onChange((v: string) => this.wakeWord = v)
            .width("85%")
            .height(55)
            .borderRadius(12)
            .backgroundColor($r('app.color.input_bg'))
            .border({ width: 1, color: $r('app.color.input_border') })
            .padding({ left: 16 })
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
        }
        .width("100%")
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 50 })

        // 提交按钮
        Column() {
          PrimaryButton({
            text: '完成注册',
            loading: this.isSubmitting,
            loadingText: '正在注册...',
            btnHeight: 56,
            onTap: (): void => {
              this.handleSubmit()
            }
          })
        }
        .width('85%')
      }
      .width(isTablet(this.pageWidth) ? 520 : "100%")
      .align(Alignment.Center)
      .height("100%")
      .padding({
        left: isTablet(this.pageWidth) ? 0 : 16,
        right: isTablet(this.pageWidth) ? 0 : 16
      })
      .backgroundColor($r('app.color.surface_card_solid'))
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .hideTitleBar(true)
    .onReady(context => {
      this.pathStack = context.pathStack
      const params = this.pathStack.getParamByName("UserInfoFill")[0] as RegisterParams
      if (params) {
        this.acc = params.uname
        this.pass = params.upass
      }
      // 字体注册已统一移至 EntryAbility.onCreate
    })
  }
}
