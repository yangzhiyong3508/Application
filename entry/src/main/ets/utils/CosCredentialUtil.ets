import http from '@ohos.net.http'

/**
 * COS 凭证结果结构
 */
export interface CosCredentialResult {
  success: boolean
  secretId: string
  secretKey: string
  msg: string
}

/**
 * COS 凭证获取工具类
 *
 * 后端接口约定：
 *   GET http://{localhost}:8080/api/cos/credentials
 *   返回 JSON: { "secretId": "xxx", "secretKey": "yyy" }
 */
export class CosCredentialUtil {
  static async fetchCredentials(): Promise<CosCredentialResult> {
    const localhost: string = AppStorage.get<string>('localhost') || '118.195.133.25'
    const url: string = `http://${localhost}:8080/api/accounts/cos-credentials`
    const httpRequest = http.createHttp()

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 5000,
        readTimeout: 5000
      })

      if (response.responseCode === 200) {
        let resultText: string = ''
        if (typeof response.result === 'string') {
          resultText = response.result
        } else {
          resultText = JSON.stringify(response.result)
        }
        const data = JSON.parse(resultText) as CosCredentialResult
        if (data.secretId && data.secretId.length > 0 &&
            data.secretKey && data.secretKey.length > 0) {
          return { success: true, secretId: data.secretId, secretKey: data.secretKey, msg: 'ok' }
        }
        return { success: false, secretId: '', secretKey: '', msg: '凭证为空' }
      }
      return { success: false, secretId: '', secretKey: '', msg: `HTTP错误：${response.responseCode}` }
    } catch (error) {
      console.error('获取COS凭证异常:', JSON.stringify(error))
      return { success: false, secretId: '', secretKey: '', msg: '网络异常或服务器错误' }
    } finally {
      httpRequest.destroy()
    }
  }
}
