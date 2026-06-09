import http from '@ohos.net.http'
import { BusinessError } from '@ohos.base'

export class CommonConstant {
  static readonly IAM_ENDPOINT: string = 'https://iam.cn-east-3.myhuaweicloud.com'
  static readonly ENDPOINT: string = 'https://92aad16b61.st1.iotda-app.cn-east-3.myhuaweicloud.com:443'
  static readonly project_id: string = '1b4fbda3bbc2472f9c497507034f79f2'
  static readonly product_id: string = '692bdc8d46c60374e3f8eadc'
  static readonly device_id: string = '692bdc8d46c60374e3f8eadc_myedog'
  static readonly DOMAIN_USERNAME: string = 'GT-Yang_zhiyong'
  static readonly IAM_USERNAME: string = 'GT-Yang_zhiyong'
  static readonly IAM_PASSWORD: string = ''
  static readonly PROJECT_NAME: string = 'cn-east-3'

  static token: string = ''

  static readonly AUTH_TOKEN: string = `${CommonConstant.IAM_ENDPOINT}/v3/auth/tokens`
  static readonly SHOW_SHADOW: string =
    `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/shadow`
  static readonly CONTROL_DEVICE_SYNC: string =
    `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/commands`
  static INSTANCE_ID: string
}

export class AuthService {
  login(): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp()

      httpRequest.request(CommonConstant.AUTH_TOKEN, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: {
          auth: {
            identity: {
              methods: ['password'],
              password: {
                user: {
                  name: CommonConstant.IAM_USERNAME,
                  password: CommonConstant.IAM_PASSWORD,
                  domain: { name: CommonConstant.DOMAIN_USERNAME }
                }
              }
            },
            scope: {
              project: { name: CommonConstant.PROJECT_NAME }
            }
          }
        }
      })
        .then((data: http.HttpResponse) => {
          if (data.responseCode === 201) {
            const header: Record<string, string> = data.header as Record<string, string>
            const token: string = header['x-subject-token'] ?? ''
            CommonConstant.token = token
            resolve(token)
            return
          }

          reject(new Error(`请求失败，状态码: ${data.responseCode}`))
        })
        .catch((err: BusinessError) => {
          reject(new Error(`网络错误: ${err.message}`))
        })
        .finally(() => {
          httpRequest.destroy()
        })
    })
  }
}

export const authService = new AuthService()

export class EmptyCommandParas {
}

export class LegacyServoParas {
  servo_id: number | string = 0
  action: string = ''
}

export class ServoAngleCommandParas {
  servo_id: number = 0
  angle: number = 0
}

export class ControlParams {
  service_id: string = ''
  command_name: string = ''
  paras: object = new EmptyCommandParas()
}

export class IoTController {
  controlDevice(params: ControlParams): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp()

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
        expectDataType: http.HttpDataType.STRING,
        extraData: JSON.stringify(params)
      }

      httpRequest.request(CommonConstant.CONTROL_DEVICE_SYNC, options)
        .then((data: http.HttpResponse) => {
          if (data.responseCode === 200 || data.responseCode === 201) {
            resolve('控制成功')
            return
          }

          reject(new Error(`操作失败，状态码: ${data.responseCode}`))
        })
        .catch((err: BusinessError) => {
          reject(new Error(`网络请求失败: ${err.message}`))
        })
        .finally(() => {
          httpRequest.destroy()
        })
    })
  }

  async sendCommand(commandName: string, paras: object = new EmptyCommandParas(),
    serviceId: string = 'get_data'): Promise<string> {
    const params: ControlParams = new ControlParams()
    params.service_id = serviceId
    params.command_name = commandName
    params.paras = paras
    return await this.controlDevice(params)
  }

  async controlServo(servoId: number, action: string): Promise<string> {
    const paras: LegacyServoParas = new LegacyServoParas()
    paras.servo_id = servoId
    paras.action = action
    return await this.sendCommand('motor_control', paras)
  }
}
