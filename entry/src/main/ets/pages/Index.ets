import { Control } from './Control'
import { curves } from "@kit.ArkUI"
import { Conversation } from "./Conversation"
import { Personal } from "./Personal"
import { AppShadow, isTablet } from '../theme/Theme'

@Builder
export function IndexBuilder() {
  Index()
}

interface TabClass {
  text: string
  icon: ResourceStr
}

@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack()
  @State currentIndex: number = 0
  @State pageWidth: number = 0

  // 必须使用 Controller 来控制 Tabs 跳转
  private controller: TabsController = new TabsController()

  @StorageLink('account') account: number = 0
  @StorageLink('isLogin') isLogin: boolean = false

  private readonly tabData: TabClass[] = [
    { text: '控制', icon: $r('app.media.control') },
    { text: '陪伴', icon: $r('app.media.conservation') },
    { text: '我的', icon: $r('app.media.personal') },
  ]

  private ensureLoginRequired(): void {
    if (!this.isLogin) {
      this.pathStack.clear()
      this.pathStack.pushPath({ name: 'Login' }, false)
    }
  }

  onPageShow(): void {
    this.ensureLoginRequired()
  }

  build() {
    Navigation(this.pathStack) {
      // 底层 Tabs + 顶层悬浮 TabBar
      Stack({ alignContent: Alignment.Bottom }) {
        // 1. 主要内容区域 (Tabs)
        Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
          TabContent() {
            Control()
          }
          .backgroundColor($r('app.color.page_bg'))

          TabContent() {
            Conversation()
          }
          .backgroundColor($r('app.color.page_bg'))

          TabContent() {
            Personal()
          }
          .backgroundColor($r('app.color.page_bg'))
        }
        .barHeight(0)
        .scrollable(false)
        .animationDuration(300)
        .onChange((index: number) => {
          animateTo({
            curve: curves.springCurve(10, 1, 228, 30)
          }, () => {
            this.currentIndex = index
          })
        })
        .margin({ bottom: 92 })

        // 2. 自定义悬浮 TabBar
        Stack() {
          // 2.1 毛玻璃背景层
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.glass_fill'))
            .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
            .borderRadius(26)
            .border({ width: 1, color: $r('app.color.glass_border') })
            .shadow(AppShadow.bottomBar)

          // 2.2 滑块层
          Row() {
            Column() {
              Column()
                .width('88%')
                .height('76%')
                .backgroundColor($r('app.color.brand_primary_subtle'))
                .borderRadius(22)
            }
            .width('33.3%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .padding(8)
            .translate({ x: `${this.currentIndex * 100}%` })
          }
          .width('100%')
          .height('100%')
          .alignItems(VerticalAlign.Top)
          .justifyContent(FlexAlign.Start)
          .hitTestBehavior(HitTestMode.None)

          // 2.3 图标 + 文字层
          Row() {
            ForEach(this.tabData, (item: TabClass, index: number) => {
              Column({ space: 6 }) {
                Image(item.icon)
                  .width(this.currentIndex === index ? 30 : 28)
                  .height(this.currentIndex === index ? 30 : 28)
                  .fillColor(this.currentIndex === index
                    ? $r('app.color.brand_primary')
                    : $r('app.color.text_tertiary'))
                  .animation({ duration: 300 })
                  .objectFit(ImageFit.Contain)

                Text(item.text)
                  .fontSize(13)
                  .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentIndex === index
                    ? $r('app.color.brand_primary')
                    : $r('app.color.text_tertiary'))
                  .animation({ duration: 300 })
              }
              .width('33.3%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                animateTo({
                  curve: curves.springCurve(10, 1, 228, 30)
                }, () => {
                  this.currentIndex = index
                })
                this.controller.changeIndex(index)
              })
            })
          }
          .width('100%')
          .height('100%')
        }
        .width(isTablet(this.pageWidth) ? 500 : '92%')
        .height(74)
        .margin({ bottom: 12 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_bg'))
    // 全屏后允许贴到系统安全区顶部，只保留少量边距（勿再用 px 当 vp）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .padding({ top: 10 })
    .onAreaChange((oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width)
      if (!Number.isNaN(width)) {
        this.pageWidth = width
      }
    })
    .onAppear(() => {
      // 字体注册已统一移至 EntryAbility.onCreate
      this.ensureLoginRequired()
    })
  }
}
