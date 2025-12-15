// HttpDeleteUtil.ets
import http from '@ohos.net.http'

/**
 * DELETE 请求参数类型
 */
export interface DeleteRequestOptions<TParams = Record<string, string | number>> {
  url: string                 // 请求 URL
  params?: TParams            // 查询参数
  headers?: Record<string, string>
  connectTimeout?: number
  readTimeout?: number
}

/**
 * 通用 DELETE 工具类（ArkTS 安全版）
 */
export class HttpDeleteUtil {
  static request<T>(options: DeleteRequestOptions): Promise<T> {
    return new Promise<T>(async (resolve, reject) => {
      const httpRequest = http.createHttp()
      let requestUrl: string = options.url

      // ✅ 拼接 GET 查询参数（不使用 Object.entries）
      if (options.params !== undefined) {
        const paramKeys: string[] = Object.keys(options.params)
        if (paramKeys.length > 0) {
          let query: string = ''
          for (let i = 0; i < paramKeys.length; i++) {
            const key: string = paramKeys[i]
            const value: string = encodeURIComponent(String((options.params as Record<string, string | number>)[key]))
            query += (i === 0 ? '' : '&') + encodeURIComponent(key) + '=' + value
          }
          requestUrl = requestUrl + '?' + query
        }
      }

      // ✅ 合并请求头（避免直接写字面量）
      const headers: Record<string, string> = {}
      headers['Content-Type'] = 'application/json'
      if (options.headers) {
        const headerKeys: string[] = Object.keys(options.headers)
        for (let i = 0; i < headerKeys.length; i++) {
          const key: string = headerKeys[i]
          const value: string = options.headers[key]
          headers[key] = value
        }
      }

      try {
        const response: http.HttpResponse = await httpRequest.request(requestUrl, {
          method: http.RequestMethod.DELETE,
          header: headers,
          connectTimeout: options.connectTimeout ?? 10000,
          readTimeout: options.readTimeout ?? 10000
        })

        if (response.responseCode === 200) {
          let resultText: string = ''
          if (typeof response.result === 'string') {
            resultText = response.result
          } else {
            resultText = JSON.stringify(response.result)
          }

          try {
            const result: T = JSON.parse(resultText) as T
            resolve(result)
          } catch (parseErr) {
            reject(`数据解析失败: ${parseErr}`)
          }
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