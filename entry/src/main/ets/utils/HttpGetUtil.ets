import http from '@ohos.net.http'

/**
 * GET 请求参数接口
 */
export interface GetRequestOptions<TParams = Record<string, string | number>> {
  url: string            // 请求 URL
  params?: TParams       // 查询参数
  headers?: Record<string, string> // 请求头
  connectTimeout?: number
  readTimeout?: number
}

/**
 * 通用 GET 工具类
 */
export class HttpGetUtil {
  /**
   * 发起 GET 请求
   * @param options 请求配置
   * @returns 泛型结果
   */
  static request<T>(options: GetRequestOptions): Promise<T> {
    return new Promise<T>(async (resolve, reject) => {
      const httpRequest = http.createHttp()
      let requestUrl: string = options.url

      // 拼接 GET 参数（替代 Object.entries）
      if (options.params) {
        const keys: string[] = Object.keys(options.params)
        let queryParts: string[] = []
        for (let i = 0; i < keys.length; i++) {
          const key: string = keys[i]
          const value: string = encodeURIComponent(String(options.params[key]))
          queryParts.push(`${encodeURIComponent(key)}=${value}`)
        }
        const query: string = queryParts.join('&')
        if (query.length > 0) {
          requestUrl += '?' + query
        }
      }

      try {
        // ArkTS 需要明确定义 header 类型
        const headers: Record<string, string> = {
          'Content-Type': 'application/json'
        }
        if (options.headers) {
          const extraKeys: string[] = Object.keys(options.headers)
          for (let i = 0; i < extraKeys.length; i++) {
            const key: string = extraKeys[i]
            headers[key] = options.headers[key]
          }
        }

        // 发起请求
        const response = await httpRequest.request(requestUrl, {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: options.connectTimeout ?? 10000,
          readTimeout: options.readTimeout ?? 10000
        })

        // 明确类型转换
        if (response.responseCode === 200) {
          let resultText: string = ''
          if (typeof response.result === 'string') {
            resultText = response.result
          } else {
            resultText = JSON.stringify(response.result)
          }
          const result: T = JSON.parse(resultText) as T
          resolve(result)
        } else {
          reject(`HTTP错误: ${response.responseCode}`)
        }
      } catch (err) {
        reject(`网络请求失败: ${JSON.stringify(err)}`)
      } finally {
        httpRequest.destroy()
      }
    })
  }
}