/**
 * StatusChip - 状态徽章
 *
 * 替代各页面手写的"圆角小色块 + 文字"组合，统一走语义色 tokens。
 *
 * 用法：
 *   StatusChip({ label: '已登录', tone: ChipTone.Success })
 *   StatusChip({ label: '未连接', tone: ChipTone.Warning })
 */

export enum ChipTone {
  Success = 'success',
  Warning = 'warning',
  Danger = 'danger',
  Info = 'info',
  Brand = 'brand'
}

@Component
export struct StatusChip {
  @Prop label: string = ''
  @Prop tone: ChipTone = ChipTone.Brand
  @Prop showDot: boolean = false

  private getBg(): ResourceColor {
    switch (this.tone) {
      case ChipTone.Success:
        return $r('app.color.state_success_subtle')
      case ChipTone.Warning:
        return $r('app.color.state_warning_subtle')
      case ChipTone.Danger:
        return $r('app.color.state_danger_subtle')
      case ChipTone.Info:
        return $r('app.color.state_info_subtle')
      default:
        return $r('app.color.brand_primary_subtle')
    }
  }

  private getFg(): ResourceColor {
    switch (this.tone) {
      case ChipTone.Success:
        return $r('app.color.state_success')
      case ChipTone.Warning:
        return $r('app.color.state_warning')
      case ChipTone.Danger:
        return $r('app.color.state_danger')
      case ChipTone.Info:
        return $r('app.color.state_info')
      default:
        return $r('app.color.brand_primary')
    }
  }

  build() {
    Row({ space: 6 }) {
      if (this.showDot) {
        Circle()
          .width(6)
          .height(6)
          .fill(this.getFg())
      }

      Text(this.label)
        .fontSize($r('app.float.font_size_caption'))
        .fontColor(this.getFg())
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .backgroundColor(this.getBg())
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }
}
