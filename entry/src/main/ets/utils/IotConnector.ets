import http from '@ohos.net.http'
import { BusinessError } from '@ohos.base'
import { CommonConstant } from './GetIotToken'

export interface IoTDAStatusResult {
  status: string
  created_time: string
  finished_time: string
}

export interface IoTDAResult {
  message_id: string
  result: IoTDAStatusResult
}

class DeviceMessageBody {
  message_id: string = ''
  name: string = 'appMessage'
  message: string | object = ''
  encoding?: string
}

export class IotConnector {
  static async sendMessage(message: string | object): Promise<IoTDAResult> {
    return new Promise<IoTDAResult>((resolve, reject) => {
      const httpRequest = http.createHttp()

      const body: DeviceMessageBody = new DeviceMessageBody()
      body.message_id = `${Date.now()}`
      body.message = message
      body.encoding = 'none'

      const url: string =
        `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/messages`

      const headerObj: Record<string, string> = {
        'Content-Type': 'application/json',
        'x-auth-token': CommonConstant.token
      }

      if (CommonConstant.INSTANCE_ID) {
        headerObj['Instance-Id'] = CommonConstant.INSTANCE_ID
      }

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headerObj,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING
      }

      httpRequest.request(url, options, (err: BusinessError, data: http.HttpResponse) => {
        httpRequest.destroy()

        if (err) {
          reject(new Error(`网络异常: ${JSON.stringify(err)}`))
          return
        }

        if (data.responseCode !== 201) {
          reject(new Error(`HTTP 错误: ${data.responseCode} - ${data.result}`))
          return
        }

        try {
          const json: IoTDAResult = JSON.parse(data.result as string) as IoTDAResult
          resolve(json)
        } catch (e) {
          reject(new Error(`JSON 解析失败: ${e}`))
        }
      })
    })
  }
}
