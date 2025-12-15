// HttpPostUtil.ts
import http from '@ohos.net.http';

/**
 * POST 请求配置接口
 */
export interface PostRequestOptions<TBody extends object, THeaders extends Record<string, string>> {
  url: string;
  body?: TBody;
  headers?: THeaders;
  connectTimeout?: number;
  readTimeout?: number;
}

/**
 * 通用 POST 工具类
 */
export class HttpPostUtil {
  static request<TResponse, TBody extends object = Record<string, string | number>, THeaders extends Record<string, string> = Record<string, string>>(
    options: PostRequestOptions<TBody, THeaders>
  ): Promise<TResponse> {
    return new Promise<TResponse>(async (resolve, reject) => {
      const httpRequest = http.createHttp();

      // 手动合并请求头
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      if (options.headers) {
        const keys: string[] = Object.keys(options.headers);
        for (let i = 0; i < keys.length; i++) {
          const key: string = keys[i];
          headers[key] = options.headers[key];
        }
      }

      try {
        const response: http.HttpResponse = await httpRequest.request(options.url, {
          method: http.RequestMethod.POST,
          header: headers,
          extraData: options.body ? JSON.stringify(options.body) : '{}',
          connectTimeout: options.connectTimeout ?? 10000,
          readTimeout: options.readTimeout ?? 10000
        });

        if (response.responseCode === 200 || response.responseCode === 201) {
          const resultText: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
          try {
            const result: TResponse = JSON.parse(resultText) as TResponse;
            resolve(result);
          } catch (parseErr) {
            reject(`数据解析失败: ${parseErr}`);
          }
        } else {
          reject(`HTTP错误: ${response.responseCode}`);
        }
      } catch (err) {
        reject(`网络请求失败: ${JSON.stringify(err)}`);
      } finally {
        httpRequest.destroy();
      }
    });
  }
}