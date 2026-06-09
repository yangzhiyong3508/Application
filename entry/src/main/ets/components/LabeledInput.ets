/**
 * LabeledInput - 图标 + 输入框组合
 *
 * 替代 Login/Register/Settings/UserInfoFill 手写的 "Image + TextInput" 横向布局。
 *
 * 用法：
 *   LabeledInput({
 *     icon: $r('app.media.usra'),
 *     placeholder: '请输入账号',
 *     text: $userName,
 *     inputType: InputType.Number
 *   })
 *
 *  text 用 $ 双向绑定到父组件的 @State / @StorageLink 字段
 */

@Component
export struct LabeledInput {
  @Prop icon: ResourceStr = ''
  @Prop placeholder: string = ''
  @Prop inputType: InputType = InputType.Normal
  @Prop inputHeight: number = 54
  @Prop iconSize: number = 20

  @Link text: string
  @State focused: boolean = false

  build() {
    Row({ space: 10 }) {
      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
        .fillColor(this.focused ? $r('app.color.brand_primary') : $r('app.color.text_tertiary'))
        .objectFit(ImageFit.Contain)

      TextInput({ placeholder: this.placeholder, text: this.text })
        .type(this.inputType)
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Color.Transparent)
        .fontSize($r('app.float.font_size_subtitle'))
        .placeholderColor($r('app.color.text_tertiary'))
        .fontColor($r('app.color.text_primary'))
        .onFocus((): void => {
          this.focused = true
        })
        .onBlur((): void => {
          this.focused = false
        })
        .onChange((value: string): void => {
          this.text = value
        })
    }
    .width('100%')
    .height(this.inputHeight)
    .borderRadius(16)
    .backgroundColor(this.focused ? $r('app.color.surface_card_solid') : $r('app.color.input_bg'))
    .border({
      width: 1,
      color: this.focused ? $r('app.color.brand_primary') : $r('app.color.input_border')
    })
    .padding({ left: 14, right: 14 })
    .animation({ duration: 160, curve: Curve.EaseOut })
  }
}
