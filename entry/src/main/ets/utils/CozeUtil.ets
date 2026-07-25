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
  conversation_id?: string;
}

export interface CozeConversationMessage {
  id?: string;
  conversation_id?: string;
  bot_id?: string;
  chat_id?: string;
  role?: string;
  type?: string;
  content?: string;
  content_type?: string;
  created_at?: number;
  updated_at?: number;
}

interface CozeMessageListData {
  messages?: CozeConversationMessage[];
}

interface CozeMessageListResponse {
  code?: number;
  msg?: string;
  message?: string;
  data?: CozeConversationMessage[] | CozeMessageListData;
}

interface CozeMessageListRequest extends Record<string, string | number> {
  order: string;
  limit: number;
}

interface CozeClearContextResponse {
  code?: number;
  msg?: string;
  message?: string;
  data?: object;
}

interface CozeCreateConversationRequest {
  bot_id: string;
}

interface CozeCreateConversationData {
  id?: string;
  conversation_id?: string;
}

interface CozeCreateConversationResponse {
  code?: number;
  msg?: string;
  message?: string;
  data?: CozeCreateConversationData;
}

/**
 * Coze 聊天接口封装类
 * 负责与扣子API通信，支持流式响应
 */
export class CozeService {
  private readonly apiUrl: string = 'https://api.coze.cn/open_api/v2/chat';
  private readonly messageListUrl: string = 'https://api.coze.cn/v1/conversation/message/list';
  private readonly conversationUrl: string = 'https://api.coze.cn/v1/conversations';
  private readonly conversationCreateUrl: string = 'https://api.coze.cn/v1/conversation/create';
  private readonly authToken: string = 'Bearer YOUR_COZE_TOKEN';
  private httpRequest: http.HttpRequest = http.createHttp();
  private buffer: string = '';

  async createConversation(botId: string): Promise<string> {
    if (botId.trim().length === 0) {
      return '';
    }

    const headers: Record<string, string> = {
      'Authorization': this.authToken,
      'Content-Type': 'application/json'
    };
    const body: CozeCreateConversationRequest = {
      bot_id: botId
    };
    const request: http.HttpRequest = http.createHttp();

    try {
      const response: http.HttpResponse = await request.request(this.conversationCreateUrl, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode !== http.ResponseCode.OK) {
        console.error(`[CozeService] createConversation response error: ${response.responseCode} - ${response.result}`);
        return '';
      }

      const resultText: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const result: CozeCreateConversationResponse = JSON.parse(resultText) as CozeCreateConversationResponse;
      if (result.code !== undefined && result.code !== 0) {
        console.error(`[CozeService] createConversation api error: ${result.code} - ${result.msg || result.message || ''}`);
        return '';
      }
      if (result.data && result.data.id && result.data.id.trim().length > 0) {
        return result.data.id.trim();
      }
      if (result.data && result.data.conversation_id && result.data.conversation_id.trim().length > 0) {
        return result.data.conversation_id.trim();
      }
      return '';
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CozeService] createConversation error: ${err.code} - ${err.message}`);
      return '';
    } finally {
      request.destroy();
    }
  }

  async listConversationMessages(conversationId: string, limit: number = 50): Promise<CozeConversationMessage[]> {
    if (conversationId.trim().length === 0) {
      return [];
    }

    const requestUrl: string = `${this.messageListUrl}?conversation_id=${encodeURIComponent(conversationId)}`;
    const headers: Record<string, string> = {
      'Authorization': this.authToken,
      'Content-Type': 'application/json'
    };
    const body: CozeMessageListRequest = {
      order: 'asc',
      limit
    };
    const request: http.HttpRequest = http.createHttp();

    try {
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode !== http.ResponseCode.OK) {
        console.error(`[CozeService] listConversationMessages response error: ${response.responseCode} - ${response.result}`);
        return [];
      }

      const resultText: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const result: CozeMessageListResponse = JSON.parse(resultText) as CozeMessageListResponse;
      if (result.code !== undefined && result.code !== 0) {
        console.error(`[CozeService] listConversationMessages api error: ${result.code} - ${result.msg || result.message || ''}`);
        return [];
      }
      if (Array.isArray(result.data)) {
        return result.data;
      }
      if (result.data !== undefined) {
        const dataObject: CozeMessageListData = result.data as CozeMessageListData;
        return dataObject.messages || [];
      }
      return [];
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CozeService] listConversationMessages error: ${err.code} - ${err.message}`);
      return [];
    } finally {
      request.destroy();
    }
  }

  async clearConversationContext(conversationId: string): Promise<boolean> {
    if (conversationId.trim().length === 0) {
      return true;
    }

    const requestUrl: string = `${this.conversationUrl}/${encodeURIComponent(conversationId)}/clear`;
    const headers: Record<string, string> = {
      'Authorization': this.authToken,
      'Content-Type': 'application/json'
    };
    const request: http.HttpRequest = http.createHttp();

    try {
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: '{}',
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode !== http.ResponseCode.OK) {
        console.error(`[CozeService] clearConversationContext response error: ${response.responseCode} - ${response.result}`);
        return false;
      }

      const resultText: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const result: CozeClearContextResponse = JSON.parse(resultText) as CozeClearContextResponse;
      if (result.code !== undefined && result.code !== 0) {
        console.error(`[CozeService] clearConversationContext api error: ${result.code} - ${result.msg || result.message || ''}`);
        return false;
      }
      return true;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CozeService] clearConversationContext error: ${err.code} - ${err.message}`);
      return false;
    } finally {
      request.destroy();
    }
  }

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
