/**
 * SurfaceCard - 通用卡片基底
 *
 * 替代各页面手写的 Column().backgroundColor(...).border(...).shadow(...) 组合。
 *
 * 用法：
 *   SurfaceCard({ variant: CardVariant.Glass, contentPadding: 18 }) {
 *     Text('卡片内容')
 *   }
 *
 * 注意：prop 名避开 ArkTS CustomComponent 基类的 modifier（padding/height/size/width/margin 等）。
 */

import { AppShadow } from '../theme/Theme'

export enum CardVariant {
  /** 半透明白底 + 边框（玻璃质感，亮色下推荐） */
  Glass = 'glass',
  /** 实心白底（无玻璃感，适合深色或需要更高对比时） */
  Solid = 'solid'
}

@Component
export struct SurfaceCard {
  @Prop variant: CardVariant = CardVariant.Glass
  @Prop contentPadding: number = 16
  @Prop radius: number = 18
  @Prop useShadow: boolean = true
  @Prop emphasized: boolean = false

  @BuilderParam content: () => void = this.defaultContent

  @Builder
  defaultContent(): void {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.contentPadding)
    .borderRadius(this.radius)
    .backgroundColor(
      this.variant === CardVariant.Glass
        ? $r('app.color.surface_card')
        : $r('app.color.surface_card_solid')
    )
    .border({
      width: 1,
      color: $r('app.color.surface_border')
    })
    .shadow(
      this.useShadow
        ? (this.emphasized ? AppShadow.cardHover : AppShadow.card)
        : AppShadow.none
    )
  }
}
