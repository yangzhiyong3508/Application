import { SurfaceCard } from '../components/SurfaceCard'
import { isTablet } from '../theme/Theme'

@Builder
export function AboutBuilder() {
  About()
}

@Entry
@Component
struct About {
  pathStack: NavPathStack = new NavPathStack()
  @State pageWidth: number = 0

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg_alt'))

        Column({ space: 22 }) {
          // 顶部返回栏
          Row({ space: 12 }) {
            Image($r('app.media.arrow_return'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
              .onClick((): void => {
                this.pathStack.pop()
              })

            Text('关于我们')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          .height(56)
          .alignItems(VerticalAlign.Center)

          // 版本卡片
          SurfaceCard({ contentPadding: 24, emphasized: true }) {
            Column({ space: 16 }) {
              Text('版本号 1.0')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Text('版本功能：远程控制、语音参数设置、图像回传、自动追踪、语音交流、语音控制。')
                .fontSize(17)
                .lineHeight(28)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
          }
        }
        .width(isTablet(this.pageWidth) ? 680 : '100%')
        .padding({
          left: isTablet(this.pageWidth) ? 0 : 18,
          right: isTablet(this.pageWidth) ? 0 : 18,
          top: 18
        })
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .height('100%')
    .width('100%')
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pathStack = context.pathStack
      // 字体注册已移至 EntryAbility.onCreate（FontRegistry.registerAll）
    })
  }
}
