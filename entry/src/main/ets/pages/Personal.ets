import promptAction from "@ohos.promptAction"
import { UpdateUsernameUtil } from '../utils/UpdateUsernameUtil'
import { CommonConstant } from '../utils/GetIotToken'
import { DEFAULT_XFYUN_VOICE } from '../utils/XfyunVoiceUtil'
import { SurfaceCard } from '../components/SurfaceCard'
import { IconBadge } from '../components/IconBadge'
import { StatusChip, ChipTone } from '../components/StatusChip'
import { SectionTitle } from '../components/SectionTitle'
import { AppTheme, ColorModePref, isTablet } from '../theme/Theme'

@Builder
export function PersonalBuilder() {
  Personal()
}

interface MenuItem {
  iconSrc: ResourceStr
  title: string
  subtitle: string
  toPage: string
  iconBgKey: string
  iconColorKey: string
  requiresLogin: boolean
}

interface ThemeOption {
  label: string
  value: ColorModePref
}

@Component
export struct Personal {
  pathStack: NavPathStack = new NavPathStack()
  @Consume('pathStack') rootPathStack: NavPathStack

  @StorageLink('account') account: number = 0
  @StorageLink('password') password: string = ''
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('username') username: string = '请先登录'
  @StorageLink('avatar') avatar: number | string = 1
  @StorageLink('colorModePref') colorMode: ColorModePref = 'system'

  @State showDialog: boolean = false
  @State tempUsername: string = ''
  @State bgRotateAngle: number = 0
  @State pageWidth: number = 0

  private readonly localAvatarList: Array<ResourceStr> = [
    $r('app.media.avatar0'),
    $r('app.media.avatar1'),
    $r('app.media.avatar2'),
    $r('app.media.avatar3')
  ]

  private readonly menuItems: Array<MenuItem> = [
    {
      iconSrc: $r('app.media.setting'),
      title: '系统设置',
      subtitle: '账号安全、通用设置',
      toPage: 'Settings',
      iconBgKey: 'brand_primary_subtle',
      iconColorKey: 'brand_primary',
      requiresLogin: true
    },
    {
      iconSrc: $r('app.media.control'),
      title: '舵机校准',
      subtitle: '按编号调整单个舵机角度',
      toPage: 'ServoAdjust',
      iconBgKey: 'state_success_subtle',
      iconColorKey: 'state_success',
      requiresLogin: true
    },
    {
      iconSrc: $r('app.media.about'),
      title: '关于我们',
      subtitle: '版本 v1.0.0',
      toPage: 'About',
      iconBgKey: 'state_warning_subtle',
      iconColorKey: 'state_warning',
      requiresLogin: false
    }
  ]

  private readonly themeOptions: ThemeOption[] = [
    { label: '跟随系统', value: 'system' },
    { label: '浅色', value: 'light' },
    { label: '深色', value: 'dark' }
  ]

  aboutToAppear(): void {
    setTimeout((): void => {
      this.startSpectrumAnimation()
    }, 120)
  }

  startSpectrumAnimation(): void {
    animateTo({
      duration: 14000,
      curve: Curve.Linear,
      iterations: -1,
    }, (): void => {
      this.bgRotateAngle = 360
    })
  }

  private getAvatarSrc(): ResourceStr | string {
    if (!this.isLogin) return this.localAvatarList[0]
    if (typeof this.avatar === 'string' && this.avatar.length > 0) return this.avatar
    if (typeof this.avatar === 'number') return this.localAvatarList[this.avatar] || this.localAvatarList[0]
    return this.localAvatarList[0]
  }

  private showEditUsernameDialog(): void {
    if (this.isLogin) {
      this.tempUsername = this.username
      this.showDialog = true
      return
    }
    promptAction.showToast({ message: '请先登录！' })
    this.goRootLogin(true)
  }

