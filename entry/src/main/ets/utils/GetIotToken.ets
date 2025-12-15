//GetIotToken.ets
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

/******************* IoT 常量定义 **********************/
export class CommonConstant {
  static readonly IAM_ENDPOINT = "https://iam.cn-east-3.myhuaweicloud.com"
  static readonly ENDPOINT = "https://92aad16b61.st1.iotda-app.cn-east-3.myhuaweicloud.com:443"
  static readonly project_id = "1b4fbda3bbc2472f9c497507034f79f2"
  static readonly product_id: string = "692bdc8d46c60374e3f8eadc"
  static readonly device_id: string = "692bdc8d46c60374e3f8eadc_myedog"
  static readonly DOMAIN_USERNAME = "GT-Yang_zhiyong"
  static readonly IAM_USERNAME = "GT-Yang_zhiyong"
  static readonly IAM_PASSWORD = "Mimawangle2"

  static token: string = "";

  static readonly AUTH_TOKEN = CommonConstant.IAM_ENDPOINT + "/v3/auth/tokens"

  static readonly SHOW_SHADOW =
    `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/shadow`

  static readonly CONTROL_DEVICE_SYNC =
    `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/commands`
  static INSTANCE_ID: string;
}

/******************* 鉴权服务：获取 Token **********************/
export class AuthService {
  login(): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp();

      httpRequest.request(CommonConstant.AUTH_TOKEN, {
        method: http.RequestMethod.POST,
        header: {
          "Content-Type": "application/json"
        },
        extraData: {
          "auth": {
            "identity": {
              "methods": ["password"],
              "password": {
                "user": {
                  "name": CommonConstant.IAM_USERNAME,
                  "password": CommonConstant.IAM_PASSWORD,
                  "domain": { "name": CommonConstant.DOMAIN_USERNAME }
                }
              }
            },
            "scope": {
              "domain": { "name": CommonConstant.DOMAIN_USERNAME }
            }
          }
        }
      })
        .then((data: http.HttpResponse) => {
          if (data.responseCode === 201) {
            const header = data.header as Record<string, string>;
            const token: string = header["x-subject-token"] ?? "";

            console.info("AuthService", "Token = " + token);
            CommonConstant.token = token;
            resolve(token);
          } else {
            reject("请求失败，状态码：" + data.responseCode);
          }
        })
        .catch((err: BusinessError) => {
          reject("网络错误: " + err.message);
        })
        .finally(() => {
          httpRequest.destroy();
        });
    });
  }
}

// 单例
export const authService = new AuthService();

/******************* 设备控制接口 **********************/
export interface Paras {
  servo_id: number | string;
  action: string;
}

export interface ControlParams {
  service_id: string;
  command_name: string;
  paras: Paras;
}

export class IoTController {

  controlDevice(params: ControlParams): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp();

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          "Content-Type": "application/json",
          "x-auth-token": CommonConstant.token
        },
        expectDataType: http.HttpDataType.STRING,
        extraData: JSON.stringify(params)
      };

      httpRequest.request(CommonConstant.CONTROL_DEVICE_SYNC, options)
        .then((data: http.HttpResponse) => {
          if (data.responseCode === 200 && data.result.toString().includes("command_id")) {
            resolve("控制成功");
          } else {
            reject("操作失败");
          }
        })
        .catch((err: BusinessError) => {
          reject("网络请求失败: " + err.message);
        })
        .finally(() => {
          httpRequest.destroy();
        });
    });
  }

  async controlServo(servoId: number, action: string): Promise<string> {
    const params: ControlParams = {
      service_id: "get_data",
      command_name: "motor_control",
      paras: {
        servo_id: servoId,
        action: action
      }
    };

    return await this.controlDevice(params);
  }
}