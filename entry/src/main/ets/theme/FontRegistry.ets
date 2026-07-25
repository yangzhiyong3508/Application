/**
 * 全局字体注册
 *
 * 替代各 page 在 aboutToAppear / onAppear / onReady 中重复调用 font.registerFont 的旧做法。
 * 由 EntryAbility.onWindowStageCreate 在应用启动时统一调用一次即可。
 *
 * 用法：
 *   FontRegistry.registerAll()
 */

import { font } from '@kit.ArkUI'

export class FontRegistry {
  private static registered: boolean = false

  /**
   * 注册全部自定义字体，重复调用是幂等的
   */
  static registerAll(): void {
    if (FontRegistry.registered) return

    try {
      font.registerFont({
        familyName: 'alibaba',
        familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
      })
      FontRegistry.registered = true
    } catch (e) {
      console.warn('[FontRegistry] register failed', e)
    }
  }

  /** 查询字体是否已注册成功 */
  static isRegistered(): boolean {
    return FontRegistry.registered
  }
}
