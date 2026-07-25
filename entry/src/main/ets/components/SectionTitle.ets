/**
 * SectionTitle - 卡片内 / 列表内的小节标题
 *
 * 用法：
 *   SectionTitle({ title: '账号信息' })
 *   SectionTitle({ title: '我的设备' }) { this.RightActionBuilder() }
 */

@Component
export struct SectionTitle {
  @Prop title: string = ''

  @BuilderParam action: () => void = this.emptyAction

  @Builder
  emptyAction(): void {
  }

  build() {
    Row({ space: 8 }) {
      Rect()
        .width(4)
        .height(16)
        .fill($r('app.color.brand_primary'))
        .borderRadius(2)

      Text(this.title)
        .fontSize($r('app.float.font_size_subtitle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      this.action()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 6, right: 6, top: 12, bottom: 8 })
  }
}
