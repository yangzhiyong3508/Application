/**
 * SurfaceCard - 通用卡片基底
 *
 * Glass 变体：半透明底 + 背景模糊（毛玻璃）
 * Solid 变体：不透明白底
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
  /** 毛玻璃：半透明 + 背景模糊 */
  Glass = 'glass',
  /** 实心白底 */
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
        ? $r('app.color.glass_fill')
        : $r('app.color.surface_card_solid')
    )
    .backgroundBlurStyle(
      this.variant === CardVariant.Glass
        ? BlurStyle.COMPONENT_THIN
        : BlurStyle.NONE
    )
    .border({
      width: 1,
      color: this.variant === CardVariant.Glass
        ? $r('app.color.glass_border')
        : $r('app.color.surface_border')
    })
    .shadow(
      this.useShadow
        ? (this.emphasized ? AppShadow.cardHover : AppShadow.card)
        : AppShadow.none
    )
  }
}
