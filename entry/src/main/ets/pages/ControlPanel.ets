// ============================================================
// 1. 封装单个控制按钮组件：按下只改变 SVG fillColor（不靠背景色）
// ============================================================
@Component
struct ControlBtn {
  @Prop icon: ResourceStr
  @Prop cmd: string
  @Prop angle: number = 0

  // 不加 @Prop（函数不能作为被装饰变量），由构造参数直接赋值
  onPressStart: (cmd: string) => void = () => {}
  onPressEnd: (cmd: string) => void = () => {}

  @State isPressed: boolean = false

  build() {
    Stack() {
      Image(this.icon)
        .width('50%')
        .height('50%')
        .objectFit(ImageFit.Contain)
        .rotate({ angle: this.angle })

        // SVG 变色关键：Template + fillColor
        .renderMode(ImageRenderMode.Template)
        .fillColor(this.isPressed ? '#0A59F7' : $r('sys.color.comp_background_list_card'))
        .opacity(this.isPressed ? 1.0 : 0.85)
        .animation({ duration: 120, curve: Curve.EaseInOut })
    }
    .width(80)
    .height(80)
    .borderRadius(40)

    // 不用背景色改变“按钮颜色”，背景固定为透明/轻微底
    .backgroundColor('#00000000')

    // 只做按压反馈（缩放/阴影），不参与“变色”
    .shadow({ radius: this.isPressed ? 10 : 0, color: '#0A59F780' })
    .scale({ x: this.isPressed ? 0.9 : 1.0, y: this.isPressed ? 0.9 : 1.0 })
    .animation({ duration: 120, curve: Curve.EaseOut })

    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        animateTo({ duration: 10, curve: Curve.Friction }, () => {
          this.isPressed = true
        })
        this.onPressStart(this.cmd)
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
          this.isPressed = false
        })
        this.onPressEnd(this.cmd)
      }
    })
  }
}

// ============================================================
// 2. 机械狗九宫格控制面板主组件（只保留这一份）
// ============================================================
@Component
export struct DogControlPanel {
  @Link command_index: number
  @Link current_command: string
  @Link control_open: boolean

  // 函数引用（不加装饰器）
  onPressStart: (cmd: string) => void = () => {}
  onPressEnd: (cmd: string) => void = () => {}

  build() {
    Column() {
      Image($r('app.media.down'))
        .width(24)
        .height(24)
        .renderMode(ImageRenderMode.Template)
        .fillColor('#CCCCCC')
        .onClick(() => { this.control_open = false })
        .margin({ top: 10, bottom: 8 })

      Text('机械狗控制台')
        .fontFamily('alibaba')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.comp_background_list_card'))
        .margin({ bottom: 25 })

      Column({ space: 15 }) {
        Row({ space: 15 }) {
          ControlBtn({ icon: $r('app.media.arrow_uptwo'), cmd: 'trot', angle: -45, onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.turn_up'), cmd: 'trot', angle: 0, onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.arrow_uptwo'), cmd: 'trot', angle: 45, onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
        }

        Row({ space: 15 }) {
          ControlBtn({ icon: $r('app.media.turn_left'), cmd: 'turn_left', onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.round'), cmd: 'stop', onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.turn_right'), cmd: 'turn_right', onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
        }

        Row({ space: 15 }) {
          ControlBtn({ icon: $r('app.media.arrow_downtwo'), cmd: 'trot_back', angle: 45, onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.turn_down'), cmd: 'trot_back', onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
          ControlBtn({ icon: $r('app.media.arrow_downtwo'), cmd: 'trot_back', angle: -45, onPressStart: this.onPressStart, onPressEnd: this.onPressEnd })
        }
      }
      .padding(20)
      .backgroundColor('#FFFFFF10')
      .borderRadius(30)
      .margin({ bottom: 20 })

      Row() {
        Text('Action: ')
          .fontSize(16)
          .fontColor('#AAAAAA')
          .fontFamily('alibaba')

        Text(this.current_command || 'Ready')
          .fontSize(20)
          .fontColor('#0A59F7')
          .fontWeight(FontWeight.Bold)
          .fontFamily('alibaba')
      }
      .padding({ top: 10, bottom: 20 })

    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor('#1A1A1A')
    .opacity(0.95)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 20, color: '#00000040', offsetY: -5 })
  }
}