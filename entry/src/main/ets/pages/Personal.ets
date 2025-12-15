import { font } from "@kit.ArkUI";
import promptAction from "@ohos.promptAction";
import { UpdateUsernameUtil } from '../utils/UpdateUsernameUtil'

@Builder
export function PersonalBuilder() {
  Personal()
}

interface Items {
  icon_src: ResourceStr
  str_row1: string
  str_row2: string
  to_page: string
}

@Component
export struct Personal {
  pathStack: NavPathStack = new NavPathStack();

  @StorageLink('account') account: number = 0
  @StorageLink('password') password: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('username') username: string = '请先登录'
  @StorageLink('avatar') avatar: number | string = 1

  @State showDialog: boolean = false
  @State tempUsername: string = ''
  @State bgRotateAngle: number = 0

  private localAvatarList: Array<ResourceStr> = [
    $r('app.media.avatar0'),
    $r('app.media.avatar1'),
    $r('app.media.avatar2'),
    $r('app.media.avatar3')
  ]

  item_array: Array<Items> = [
    { icon_src: $r('app.media.setting'), str_row1: '系统设置', str_row2: '账号安全、通用设置', to_page: 'Settings' },
    { icon_src: $r('app.media.about'), str_row1: '关于我们', str_row2: '版本 v1.0.0', to_page: 'About' }
  ]

  aboutToAppear() {
    // 注册字体（如果资源存在）
    try {
      font.registerFont({
        familyName: "alibaba",
        familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
      })
    } catch (e) {}

    setTimeout(() => {
      this.startSpectrumAnimation()
    }, 100)
  }

  startSpectrumAnimation() {
    animateTo({
      duration: 15000, // 放慢速度，更优雅
      curve: Curve.Linear,
      iterations: -1,
    }, () => {
      this.bgRotateAngle = 360
    })
  }

  private getAvatarSrc(): ResourceStr | string {
    if (!this.isLogin) return this.localAvatarList[0];
    if (typeof this.avatar === 'string' && this.avatar.length > 0) return this.avatar;
    if (typeof this.avatar === 'number') return this.localAvatarList[this.avatar] || this.localAvatarList[0];
    return this.localAvatarList[0];
  }

  private showEditUsernameDialog() {
    if (this.isLogin) {
      this.tempUsername = this.username
      this.showDialog = true
    } else {
      this.pathStack.pushPathByName('Login', null)
      promptAction.showToast({ message: '请先登录！' })
    }
  }

