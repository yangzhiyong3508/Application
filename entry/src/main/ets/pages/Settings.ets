import { font } from "@kit.ArkUI"
import promptAction from "@ohos.promptAction"
import http from '@ohos.net.http'
import common from '@ohos.app.ability.common'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { PhotoPickerUtil } from '../utils/PhotoPickerUtil'
import { CosHelper } from '../utils/PhotoUploadUtil'

@Builder
export function SettingsBuilder() {
  Settings()
}

@Entry
@Component
struct Settings {
  pathStack: NavPathStack = new NavPathStack()

  // 密码修改相关状态
  @State oldPwd: string = ''
  @State newPwd: string = ''
  @State confirmPwd: string = ''
  @State isUploading: boolean = false

  // 全局状态
  @StorageLink('account') account: number = 0
  @StorageLink('password') psw: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('avatar') avatar: number | string = 1

  private photoPickerUtil: PhotoPickerUtil = new PhotoPickerUtil()

  // 兼容旧版本的本地头像资源
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
      "***",
      "***"
    )
  }

  // ---- 样式封装 ----
  @Styles inputStyle() {
    .width('100%')
    .height(55)
    .borderRadius(12)
    .backgroundColor('#F7F8FA') // 更柔和的输入框背景
    .padding({ left: 16, right: 16 })
  }

  @Styles cardStyle() {
    .width('92%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20) // 加大圆角
    .padding(24)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.06)', offsetY: 8 }) // 柔和阴影
  }

  // 获取当前头像
  private getAvatarSrc(): ResourceStr | string {
    if (typeof this.avatar === 'string' && this.avatar.length > 0) {
      return this.avatar;
    } else if (typeof this.avatar === 'number') {
      return this.localAvatarList[this.avatar] || this.localAvatarList[0];
    }
    return this.localAvatarList[0];
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // --- 1. 顶部装饰背景 ---
        Column() {
          Stack() {
            // 渐变背景
            Column()
              .linearGradient({
                direction: GradientDirection.RightBottom,
                colors: [['#1C6AEB', 0.0], ['#5296FF', 1.0]]
              })
              .width('100%')
              .height('100%')

            // 装饰圆环 1
            Circle()
              .width(200)
              .height(200)
              .fillOpacity(0)
              .strokeWidth(30)
              .stroke('rgba(255,255,255,0.1)')
              .position({ x: -50, y: -50 })

            // 装饰圆环 2
            Circle()
              .width(150)
              .height(150)
              .fill('rgba(255,255,255,0.1)')
              .position({ x: '85%', y: 50 })
          }
        }
        .width('100%')
        .height(280) // 背景高度

        // --- 2. 主要内容滚动区 ---
        Scroll() {
          Column() {
            // --- 顶部导航栏 (透明背景，白色图标) ---
            Row() {
              Column() {
                Image($r('app.media.arrow_return'))
                  .width(24)
                  .height(24)
                  .fillColor('#FFFFFF') // 白色图标适应深色背景
              }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .borderRadius(20)
              .backgroundColor('rgba(255,255,255,0.2)') // 半透明按钮背景
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => this.pathStack.pop())

              Text('账户设置')
                .fontSize(24)
                .fontFamily('alibaba')
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF') // 白色标题
                .margin({ left: 16 })
            }
            .width('100%')
            .padding({ left: 20, top: 16 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)

            // --- 悬浮内容区 ---
            Column({ space: 20 }) {

              // --- 头像卡片 ---
              Column() {
                // 头像与提示文字
                Column({ space: 15 }) {
                  // 头像容器
                  Stack({ alignContent: Alignment.Center }) {
                    // 外层光晕装饰
                    Circle()
                      .width(110)
                      .height(110)
                      .fill(Color.Transparent)
                      .strokeWidth(2)
                      .stroke('#1C6AEB')
                      .opacity(0.3)
                      .scale({ x: this.isUploading ? 1.1 : 1, y: this.isUploading ? 1.1 : 1 })
                      .animation({ duration: 1000, iterations: -1, curve: Curve.EaseInOut }) // 上传时呼吸动画

                    // 头像本体
                    Image(this.getAvatarSrc())
                      .width(100)
                      .height(100)
                      .borderRadius(50) // 纯圆形
                      .border({ width: 4, color: '#FFFFFF' }) // 白色描边
                      .shadow({ radius: 10, color: 'rgba(0,0,0,0.1)', offsetY: 5 })
                      .objectFit(ImageFit.Cover)
                  }
                  .onClick(() => this.showAvatarActionSheet())

                  Column() {
                    Text('点击更换头像')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#333')

                    Text(this.isUploading ? '正在上传图片...' : `账号: ${this.account}`)
                      .fontSize(14)
                      .fontColor(this.isUploading ? '#1C6AEB' : '#999')
                      .margin({ top: 4 })
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              }
              .cardStyle()
              .margin({ top: 40 }) // 向上顶，产生悬浮感

              // --- 安全中心卡片 ---
              Column({ space: 18 }) {
                Row() {
                  // 小装饰条
                  Rect().width(4).height(18).fill('#1C6AEB').borderRadius(2)
                  Text('修改密码')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontFamily('alibaba')
                    .margin({ left: 10 })
                }
                .width('100%')

                TextInput({ placeholder: '请输入旧密码' })
                  .type(InputType.Password)
                  .inputStyle()
                  .onChange((value) => this.oldPwd = value)

                TextInput({ placeholder: '请输入新密码 (至少6位)' })
                  .type(InputType.Password)
                  .inputStyle()
                  .onChange((value) => this.newPwd = value)

                TextInput({ placeholder: '请确认新密码' })
                  .type(InputType.Password)
                  .inputStyle()
                  .onChange((value) => this.confirmPwd = value)

                Button('确认修改')
                  .width('100%')
                  .height(52)
                  .fontSize(18)
                  .fontFamily('alibaba')
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor('#1C6AEB')
                  .fontColor(Color.White)
                  .borderRadius(26)
                  .shadow({ radius: 10, color: 'rgba(28, 106, 235, 0.4)', offsetY: 5 })
                  .margin({ top: 10 })
                  .onClick(() => this.changePassword())
              }
              .cardStyle()
              .margin({ bottom: 40 })
            }
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .backgroundColor('#F5F6F8') // 整体背景灰
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      font.registerFont({
        familyName: "alibaba",
        familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
      })
    })
  }

  // ... 逻辑代码保持不变 ...

  /**
   * 显示头像操作弹窗
   */
  private showAvatarActionSheet() {
    if (this.isUploading) {
      promptAction.showToast({ message: '正在上传中，请稍候' });
      return;
    }

    promptAction.showActionMenu({
      title: '更换头像',
      buttons: [
        {
          text: '从相册选择',
          color: '#1C6AEB'
        }
      ]
    }).then(data => {
      if (data.index === 0) {
        this.handleCustomAvatar();
      }
    }).catch((err: Error) => {
      console.info('取消弹窗');
    })
  }

  /**
   * 处理自定义头像上传逻辑
   */
  private async handleCustomAvatar() {
    try {
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoViewPicker.select(this.photoPickerUtil.getPickerOptions());

      if (result && result.photoUris && result.photoUris.length > 0) {
        const uri = result.photoUris[0];
        this.isUploading = true;
        promptAction.showToast({ message: '正在上传头像...', duration: 2000 });

        const cosUrl = await CosHelper.getInstance().uploadFile(uri);
        await this.updateAvatarOnServer(cosUrl);
      }
    } catch (err) {
      let msg = '未知错误';
      if (err instanceof Error) {
        msg = err.message;
      }
      promptAction.showToast({ message: `操作失败: ${msg}`, duration: 3000 });
    } finally {
      this.isUploading = false;
    }
  }

  /**
   * 统一的后端更新请求
   */
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
      const result = Number(response.result);
      if (result === 1) {
        this.avatar = avatarData;
        promptAction.showToast({ message: '头像修改成功', duration: 1500 });
      } else {
        promptAction.showToast({ message: '服务器更新失败', duration: 2000 });
      }
    } catch (error) {
      promptAction.showToast({ message: '网络连接超时', duration: 2000 });
    }
  }

  /**
   * 修改密码逻辑
   */
  private async changePassword() {
    if (this.oldPwd === '' || this.newPwd === '' || this.confirmPwd === '') {
      promptAction.showToast({ message: '请将信息填写完整', duration: 2000 });
      return;
    }
    if (this.oldPwd !== this.psw) {
      promptAction.showToast({ message: '旧密码输入错误', duration: 2000 });
      return;
    }
    if (this.newPwd !== this.confirmPwd) {
      promptAction.showToast({ message: '两次新密码输入不一致', duration: 2000 });
      return;
    }
    if (this.newPwd.length < 6) {
      promptAction.showToast({ message: '新密码长度至少为6位', duration: 2000 });
      return;
    }
    if (this.newPwd === this.oldPwd) {
      promptAction.showToast({ message: '新密码不能与旧密码相同', duration: 2000 });
      return;
    }

    try {
      const httpRequest = http.createHttp();
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
      );
      const result = Number(response.result);
      if (result === 1) {
        this.psw = this.newPwd;
        AppStorage.setOrCreate('password', this.newPwd);
        promptAction.showToast({ message: '密码修改成功', duration: 2000 });
        this.oldPwd = ''; this.newPwd = ''; this.confirmPwd = '';
        setTimeout(() => { this.pathStack.pop(); }, 1500);
      } else {
        promptAction.showToast({ message: '修改失败，请重试', duration: 2000 });
      }
    } catch (error) {
      promptAction.showToast({ message: '网络请求失败', duration: 2000 });
    }
  }
}