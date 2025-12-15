import http from '@ohos.net.http'

/**
 * 修改唤醒词结果结构
 */
export interface UpdateWakeWordResult {
  success: boolean
  msg: string
}

/**
 * 修改唤醒词工具类
 */
export class UpdateWakeWordUtil {
  /**
   * 更新唤醒词
   * @param account 用户账号
   * @param wakeWord 新唤醒词
   */
  static async updateWakeWord(account: number, wakeWord: string): Promise<UpdateWakeWordResult> {
    if (!account || !wakeWord) {
      return { success: false, msg: '参数错误' }
    }

    // 从 AppStorage 获取当前后端主机地址
    const localhost: string = AppStorage.get<string>('localhost') || '192.168.1.111'
    const url: string = `http://${localhost}:8080/api/accounts/updateWakeWord`
    const httpRequest = http.createHttp()

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 5000,
        readTimeout: 5000,
        extraData: JSON.stringify({
          account: account,
          wakeWord: wakeWord
        })
      })

      if (response.responseCode === 200) {
        const result: number = Number(response.result)
        if (result > 0) {
          // ✅ 同步到 AppStorage，保证前端全局状态更新
          AppStorage.setOrCreate('wakeWord', wakeWord)
          return { success: true, msg: '唤醒词修改成功' }
        } else {
          return { success: false, msg: '唤醒词修改失败' }
        }
      } else {
        return { success: false, msg: `HTTP错误：${response.responseCode}` }
      }
    } catch (error) {
      console.error('修改唤醒词异常:', JSON.stringify(error))
      return { success: false, msg: '网络异常或服务器错误' }
    } finally {
      httpRequest.destroy()
    }
  }
}