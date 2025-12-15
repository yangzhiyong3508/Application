// CozeUtil.ets
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

export interface MessageContent {
  role: string;
  type: string;
  content: string;
  content_type: string;
  reasoning_content: string;
}

export interface CozeMessage {
  event: string;
  message: MessageContent;
  is_finish: boolean;
  index: number;
  conversation_id: string;
  seq_id?: number;
}

export interface CozeRequestParams {
  bot_id: string;
  user: string;
  query: string;
  stream: boolean;
}

/**
 * Coze 聊天接口封装类
 * 负责与扣子API通信，支持流式响应
 */
export class CozeService {
  private readonly apiUrl: string = 'https://api.coze.cn/open_api/v2/chat';
  private readonly authToken: string = 'Bearer sat_LeDY8iu23Ifcb2UwY7LXfZeL0HhoF4NTswQmlooFVJyRJNd7ExEk9gFogjnRPbPl';
  private httpRequest: http.HttpRequest = http.createHttp();
  private buffer: string = '';

  /**
   * 发送请求并接收流式返回消息
   * @param params 请求参数
   * @param onMessage 每次接收到一段流时回调
   */
  async sendMessage(
    params: CozeRequestParams,
    onMessage: (msg: CozeMessage) => void
  ): Promise<void> {
    try {
      const headers: Record<string, string> = {
        'Authorization': this.authToken,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream'
      };

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(params),
        expectDataType: http.HttpDataType.STRING
      };

      this.httpRequest.request(this.apiUrl, requestOptions, (err: BusinessError, data: http.HttpResponse) => {
        if (err) {
          console.error(`Request failed: ${err.code} - ${err.message}`);
          return;
        }

        if (data.responseCode !== http.ResponseCode.OK) {
          console.error(`Response error: ${data.responseCode} - ${data.result}`);
          return;
        }

        this.processStream(data.result as string, onMessage);
      });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`sendMessage error: ${err.code} - ${err.message}`);
    }
  }

  /**
   * 处理扣子流式响应
   */
  private processStream(chunk: string, onMessage: (msg: CozeMessage) => void): void {
    this.buffer += chunk;
    const events = this.buffer.split('\n\n');
    this.buffer = events.pop() || '';

    for (const event of events) {
      if (!event.trim()) continue;
      const lines = event.split('\n');
      let dataLine = '';

      for (const line of lines) {
        if (line.startsWith('data:')) {
          dataLine = line.substring(5).trim();
          break;
        }
      }

      if (!dataLine) continue;

      try {
        const message: CozeMessage = JSON.parse(dataLine);
        if (message.event === 'message' && message.message.type === 'answer') {
          onMessage(message);
        }
      } catch (err) {
        console.error('Failed to parse message:', err, dataLine);
      }
    }
  }
}