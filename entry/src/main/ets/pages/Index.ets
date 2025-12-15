import { Control } from './Control'
import { font, curves } from "@kit.ArkUI";
import { Conversation } from "./Conversation";
import { Personal } from "./Personal";

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
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  @State currentIndex: number = 0;

  // 必须使用 Controller 来控制 Tabs 跳转
  private controller: TabsController = new TabsController()

  @StorageLink('account') account: number = 0
  @StorageLink('isLogin') isLogin: boolean = false

  private readonly tabData: TabClass[] = [
    { text: '智控', icon: $r('app.media.control') },
    { text: '对话', icon: $r('app.media.conservation') },
    { text: '我的', icon: $r('app.media.personal') },
  ]

  // 配色配置
  private readonly activeColor: string = '#4158D0' // 选中文字颜色
  private readonly inactiveColor: string = '#999999' // 未选中文字颜色
  private readonly sliderColor: string = '#E6F0FF' // 滑块背景色（浅蓝）

  build() {
    Navigation(this.pathStack) {
      // 使用 Stack 堆叠布局：底层是 Tabs 内容，顶层是悬浮的自定义 TabBar
      Stack({ alignContent: Alignment.Bottom }) {

        // 1. 主要内容区域 (Tabs)
        Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
          TabContent() {
            Control()
          }
          .backgroundColor('#F5F6F8')

          TabContent() {
            Conversation()
          }
          .backgroundColor('#F5F6F8')

          TabContent() {
            Personal()
          }
          .backgroundColor('#F5F6F8')
        }
        .barHeight(0) // ⚠️ 关键：隐藏原生 TabBar，完全交给我们自定义的来接管
        .scrollable(true) // 允许手势滑动切换
        .animationDuration(300)
        .onChange((index: number) => {
          // 页面滑动时，同步更新 currentIndex，触发底部滑块动画
          animateTo({
            curve: curves.springCurve(10, 1, 228, 30) // 物理弹簧曲线
          }, () => {
            this.currentIndex = index
          })
        })
        .margin({ bottom: 80 }) // ⚠️ 关键：给底部留出 80vp 的空间，防止内容被自定义 Bar 遮挡

        // 2. 自定义悬浮 TabBar
        Stack() {
          // 2.1 背景层 (纯白卡片 + 阴影)
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.White)
            .borderRadius({ topLeft: 24, topRight: 24 }) // 顶部圆角
            .shadow({ radius: 30, color: 'rgba(0,0,0,0.08)', offsetY: -5 })

          // 2.2 核心动画层：滑块 (Sliding Block)
          // 根据 currentIndex 计算位置
          Row() {
            Column() {
              // 滑块本体（胶囊形状）
              Column()
                .width('90%')
                .height('85%')
                .backgroundColor(this.sliderColor) // 浅蓝色背景
                .borderRadius(20)
            }
            .width('33.3%') // 3个Tab，每个占 1/3
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .padding(8) // 内边距，让滑块别填太满
            .translate({ x: `${this.currentIndex * 100}%` }) // 📍 核心位移逻辑：0%, 100%, 200%
          }
          .width('100%')
          .height('100%')
          // 这里的 Row 必须左对齐，才能让 translate 正确工作
          .alignItems(VerticalAlign.Top)
          .justifyContent(FlexAlign.Start)
          .hitTestBehavior(HitTestMode.None) // 穿透点击，让下层能响应（虽然这里不需要，但习惯加上）

          // 2.3 前景交互层：图标和文字
          Row() {
            ForEach(this.tabData, (item: TabClass, index: number) => {
              Column({ space: 6 }) {
                Image(item.icon)
                  .width(32) // 🔥 放大图标
                  .height(32)
                  .fillColor(this.currentIndex === index ? this.activeColor : this.inactiveColor)
                  .animation({ duration: 300 }) // 图标变色动画
                  .objectFit(ImageFit.Contain)

                Text(item.text)
                  .fontFamily('alibaba')
                  .fontSize(14) // 🔥 放大字体
                  .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentIndex === index ? this.activeColor : this.inactiveColor)
                  .animation({ duration: 300 })
              }
              .width('33.3%') // 等分宽度
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                // 点击时触发动画和切换
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
        .width('100%')
        .height(88) // 🔥 整体加高 (包含底部安全区)
        .padding({ bottom: 12 }) // 避开底部 Home 条
      }
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .backgroundColor('#F5F6F8')
    .onAppear(() => {
      try {
        font.registerFont({
          familyName: 'alibaba',
          familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
        })
      } catch (e) {}

      setTimeout(() => {
        if (!this.isLogin) {
          this.pathStack.pushPath({ name: 'Login' }, false)
        }
      }, 100)
    })
  }
}