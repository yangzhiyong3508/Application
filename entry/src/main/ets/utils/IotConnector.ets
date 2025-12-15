// IotConnector.ets
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { CommonConstant } from './GetIotToken';

// 内层 result
export interface IoTDAStatusResult {
  status: string;
  created_time: string;
  finished_time: string;
}

// IoTDA 返回格式
export interface IoTDAResult {
  message_id: string;
  result: IoTDAStatusResult;
}

// 请求体格式
interface DeviceMessageBody {
  message: string | object; // 支持 string 或 object
  encoding?: string;        // 可选，默认 none
}

export class IotConnector {

  static async sendMessage(message: string): Promise<IoTDAResult> {
    return new Promise<IoTDAResult>((resolve, reject) => {
      const httpRequest = http.createHttp();

      // 1. 构造 Body：API 文档要求 encoding 只能是 'none' 或 'base64'
      // 如果发送普通文本或 JSON，建议不传 encoding 或传 'none'
      const body: DeviceMessageBody = {
        message: message,
        encoding: "none"
      };

      const url =
        `${CommonConstant.ENDPOINT}/v5/iot/${CommonConstant.project_id}/devices/${CommonConstant.device_id}/messages`;

      // 2. 构造 Header
      const headerObj: Record<string, string> = {
        "Content-Type": "application/json",
        "x-auth-token": CommonConstant.token
      };

      // 【关键】如果是标准版/企业版，必须带 Instance-Id
      if (CommonConstant.INSTANCE_ID) {
        headerObj["Instance-Id"] = CommonConstant.INSTANCE_ID;
      }

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headerObj,
        extraData: JSON.stringify(body), // 确保转为 JSON 字符串
        expectDataType: http.HttpDataType.STRING
      };

      httpRequest.request(url, options, (err: BusinessError, data: http.HttpResponse) => {
        // 记得销毁请求
        httpRequest.destroy();

        if (err) {
          reject(new Error("网络异常：" + JSON.stringify(err)));
          return;
        }

        // 3. 修正状态码判断：文档明确说明成功返回 201 Created
        if (data.responseCode !== 201) {
          reject(new Error(`HTTP 错误: ${data.responseCode} - ${data.result}`));
          return;
        }

        try {
          const json = JSON.parse(data.result as string) as IoTDAResult;
          resolve(json);
        } catch (e) {
          reject(new Error("JSON 解析失败: " + e));
        }
      });
    });
  }
}