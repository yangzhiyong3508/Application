import http from '@ohos.net.http'

/**
 * 修改用户名结果结构
 */
export interface UpdateUsernameResult {
  success: boolean
  msg: string
}

/**
 * 修改用户名工具类
 */
export class UpdateUsernameUtil {
  /**
   * 更新用户名
   * @param account 用户账号
   * @param username 新用户名
   */
  static async updateUsername(account: number, username: string): Promise<UpdateUsernameResult> {
    if (!account || !username) {
      return { success: false, msg: '参数错误' }
    }

    const localhost: string = AppStorage.get<string>('localhost') || '192.168.1.111'
    const url: string = `http://${localhost}:8080/api/accounts/updateUsername`
    const httpRequest = http.createHttp()

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 5000,
        readTimeout: 5000,
        extraData: JSON.stringify({
          account: account,
          username: username
        })
      })

      if (response.responseCode === 200) {
        const result: number = Number(response.result)
        if (result > 0) {
          // 同步到 AppStorage
          AppStorage.setOrCreate('username', username)
          return { success: true, msg: '用户名修改成功' }
        } else {
          return { success: false, msg: '用户名修改失败' }
        }
      } else {
        return { success: false, msg: `HTTP错误：${response.responseCode}` }
      }
    } catch (error) {
      console.error('修改用户名异常:', JSON.stringify(error))
      return { success: false, msg: '网络异常或服务器错误' }
    } finally {
      httpRequest.destroy()
    }
  }
}