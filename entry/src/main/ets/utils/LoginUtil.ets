import http from '@ohos.net.http'
import { normalizeXfyunVoiceId } from './XfyunVoiceUtil'

/**
 * 后端返回的账户信息结构（对应后端 Account.java）
 */
export interface AccountData {
  id: number
  account: number
  password: string
  username: string
  avatarUrl: string

  // 旧有的运动参数
  per: number
  spd: number
  pid: number

  // 🔥 新增语音相关字段 (需与后端 JSON 返回字段名一致)
  vol: number        // 音量
  voiceId?: string   // 音色 ID
  speedRatio?: number // 语速倍率
  wakeWord?: string  // 唤醒词
}

/**
 * 登录结果结构
 */
export interface LoginResult {
  success: boolean
  msg: string
  user?: AccountData
}

export class LoginUtil {
  /**
   * 登录方法
   * @param account 账号
   * @param password 密码
   */
  static async login(account: string, password: string): Promise<LoginResult> {
    if (!account || !password) {
      return { success: false, msg: '账号或密码不能为空' }
    }

    const localhost = AppStorage.get<string>('localhost')
    // 使用后端提供的查询接口
    const url = `http://${localhost}:8080/api/accounts/account/${account}`
    const httpRequest = http.createHttp()

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      })

      if (response.responseCode !== 200) {
        return { success: false, msg: `HTTP错误: ${response.responseCode}` }
      }

      // 解析返回的账号数据
      const result: AccountData[] = JSON.parse(response.result as string) as AccountData[]
      if (!result || result.length === 0) {
        return { success: false, msg: '账号不存在' }
      }

      const user: AccountData = result[0]
      // 简单的密码比对（实际生产环境建议后端比对）
      if (String(user.password) !== password) {
        return { success: false, msg: '密码错误' }
      }

      // ============================================================
      // 登录成功 — 将用户信息写入全局 AppStorage
      // ============================================================
      AppStorage.setOrCreate('account', user.account)
      AppStorage.setOrCreate('username', user.username)
      AppStorage.setOrCreate('avatarUrl', user.avatarUrl ?? '')
      AppStorage.setOrCreate('avatar', user.avatarUrl && user.avatarUrl.length > 0 ? user.avatarUrl : 1)

      // 运动参数
      AppStorage.setOrCreate('per', user.per)
      AppStorage.setOrCreate('spd', user.spd)
      AppStorage.setOrCreate('pid', user.pid)

      // 🔥 核心修改：设置语音参数全局变量 (带默认值兜底)

      // 1. 音量 (vol)
      AppStorage.setOrCreate('vol', user.vol ?? 50)

      // 2. 音色 ID (voiceId) - 兼容历史阿里云音色，统一迁移为讯飞音色
      const normalizedVoiceId: string = normalizeXfyunVoiceId(user.voiceId)
      AppStorage.setOrCreate('voiceId', normalizedVoiceId)

      // 3. 语速 (speedRatio) - 默认为 1.0
      AppStorage.setOrCreate('speedRatio', user.speedRatio ?? 1.0)

      // 4. 唤醒词与宠物名保持一致
      const normalizedWakeWord: string = user.wakeWord || '小E'
      AppStorage.setOrCreate('wakeWord', normalizedWakeWord)
      AppStorage.setOrCreate('petName', normalizedWakeWord)

      // 登录状态
      AppStorage.setOrCreate('isLogin', true)
      AppStorage.setOrCreate('password', String(user.password)) // 建议仅在需要时保存

      return {
        success: true,
        msg: `登录成功，欢迎 ${user.username}`,
        user: user
      }
    } catch (err) {
      console.error('登录异常:', err)
      return { success: false, msg: '网络错误或服务器异常' }
    } finally {
      httpRequest.destroy()
    }
  }
}