  private async confirmChangeUsername(): Promise<void> {
    const name: string = this.tempUsername.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: '用户名不能为空' })
      return
    }

    const result = await UpdateUsernameUtil.updateUsername(this.account, name)
    if (result.success) {
      this.username = name
      this.showDialog = false
    }
    promptAction.showToast({ message: result.msg })
  }

  private openMenu(item: MenuItem): void {
    if (!item.requiresLogin || this.isLogin) {
      this.pathStack.pushPathByName(item.toPage, null)
      return
    }
    promptAction.showToast({ message: '请先登录' })
    this.goRootLogin(true)
  }

  private goRootLogin(clearRootStack: boolean): void {
    if (clearRootStack) {
      this.rootPathStack.clear()
    }
    this.rootPathStack.pushPath({ name: 'Login' }, false)
  }

  private clearLocalCache(): void {
    this.account = 0
    this.password = ''
    this.username = '请先登录'
    this.avatar = 1
    this.isLogin = false

    AppStorage.setOrCreate('account', 0)
    AppStorage.setOrCreate('password', '')
    AppStorage.setOrCreate('username', '请先登录')
    AppStorage.setOrCreate('avatar', 1)
    AppStorage.setOrCreate('avatarUrl', '')
    AppStorage.setOrCreate('isLogin', false)

    AppStorage.setOrCreate('current_command', '')
    AppStorage.setOrCreate('isTrace', false)
    AppStorage.setOrCreate('per', 4)
    AppStorage.setOrCreate('spd', 6)
    AppStorage.setOrCreate('pid', 10)
    AppStorage.setOrCreate('voiceId', DEFAULT_XFYUN_VOICE)
    AppStorage.setOrCreate('speedRatio', 1.0)
    AppStorage.setOrCreate('vol', 50)
    AppStorage.setOrCreate('wakeWord', '小E')
    AppStorage.setOrCreate('petName', '小E')

    CommonConstant.token = ''
  }

  private logout(): void {
    this.clearLocalCache()
    this.pathStack.clear()
    this.goRootLogin(true)
  }

  private applyColorMode(mode: ColorModePref): void {
    this.colorMode = mode
    try {
      const appCtx = getContext(this).getApplicationContext()
      AppTheme.setMode(appCtx, mode)
    } catch (e) {
      console.warn('[Personal] applyColorMode failed', e)
    }
  }

  /**
   * 解析图标徽章背景色（从 string token key 到 Resource）
   * 注：ArkTS 不允许 $r() 接收变量字符串，所以用 switch 显式映射
   */
  private resolveTokenColor(key: string): ResourceColor {
    switch (key) {
      case 'brand_primary':         return $r('app.color.brand_primary')
      case 'brand_primary_subtle':  return $r('app.color.brand_primary_subtle')
      case 'state_success':         return $r('app.color.state_success')
      case 'state_success_subtle':  return $r('app.color.state_success_subtle')
      case 'state_warning':         return $r('app.color.state_warning')
      case 'state_warning_subtle':  return $r('app.color.state_warning_subtle')
      case 'state_info':            return $r('app.color.state_info')
      case 'state_info_subtle':     return $r('app.color.state_info_subtle')
      default:                      return $r('app.color.brand_primary')
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {
        // 1. 页面底
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg_alt'))

        // 2. 顶部蓝色渐变
        Column()
          .width('100%')
          .height(326)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [$r('app.color.brand_gradient_start'), 0.0],
              [$r('app.color.brand_gradient_end'), 1.0]
            ]
          })

        // 3. 装饰旋转圆
        Circle()
          .width(320)
          .height(320)
          .fill('#29FFFFFF')
          .position({ x: 220, y: -130 })
          .rotate({ angle: this.bgRotateAngle })

        Circle()
          .width(250)
          .height(250)
          .fill('#1AFFFFFF')
          .position({ x: -100, y: 130 })
          .rotate({ angle: -this.bgRotateAngle * 0.6 })

        // 4. 主内容
        Scroll() {
          Column() {
            // 标题
            Column({ space: 6 }) {
              Text('个人中心')
                .fontSize($r('app.float.font_size_display'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_brand'))

              Text('账号管理与偏好设置')
                .fontSize($r('app.float.font_size_body'))
                .fontColor('#D6FFFFFF')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 46, left: 6 })

            // 用户信息卡（外层 Column 用于承载 .margin，ArkTS 不允许在带内容块的自定义组件后链式调用通用 modifier）
            Column() {
              SurfaceCard({ contentPadding: 18, radius: 24, emphasized: true }) {
                Column({ space: 14 }) {
                  Row() {
                  Stack({ alignContent: Alignment.BottomEnd }) {
                    Circle()
                      .width(98)
                      .height(98)
                      .fill('#142573E6')
                      .border({ width: 1, color: '#332274FF' })

                    Image(this.getAvatarSrc())
                      .width(90)
                      .height(90)
                      .borderRadius(45)
                      .objectFit(ImageFit.Cover)
                      .border({ width: 3, color: $r('app.color.surface_card_solid') })
                      .backgroundColor($r('app.color.brand_primary_subtle'))

                    if (!this.isLogin) {
                      Circle()
                        .width(24)
                        .height(24)
                        .fill($r('app.color.state_danger'))
                        .border({ width: 2, color: $r('app.color.surface_card_solid') })
                        .overlay('!', { align: Alignment.Center, offset: { x: 0, y: 1 } })
                    }
                  }
                  .onClick(() => {
                    if (!this.isLogin) {
                      this.goRootLogin(true)
                    }
                  })

                  Column({ space: 8 }) {
                    Row({ space: 8 }) {
                      Text(this.username)
                        .fontSize(24)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      if (this.isLogin) {
                        Image($r('sys.media.ohos_ic_public_edit'))
                          .width(16)
                          .height(16)
                          .fillColor($r('app.color.text_secondary'))
                          .onClick(() => this.showEditUsernameDialog())
                      }
                    }

                    Text(this.isLogin ? `ID: ${this.account}` : '登录后可同步头像和设置')
                      .fontSize($r('app.float.font_size_body'))
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)

                    StatusChip({
                      label: this.isLogin ? '已登录' : '未登录',
                      tone: this.isLogin ? ChipTone.Success : ChipTone.Warning,
                      showDot: true
                    })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 16 })

                  if (!this.isLogin) {
                    Image($r('sys.media.ohos_ic_public_arrow_right'))
                      .width(18)
                      .height(18)
                      .fillColor($r('app.color.text_tertiary'))
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                // 状态条
                Row({ space: 10 }) {
                  Row({ space: 8 }) {
                    Circle()
                      .width(8)
                      .height(8)
                      .fill(this.isLogin ? $r('app.color.state_success') : $r('app.color.state_warning'))

                    Text(this.isLogin ? '账号状态正常' : '请先完成登录')
                      .fontSize($r('app.float.font_size_body'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .layoutWeight(1)
                  .height(42)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor($r('app.color.brand_primary_subtle'))
                  .borderRadius(14)

                  Row({ space: 8 }) {
                    Circle()
                      .width(8)
                      .height(8)
                      .fill($r('app.color.brand_primary'))

                    Text('偏好配置已同步')
                      .fontSize($r('app.float.font_size_body'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .layoutWeight(1)
                  .height(42)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor($r('app.color.brand_primary_subtle'))
                  .borderRadius(14)
                }
                .width('100%')
              }
            }
            }
            .margin({ top: -16 })

            // 外观设置（新增：深色模式开关）
            SectionTitle({ title: '外观' })
            SurfaceCard({ contentPadding: 6, radius: 18 }) {
              Row() {
                ForEach(this.themeOptions, (opt: ThemeOption) => {
                  Column() {
                    Text(opt.label)
                      .fontSize($r('app.float.font_size_body'))
                      .fontWeight(this.colorMode === opt.value ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.colorMode === opt.value
                        ? $r('app.color.brand_primary')
                        : $r('app.color.text_secondary'))
                  }
                  .layoutWeight(1)
                  .height(40)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.colorMode === opt.value
                    ? $r('app.color.brand_primary_subtle')
                    : Color.Transparent)
                  .borderRadius(14)
                  .onClick(() => this.applyColorMode(opt.value))
                })
              }
              .width('100%')
            }

            // 菜单
            SectionTitle({ title: '更多' })
            SurfaceCard({ contentPadding: 0, radius: 24 }) {
              Column() {
                ForEach(this.menuItems, (item: MenuItem, index: number) => {
                  Row() {
                    Row({ space: 14 }) {
                      IconBadge({
                        icon: item.iconSrc,
                        bgColor: this.resolveTokenColor(item.iconBgKey),
                        iconColor: this.resolveTokenColor(item.iconColorKey),
                        badgeSize: 42,
                        iconSize: 20
                      })

                      Column({ space: 4 }) {
                        Text(item.title)
                          .fontSize($r('app.float.font_size_subtitle'))
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))

                        Text(item.subtitle)
                          .fontSize($r('app.float.font_size_caption'))
                          .fontColor($r('app.color.text_secondary'))
                      }
                      .alignItems(HorizontalAlign.Start)
                    }

                    Image($r('sys.media.ohos_ic_public_arrow_right'))
                      .width(16)
                      .height(16)
                      .fillColor($r('app.color.text_tertiary'))
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                  .justifyContent(FlexAlign.SpaceBetween)
                  .onClick(() => this.openMenu(item))

                  if (index < this.menuItems.length - 1) {
                    Divider()
                      .color($r('app.color.divider'))
                      .strokeWidth(1)
                      .margin({ left: 72, right: 16 })
                  }
                })
              }
            }

            // 退出登录
            if (this.isLogin) {
              Button('退出登录')
                .width('100%')
                .height(50)
                .backgroundColor($r('app.color.state_danger_subtle'))
                .fontColor($r('app.color.state_danger'))
                .fontSize($r('app.float.font_size_subtitle'))
                .fontWeight(FontWeight.Medium)
                .borderRadius(16)
                .margin({ top: 6, bottom: 6 })
                .onClick(() => this.logout())
            }
          }
          .width(isTablet(this.pageWidth) ? 760 : '100%')
          .align(Alignment.Center)
          .padding({
            left: isTablet(this.pageWidth) ? 0 : 16,
            right: isTablet(this.pageWidth) ? 0 : 16,
            top: isTablet(this.pageWidth) ? 18 : 6,
            bottom: 28
          })
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.SpaceAround)
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')

        // 改名弹窗
        if (this.showDialog) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.overlay_bg'))
              .onClick(() => this.showDialog = false)

            Column({ space: 18 }) {
              Text('修改昵称')
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              TextInput({ text: this.tempUsername, placeholder: '请输入新昵称' })
                .width('100%')
                .height(46)
                .backgroundColor($r('app.color.input_bg'))
                .borderRadius(10)
                .padding({ left: 14, right: 14 })
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .onChange((val) => this.tempUsername = val)
                .defaultFocus(true)

              Row({ space: 12 }) {
                Button('取消')
                  .layoutWeight(1)
                  .height(40)
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.input_bg'))
                  .borderRadius(20)
                  .onClick(() => this.showDialog = false)

                Button('保存')
                  .layoutWeight(1)
                  .height(40)
                  .fontSize(15)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.brand_primary'))
                  .borderRadius(20)
                  .onClick(() => this.confirmChangeUsername())
              }
              .width('100%')
            }
            .width(isTablet(this.pageWidth) ? 420 : '82%')
            .padding(22)
            .backgroundColor($r('app.color.surface_card_solid'))
            .borderRadius(20)
            .transition(TransitionEffect.scale({ x: 0.9, y: 0.9 }).animation({ duration: 220 }))
          }
          .width('100%')
          .height('100%')
          .alignContent(Alignment.Center)
          .zIndex(999)
        }
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
  }
}
