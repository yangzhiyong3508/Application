/**
 * PrimaryButton - 渐变主按钮（含加载态）
 *
 * 替代 Login/Register/Settings/UserInfoFill 手写的渐变按钮。
 *
 * 用法：
 *   PrimaryButton({
 *     text: '登录',
 *     loading: this.isLoading,
 *     onTap: () => this.handleLogin()
 *   })
 */

import { AppShadow } from '../theme/Theme'

@Component
export struct PrimaryButton {
  @Prop text: string = ''
  @Prop loading: boolean = false
  @Prop disabled: boolean = false
  @Prop btnHeight: number = 54
  @Prop loadingText: string = '请稍候...'

  onTap: () => void = () => {
  }

  @State pressed: boolean = false

  build() {
    Button() {
      if (this.loading) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.text_on_brand'))

          Text(this.loadingText)
            .fontColor($r('app.color.text_on_brand'))
            .fontSize($r('app.float.font_size_subtitle'))
        }
      } else {
        Text(this.text)
          .fontSize(18)
          .fontColor($r('app.color.text_on_brand'))
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height(this.btnHeight)
    .borderRadius(16)
    .linearGradient({
      direction: GradientDirection.Right,
      colors: this.loading || this.disabled
        ? [
            [$r('app.color.brand_primary_disabled'), 0],
            [$r('app.color.brand_primary_disabled'), 1]
          ]
        : [
            [$r('app.color.brand_gradient_start'), 0],
            [$r('app.color.brand_gradient_end'), 1]
          ]
    })
    .shadow(AppShadow.button)
    .opacity(this.disabled ? 0.72 : 1)
    .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .enabled(!this.loading && !this.disabled)
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down && !this.loading && !this.disabled) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onTap())
  }
}
