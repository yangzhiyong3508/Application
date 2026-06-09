import promptAction from "@ohos.promptAction"
import http from '@ohos.net.http'
import common from '@ohos.app.ability.common'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { PhotoPickerUtil } from '../utils/PhotoPickerUtil'
import { CosHelper } from '../utils/PhotoUploadUtil'
import { SurfaceCard } from '../components/SurfaceCard'
import { PrimaryButton } from '../components/PrimaryButton'
import { isTablet } from '../theme/Theme'

@Builder
export function SettingsBuilder() {
  Settings()
}

@Entry
@Component
struct Settings {
  pathStack: NavPathStack = new NavPathStack()

  @State oldPwd: string = ''
  @State newPwd: string = ''
  @State confirmPwd: string = ''
  @State isUploading: boolean = false
  @State pageWidth: number = 0

  @StorageLink('account') account: number = 0
  @StorageLink('password') psw: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('avatar') avatar: number | string = 1

  private photoPickerUtil: PhotoPickerUtil = new PhotoPickerUtil()

  private localAvatarList: Array<ResourceStr> = [
    $r('app.media.avatar0'),
    $r('app.media.avatar1'),
    $r('app.media.avatar2'),
    $r('app.media.avatar3')
  ]

  aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext
    CosHelper.getInstance().init(
      context,
      "ap-nanjing",
      "edog-avatar-1361772203",
      "",
      ""
    )
  }

  @Styles inputStyle() {
    .width('100%')
    .height(55)
    .borderRadius(12)
    .padding({ left: 16, right: 16 })
  }

  private getAvatarSrc(): ResourceStr | string {
    if (typeof this.avatar === 'string' && this.avatar.length > 0) {
      return this.avatar
    } else if (typeof this.avatar === 'number') {
      return this.localAvatarList[this.avatar] || this.localAvatarList[0]
    }
    return this.localAvatarList[0]
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // 顶部蓝色渐变装饰
        Column() {
          Stack() {
            Column()
              .linearGradient({
                direction: GradientDirection.RightBottom,
                colors: [
                  [$r('app.color.brand_gradient_start'), 0.0],
                  [$r('app.color.brand_gradient_end'), 1.0]
                ]
              })
              .width('100%')
              .height('100%')

            Circle()
              .width(200)
              .height(200)
              .fillOpacity(0)
              .strokeWidth(30)
              .stroke('#1AFFFFFF')
              .position({ x: -50, y: -50 })

            Circle()
              .width(150)
              .height(150)
              .fill('#1AFFFFFF')
              .position({ x: '85%', y: 50 })
          }
        }
        .width('100%')
        .height(280)

        // 主内容
        Scroll() {
          Column() {
            // 顶部导航栏
            Row() {
              Column() {
                Image($r('app.media.arrow_return'))
                  .width(24)
                  .height(24)
                  .fillColor($r('app.color.text_on_brand'))
              }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .borderRadius(20)
              .backgroundColor('#33FFFFFF')
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => this.pathStack.pop())

              Text('账户设置')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_brand'))
                .margin({ left: 16 })
            }
            .width('100%')
            .padding({ left: 20, top: 16 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)

            Column({ space: 20 }) {
              // 头像卡片（外层 Column 用于承载 .margin）
              Column() {
              SurfaceCard({ contentPadding: 24, radius: 20, emphasized: true }) {
                Column({ space: 15 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    Circle()
                      .width(110)
                      .height(110)
                      .fill(Color.Transparent)
                      .strokeWidth(2)
                      .stroke($r('app.color.brand_primary'))
                      .opacity(0.3)
                      .scale({
                        x: this.isUploading ? 1.1 : 1,
                        y: this.isUploading ? 1.1 : 1
                      })
                      .animation({ duration: 1000, iterations: -1, curve: Curve.EaseInOut })

                    Image(this.getAvatarSrc())
                      .width(100)
                      .height(100)
                      .borderRadius(50)
                      .border({ width: 4, color: $r('app.color.surface_card_solid') })
                      .objectFit(ImageFit.Cover)
                  }
                  .onClick(() => this.showAvatarActionSheet())

                  Column() {
                    Text('点击更换头像')
                      .fontSize($r('app.float.font_size_subtitle'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))

                    Text(this.isUploading ? '正在上传图片...' : `账号: ${this.account}`)
                      .fontSize($r('app.float.font_size_body'))
                      .fontColor(this.isUploading
                        ? $r('app.color.brand_primary')
                        : $r('app.color.text_tertiary'))
                      .margin({ top: 4 })
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              }
              }
              .margin({ top: 40 })

              // 修改密码卡片（外层 Column 用于承载 .margin）
              Column() {
              SurfaceCard({ contentPadding: 24, radius: 20, emphasized: true }) {
                Column({ space: 18 }) {
                  Row() {
                    Rect()
                      .width(4)
                      .height(18)
                      .fill($r('app.color.brand_primary'))
                      .borderRadius(2)

                    Text('修改密码')
                      .fontSize($r('app.float.font_size_subtitle'))
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .margin({ left: 10 })
                  }
                  .width('100%')

                  TextInput({ placeholder: '请输入旧密码' })
                    .type(InputType.Password)
                    .inputStyle()
                    .backgroundColor($r('app.color.input_bg'))
                    .border({ width: 1, color: $r('app.color.input_border') })
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .onChange((value) => this.oldPwd = value)

                  TextInput({ placeholder: '请输入新密码 (至少6位)' })
                    .type(InputType.Password)
                    .inputStyle()
                    .backgroundColor($r('app.color.input_bg'))
                    .border({ width: 1, color: $r('app.color.input_border') })
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .onChange((value) => this.newPwd = value)

                  TextInput({ placeholder: '请确认新密码' })
                    .type(InputType.Password)
                    .inputStyle()
                    .backgroundColor($r('app.color.input_bg'))
                    .border({ width: 1, color: $r('app.color.input_border') })
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .onChange((value) => this.confirmPwd = value)

                  PrimaryButton({
                    text: '确认修改',
                    btnHeight: 52,
                    onTap: (): void => {
                      this.changePassword()
                    }
                  })
                }
              }
              }
              .margin({ bottom: 40 })
            }
          }
          .width(isTablet(this.pageWidth) ? 720 : '100%')
          .align(Alignment.Center)
          .padding({
            left: isTablet(this.pageWidth) ? 0 : 16,
            right: isTablet(this.pageWidth) ? 0 : 16,
            bottom: 24
          })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .backgroundColor($r('app.color.page_bg'))
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

  private showAvatarActionSheet() {
    if (this.isUploading) {
      promptAction.showToast({ message: '正在上传中，请稍候' })
      return
    }

    promptAction.showActionMenu({
      title: '更换头像',
      buttons: [
        { text: '从相册选择', color: '#FF2D7EF0' }
      ]
    }).then(data => {
      if (data.index === 0) {
        this.handleCustomAvatar()
      }
    }).catch((err: Error) => {
      console.info('取消弹窗')
    })
  }

  private async handleCustomAvatar() {
    try {
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoViewPicker.select(this.photoPickerUtil.getPickerOptions())

      if (result && result.photoUris && result.photoUris.length > 0) {
        const uri = result.photoUris[0]
        this.isUploading = true
        promptAction.showToast({ message: '正在上传头像...', duration: 2000 })

        const cosUrl = await CosHelper.getInstance().uploadFile(uri)
        await this.updateAvatarOnServer(cosUrl)
      }
    } catch (err) {
      let msg = '未知错误'
      if (err instanceof Error) {
        msg = err.message
      }
      promptAction.showToast({ message: `操作失败: ${msg}`, duration: 3000 })
    } finally {
      this.isUploading = false
    }
  }

  private async updateAvatarOnServer(avatarData: number | string) {
    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${AppStorage.get<string>('localhost')}:8080/api/accounts/updateAvatar`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify({
            account: this.account,
            avatar: avatarData
          })
        }
      )
      const result = Number(response.result)
      if (result === 1) {
        this.avatar = avatarData
        promptAction.showToast({ message: '头像修改成功', duration: 1500 })
      } else {
        promptAction.showToast({ message: '服务器更新失败', duration: 2000 })
      }
    } catch (error) {
      promptAction.showToast({ message: '网络连接超时', duration: 2000 })
    }
  }

  private async changePassword() {
    if (this.oldPwd === '' || this.newPwd === '' || this.confirmPwd === '') {
      promptAction.showToast({ message: '请将信息填写完整', duration: 2000 })
      return
    }
    if (this.oldPwd !== this.psw) {
      promptAction.showToast({ message: '旧密码输入错误', duration: 2000 })
      return
    }
    if (this.newPwd !== this.confirmPwd) {
      promptAction.showToast({ message: '两次新密码输入不一致', duration: 2000 })
      return
    }
    if (this.newPwd.length < 6) {
      promptAction.showToast({ message: '新密码长度至少为6位', duration: 2000 })
      return
    }
    if (this.newPwd === this.oldPwd) {
      promptAction.showToast({ message: '新密码不能与旧密码相同', duration: 2000 })
      return
    }

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${AppStorage.get<string>('localhost')}:8080/api/accounts/updatePassword`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify({
            account: this.account,
            password: this.newPwd
          })
        }
      )
      const result = Number(response.result)
      if (result === 1) {
        this.psw = this.newPwd
        AppStorage.setOrCreate('password', this.newPwd)
        promptAction.showToast({ message: '密码修改成功', duration: 2000 })
        this.oldPwd = ''
        this.newPwd = ''
        this.confirmPwd = ''
        setTimeout(() => {
          this.pathStack.pop()
        }, 1500)
      } else {
        promptAction.showToast({ message: '修改失败，请重试', duration: 2000 })
      }
    } catch (error) {
      promptAction.showToast({ message: '网络请求失败', duration: 2000 })
    }
  }
}
