/**
 * EmptyState - 空态占位
 *
 * 替代 ChatHistory / Command 等列表页的"无数据"硬编码 UI。
 *
 * 用法：
 *   EmptyState({
 *     icon: $r('app.media.command'),
 *     title: '暂无指令',
 *     tip: '快去添加你的第一条自定义指令吧'
 *   })
 *
 *   EmptyState({
 *     icon: $r('app.media.conservation'),
 *     title: '还没和小狗聊过天',
 *     tip: '点击下方按钮开始第一次对话',
 *     actionText: '开始聊天',
 *     onAction: () => this.startChat()
 *   })
 */

@Component
export struct EmptyState {
  @Prop icon: ResourceStr = ''
  @Prop title: string = ''
  @Prop tip: string = ''
  @Prop actionText: string = ''

  onAction: () => void = () => {
  }

  build() {
    Column({ space: 12 }) {
      if (this.icon !== '') {
        Image(this.icon)
          .width(64)
          .height(64)
          .fillColor($r('app.color.text_tertiary'))
          .opacity(0.55)
          .objectFit(ImageFit.Contain)
      }

      Text(this.title)
        .fontSize($r('app.float.font_size_subtitle'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)

      if (this.tip !== '') {
        Text(this.tip)
          .fontSize($r('app.float.font_size_body'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
      }

      if (this.actionText !== '') {
        Button(this.actionText)
          .fontSize($r('app.float.font_size_body'))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_primary_subtle'))
          .height(40)
          .padding({ left: 22, right: 22 })
          .borderRadius(20)
          .margin({ top: 6 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
