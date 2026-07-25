/**
 * 应用全局主题工具
 *
 * 设计原则：
 *   1. 颜色、圆角、间距、字号统一走 resources/base/element/*.json 中的 tokens
 *      在 ArkTS 中通过 $r('app.color.xxx') / $r('app.float.xxx') 引用
 *   2. 阴影 ArkTS 不支持 resource token，集中在本文件 AppShadow 中维护
 *   3. 颜色模式（亮色 / 深色 / 跟随系统）通过 AppTheme 服务统一管理
 *
 * 用法示例：
 *   .shadow(AppShadow.card)
 *   AppTheme.applyStoredMode(getContext(this).getApplicationContext())
 *   AppTheme.setMode(ctx, 'dark')
 */

import { common, ConfigurationConstant } from '@kit.AbilityKit'

/* ============================================================
 * 颜色模式偏好
 * ============================================================ */

export type ColorModePref = 'light' | 'dark' | 'system'

export class AppTheme {
  static readonly STORAGE_KEY: string = 'colorModePref'
  static readonly DEFAULT_MODE: ColorModePref = 'system'

  /**
   * 读取用户保存的颜色模式偏好
   */
  static getStoredMode(): ColorModePref {
    const v: ColorModePref | undefined = AppStorage.get<ColorModePref>(AppTheme.STORAGE_KEY)
    return v ?? AppTheme.DEFAULT_MODE
  }

  /**
   * 设置并立即应用颜色模式
   * @param context ApplicationContext，从 getContext(this).getApplicationContext() 取
   * @param mode 'light' | 'dark' | 'system'
   */
  static setMode(context: common.ApplicationContext, mode: ColorModePref): void {
    AppStorage.setOrCreate(AppTheme.STORAGE_KEY, mode)

    let cm: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === 'light') {
      cm = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (mode === 'dark') {
      cm = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }

    try {
      context.setColorMode(cm)
    } catch (e) {
      console.warn('[AppTheme] setColorMode failed', e)
    }
  }

  /**
   * 应用启动时调用一次，把上次保存的偏好恢复到系统
   */
  static applyStoredMode(context: common.ApplicationContext): void {
    AppTheme.setMode(context, AppTheme.getStoredMode())
  }
}

/* ============================================================
 * 阴影预设
 * ============================================================
 * ArkTS 的 .shadow() 接受 ShadowOptions（radius / color / offsetX / offsetY / type / fill）
 * 这里集中维护，业务侧直接 .shadow(AppShadow.card) 使用
 *
 * 颜色采用 ArkTS 8 位 hex（#AARRGGBB），不会因深浅色切换而失真：
 *   - light 模式下阴影偏蓝灰
 *   - dark 模式下阴影颜色保持，但因背景变深而自然弱化
 * ============================================================ */

/**
 * 阴影选项结构：与 ArkUI 的 ShadowOptions 结构兼容
 *  - radius / color / offsetY 必填或语义可选
 *  - 不导出，仅用于本文件内类型推导
 */
interface AppShadowOption {
  radius: number
  color: string
  offsetX?: number
  offsetY: number
}

export class AppShadow {
  /** 普通卡片：用于 SurfaceCard 默认态 */
  static readonly card: AppShadowOption = {
    radius: 14,
    color: '#141F78FF',
    offsetY: 4
  }

  /** 强调卡片：用于个人中心 / 设置等大块信息卡 */
  static readonly cardHover: AppShadowOption = {
    radius: 22,
    color: '#1F1F78FF',
    offsetY: 8
  }

  /** 主按钮：渐变 + 蓝色光晕 */
  static readonly button: AppShadowOption = {
    radius: 16,
    color: '#381F78FF',
    offsetY: 7
  }

  /** 弹窗：深而柔 */
  static readonly dialog: AppShadowOption = {
    radius: 30,
    color: '#26000000',
    offsetY: 10
  }

  /** 轻微阴影：用于分组、聊天气泡等小元素 */
  static readonly subtle: AppShadowOption = {
    radius: 10,
    color: '#12000000',
    offsetY: 2
  }

  /** 浮动 TabBar：向上发散 */
  static readonly bottomBar: AppShadowOption = {
    radius: 26,
    color: '#1A1F78FF',
    offsetY: -6
  }

  /** 无阴影占位：用于条件式 .shadow() 调用 */
  static readonly none: AppShadowOption = {
    radius: 0,
    color: '#00000000',
    offsetY: 0
  }
}

/* ============================================================
 * 平板布局断点
 * ============================================================
 * 与 resources/.../float.json 的 tablet_breakpoint 保持一致
 * 业务侧若已拿到 pageWidth，可直接调用 isTablet(width)
 * ============================================================ */

export const TABLET_BREAKPOINT: number = 700

export function isTablet(pageWidth: number): boolean {
  return pageWidth >= TABLET_BREAKPOINT
}
