/**
 * IconBadge - 圆形彩色背景 + 中心图标
 *
 * 替代 Personal/Settings 菜单项中手写的 Stack { Circle + Image } 组合。
 *
 * 用法：
 *   IconBadge({
 *     icon: $r('app.media.setting'),
 *     bgColor: $r('app.color.brand_primary_subtle'),
 *     iconColor: $r('app.color.brand_primary'),
 *     size: 42
 *   })
 */

@Component
export struct IconBadge {
  @Prop icon: ResourceStr = ''
  @Prop bgColor: ResourceColor = '#FFEEF5FF'
  @Prop iconColor: ResourceColor = '#FF2D7EF0'
  @Prop badgeSize: number = 42
  @Prop iconSize: number = 20
  @Prop bordered: boolean = false

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(this.badgeSize)
        .height(this.badgeSize)
        .fill(this.bgColor)

      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
        .fillColor(this.iconColor)
        .objectFit(ImageFit.Contain)
    }
    .width(this.badgeSize)
    .height(this.badgeSize)
    .border({
      width: this.bordered ? 1 : 0,
      color: $r('app.color.surface_border')
    })
    .borderRadius(this.badgeSize / 2)
  }
}