  private async confirmChangeUsername() {
    const name: string = this.tempUsername.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: '用户名不能为空' })
      return
    }
    const result = await UpdateUsernameUtil.updateUsername(this.account, name)
    if (result.success) {
      this.username = name
      this.showDialog = false
      promptAction.showToast({ message: result.msg })
    } else {
      promptAction.showToast({ message: result.msg })
    }
  }

  // ⭐ 统一样式：卡片容器
  @Styles cardStyle() {
    .width('92%')
    .backgroundColor(Color.White)
    .borderRadius(24) // 更圆润
    // 更柔和的高级阴影
    .shadow({ radius: 40, color: 'rgba(0,0,0,0.08)', offsetY: 10 })
    .padding({ top: 12, bottom: 12 })
  }

  // ⭐ 统一样式：列表项点击态
  @Styles listItemPressed() {
    .backgroundColor('#F5F7FA') // 点击变灰
    .scale({ x: 0.98, y: 0.98 }) // 微微缩小
    .borderRadius(16)
  }

  @Styles listItemNormal() {
    .backgroundColor(Color.Transparent)
    .scale({ x: 1, y: 1 })
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {

        // ============================================================
        // 1. 梦幻极光背景 (升级版)
        // ============================================================
        Column() {
          Stack() {
            // 背景层
            Column()
              .width('200%')
              .height('200%')
              .linearGradient({
                direction: GradientDirection.Left,
                // ⭐ 升级配色：蓝->紫->粉->青 (莫兰迪/科技感配色)
                colors: [
                  ['#4FACFE', 0.0],  // 浅蓝
                  ['#00F2FE', 0.25], // 青色
                  ['#a18cd1', 0.5],  // 紫色
                  ['#fbc2eb', 0.75], // 粉色
                  ['#4FACFE', 1.0]   // 回到浅蓝 (闭环)
                ]
              })
              .rotate({ angle: this.bgRotateAngle })
              .opacity(0.9)

            // 磨砂层
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(255,255,255,0.1)') // 更通透
              .backdropBlur(100) // 极致模糊
          }
          .borderRadius({ bottomLeft: 60, bottomRight: 60 }) // 更大的圆角
          .clip(true)
        }
        .width('100%')
        .height(340) // 稍微加高一点

        // ============================================================
        // 2. 滚动内容层
        // ============================================================
        Scroll() {
          Column() {
            // 标题栏
            Row() {
              Text('个人中心')
                .fontSize(24)
                .fontFamily('alibaba')
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .opacity(0.9)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center) // 居中标题更像APP
            .padding({ top: 44, bottom: 10 })

            // 用户信息卡片 (浮动感更强)
            Column() {
              Row() {
                // 头像区
                Stack({ alignContent: Alignment.BottomEnd }) {
                  // 外发光光晕
                  Circle({ width: 94, height: 94 })
                    .fillOpacity(0)
                    .border({ width: 1, color: 'rgba(255,255,255,0.3)' })
                    .margin({ bottom: 2, right: 2 }) // 微调对齐

                  Image(this.getAvatarSrc())
                    .width(90)
                    .height(90)
                    .borderRadius(45)
                    .border({ width: 4, color: 'rgba(255,255,255,0.6)' }) // 半透明边框
                    .objectFit(ImageFit.Cover)
                    .backgroundColor('#F0F0F0')

                  if (!this.isLogin) {
                    Circle({ width: 26, height: 26 })
                      .fill('#FF4D4F')
                      .border({ width: 3, color: Color.White })
                      .overlay('!', { align: Alignment.Center, offset: { x: 0, y: 1 } })
                  }
                }
                .onClick(() => !this.isLogin && this.pathStack.pushPathByName('Login', null))

                // 文字区
                Column({ space: 8 }) {
                  Row({ space: 8 }) {
                    Text(this.username)
                      .fontSize(26)
                      .fontWeight(FontWeight.Bold)
                      .fontFamily('alibaba')
                      .fontColor(Color.White)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .shadow({ radius: 5, color: 'rgba(0,0,0,0.1)', offsetY: 2 })

                    if (this.isLogin) {
                      Image($r('sys.media.ohos_ic_public_edit'))
                        .width(16)
                        .height(16)
                        .fillColor('rgba(255,255,255,0.8)')
                        .onClick(() => this.showEditUsernameDialog())
                    }
                  }

                  Text(this.isLogin ? `ID: ${this.account}` : '登录体验更多功能')
                    .fontSize(14)
                    .fontColor('rgba(255,255,255,0.7)')
                    .fontFamily('alibaba')
                    .backgroundColor('rgba(0,0,0,0.1)') // 文字背景胶囊
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(12)
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 20 })
                .layoutWeight(1)

                // 箭头
                if (!this.isLogin) {
                  Image($r('sys.media.ohos_ic_public_arrow_right'))
                    .width(20)
                    .height(20)
                    .fillColor('rgba(255,255,255,0.6)')
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 50, top: 20 })

            // 菜单列表
            Column() {
              ForEach(this.item_array, (item: Items, index: number) => {
                Row() {
                  Row({ space: 16 }) {
                    // 图标容器
                    Stack({ alignContent: Alignment.Center }) {
                      Circle({ width: 40, height: 40 })
                        .fill(index === 0 ? '#E8F3FF' : '#FFF0F0') // 不同颜色的底色

                      Image(item.icon_src)
                        .width(20)
                        .height(20)
                        // 根据索引给不同颜色
                        .fillColor(index === 0 ? '#1677FF' : '#FF4D4F')
                    }

                    Column({ space: 4 }) {
                      Text(item.str_row1)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#1A1A1A')
                        .fontFamily('alibaba')

                      if (item.str_row2) {
                        Text(item.str_row2)
                          .fontSize(12)
                          .fontColor('#999')
                          .fontFamily('alibaba')
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                  }

                  Image($r('sys.media.ohos_ic_public_arrow_right'))
                    .width(16)
                    .height(16)
                    .fillColor('#CCCCCC')
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                .justifyContent(FlexAlign.SpaceBetween)
                // 添加按压动效
                .stateStyles({
                  normal: this.listItemNormal,
                  pressed: this.listItemPressed
                })
                .animation({ duration: 200 })
                .onClick(() => {
                  if (this.isLogin || item.to_page === 'About') {
                    this.pathStack.pushPathByName(item.to_page, null)
                  } else {
                    promptAction.showToast({ message: '请先登录' })
                    this.pathStack.pushPathByName('Login', null)
                  }
                })

                // 隐形分割线，只在中间显示，且左右留白
                if (index < this.item_array.length - 1) {
                  Divider()
                    .color('#FAFAFA') // 非常淡
                    .strokeWidth(1)
                    .margin({ left: 72, right: 16 })
                }
              })
            }
            .cardStyle()
            .margin({ top: -30 }) // 向上插入背景

            // 退出按钮
            if (this.isLogin) {
              Button('退出登录')
                .width('92%')
                .height(50)
                .backgroundColor(Color.White)
                .fontColor('#FF4D4F')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontFamily('alibaba')
                .borderRadius(25)
                .margin({ top: 20, bottom: 40 })
                .shadow({ radius: 20, color: 'rgba(255, 77, 79, 0.1)', offsetY: 5 }) // 带颜色的阴影
                .stateEffect(true) // 开启原生点击效果
                .onClick(() => {
                  // 清理逻辑...
                  this.account = 0; this.password = ''; this.username = '请先登录';
                  this.avatar = 1; this.isLogin = false;
                  AppStorage.setOrCreate('avatar', 1)
                  this.pathStack.pushPathByName('Login', null, true)
                })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring) // iOS风格回弹
        .width('100%')
        .height('100%')

        // ============================================================
        // 3. 弹窗 (Glassmorphism 风格)
        // ============================================================
        if (this.showDialog) {
          Stack() {
            // 蒙层
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0,0,0,0.4)')
              .backdropBlur(5) // 背景模糊
              .onClick(() => this.showDialog = false)
              .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

            // 弹窗主体
            Column() {
              Text('修改昵称')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontFamily('alibaba')
                .margin({ bottom: 20, top: 8 })

              TextInput({ text: this.tempUsername, placeholder: '请输入新昵称' })
                .width('100%')
                .height(48)
                .backgroundColor('#F7F8FA')
                .borderRadius(10)
                .padding({ left: 16 })
                .onChange((val) => this.tempUsername = val)
                .defaultFocus(true) // 自动聚焦

              Row({ space: 12 }) {
                Button('取消')
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor('#F0F2F5')
                  .fontColor('#666')
                  .fontSize(15)
                  .borderRadius(20)
                  .onClick(() => this.showDialog = false)

                Button('保存')
                  .layoutWeight(1)
                  .height(40)
                  // 渐变色按钮
                  .linearGradient({
                    angle: 90,
                    colors: [['#4FACFE', 0], ['#00F2FE', 1]]
                  })
                  .fontColor(Color.White)
                  .fontSize(15)
                  .borderRadius(20)
                  .onClick(() => this.confirmChangeUsername())
              }
              .margin({ top: 24 })
              .width('100%')
            }
            .width('80%')
            .backgroundColor(Color.White)
            .borderRadius(20)
            .padding(24)
            .shadow({ radius: 30, color: 'rgba(0,0,0,0.15)', offsetY: 10 })
            .transition(TransitionEffect.scale({ x: 0.9, y: 0.9 }).animation({ duration: 300, curve: Curve.FastOutSlowIn }))
          }
          .width('100%')
          .height('100%')
          .alignContent(Alignment.Center)
          .zIndex(999)
        }
      }
      .backgroundColor('#F5F6F8') // 全局背景微调
    }
    .hideTitleBar(true)
  }
}