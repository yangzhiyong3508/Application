import { HttpPostUtil } from './HttpPostUtil'

export interface UpdatePasswordResponse {
  success: boolean
  msg: string
}

export class UpdatePasswordUtil {
  static async updatePassword(account: number, newPassword: string): Promise<UpdatePasswordResponse> {
    try {
      const result = await HttpPostUtil.request<UpdatePasswordResponse>({
        url: `http://${AppStorage.get<string>('localhost')}:8080/api/accounts/update`,
        body: {
          "account": account,
          "password": newPassword
        }, // ✅ 直接内联对象，不定义单独类型
        headers: { 'Content-Type': 'application/json' }
      })
      return result
    } catch (error) {
      console.error('更新密码失败:', error)
      return { success: false, msg: '网络错误或服务器异常' }
    }
  }
}