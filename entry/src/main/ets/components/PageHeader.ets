/**
 * PageHeader - 页面顶部标题区
 *
 * 两种形态：
 *  - plain：白底 / 普通页面背景，仅标题 + 副标题
 *  - gradient：蓝色渐变背景 + 可选装饰圆 + 反白文字（用于 Personal 等"门面"页）
 *
 * 用法：
 *   PageHeader({ title: '欢迎回来', subtitle: '登录后继续使用' })
 *   PageHeader({ title: '个人中心', subtitle: '账号管理与偏好设置',
 *                useGradient: true, decoration: true, bgRotateAngle: this.bgRotateAngle })
 */

@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop useGradient: boolean = false
  @Prop decoration: boolean = false
  @Prop bgRotateAngle: number = 0
  @Prop headerHeight: number = 280

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 渐变背景层
      if (this.useGradient) {
        Column()
          .width('100%')
          .height(this.headerHeight)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [$r('app.color.brand_gradient_start'), 0.0],
              [$r('app.color.brand_gradient_end'), 1.0]
            ]
          })
      }

      // 装饰旋转圆
      if (this.useGradient && this.decoration) {
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
      }

      // 标题区
      Column({ space: 6 }) {
        Text(this.title)
          .fontSize($r('app.float.font_size_display'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.useGradient ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize($r('app.float.font_size_body'))
            .fontColor(this.useGradient ? '#D6FFFFFF' : $r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: this.useGradient ? 46 : 12,
        left: this.useGradient ? 22 : 6,
        right: this.useGradient ? 22 : 6
      })
    }
    .width('100%')
  }
}
