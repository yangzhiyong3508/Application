import http from '@ohos.net.http'

/**
 * PUT 请求参数接口
 */
export interface PutRequestOptions<TBody = Record<string, string | number>> {
  url: string
  body?: TBody | string
  headers?: Record<string, string>
  connectTimeout?: number
  readTimeout?: number
}

/**
 * 通用 PUT 工具类（兼容 ArkTS 最新类型系统）
 */
export class HttpPutUtil {
  static request<T>(options: PutRequestOptions): Promise<T> {
    return new Promise<T>(async (resolve, reject) => {
      const httpRequest = http.createHttp()

      try {
        /** 1️⃣ 构建请求头 **/
        const headers: Record<string, string> = {
          'Content-Type': 'application/json'
        }
        if (options.headers) {
          const keys: string[] = Object.keys(options.headers)
          for (let i = 0; i < keys.length; i++) {
            const key: string = keys[i]
            headers[key] = options.headers[key]
          }
        }

        /** 2️⃣ 构建请求体 **/
        let requestBody: string = ''
        if (typeof options.body === 'string') {
          requestBody = options.body
        } else if (options.body) {
          const keys: string[] = Object.keys(options.body)
          const bodyData: Record<string, string | number> = {}
          for (let i = 0; i < keys.length; i++) {
            const key: string = keys[i]
            bodyData[key] = options.body[key]
          }
          requestBody = JSON.stringify(bodyData)
        }

        /** 3️⃣ 明确声明 HttpRequestOptions **/
        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.PUT,
          // ✅ 使用 STRING，因为 HttpDataType 没有 JSON
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: options.connectTimeout ?? 10000,
          readTimeout: options.readTimeout ?? 10000,
          header: headers,
          extraData: requestBody
        }

        /** 4️⃣ 发起请求 **/
        const response = await httpRequest.request(options.url, requestOptions)

        /** 5️⃣ 解析响应 **/
        if (response.responseCode === 200) {
          let resultText: string = ''
          if (typeof response.result === 'string') {
            resultText = response.result
          } else {
            resultText = JSON.stringify(response.result)
          }

          // ✅ ArkTS 下需要显式解析 JSON
          const result: T = JSON.parse(resultText) as T
          resolve(result)
        } else {
          reject(`HTTP错误: ${response.responseCode}`)
        }
      } catch (error) {
        reject(`网络请求失败: ${JSON.stringify(error)}`)
      } finally {
        httpRequest.destroy()
      }
    })
  }
}