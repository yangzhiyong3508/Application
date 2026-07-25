import { HttpGetUtil } from './HttpGetUtil'
import { HttpPostUtil } from './HttpPostUtil'
import { HttpDeleteUtil } from './HttpDeleteUtil'

export interface ConversationRecord {
  id: number
  account: number
  answer: string
  reply: string
  create_time: string
}

interface DeleteConversationParams extends Record<string, string | number> {
  account: number
  reply: string
}

export interface ConversationRequest extends Record<string, string | number> {
  account: number
  answer: string
  reply: string
}

export interface ConversationResponse {
  code?: number
  message?: string
  status?: string
  result?: object | string
}

export class ConversationUtil {
  // 增加默认值防止 localhost 为空
  private static getBaseUrl(): string {
    const host = AppStorage.get<string>('localhost') || '127.0.0.1';
    // ⚠️ 注意：真机/模拟器访问电脑本地服务，通常需要用电脑的局域网IP，不能是localhost
    return `http://${host}:8080/api/conversation`
  }

  static async getConversations(account: number): Promise<ConversationRecord[]> {
    const url = `${ConversationUtil.getBaseUrl()}/list/${account}`
    try {
      const result = await HttpGetUtil.request<ConversationRecord[]>({ url })
      return result || []
    } catch (error) {
      console.error('[ConversationUtil] 获取历史对话失败:', JSON.stringify(error))
      return []
    }
  }

  static async addConversation(
    account: number,
    answer: string,
    reply: string
  ): Promise<ConversationResponse> {
    const url = `${ConversationUtil.getBaseUrl()}/add`
    const body: ConversationRequest = { account, answer, reply }

    console.info(`[ConversationUtil] 正在保存对话 -> Account: ${account}, Answer长度: ${answer.length}, Reply长度: ${reply.length}`)

    try {
      // 假设 HttpPostUtil 内部会自动对 body 进行 JSON.stringify
      // 如果你的 HttpPostUtil 比较原始，可能需要传入 extraData: JSON.stringify(body)
      const result = await HttpPostUtil.request<ConversationResponse, ConversationRequest>({
        url,
        body
      })
      console.info('[ConversationUtil] 上传结果:', JSON.stringify(result))
      return result
    } catch (error) {
      console.error('[ConversationUtil] 上传对话失败:', JSON.stringify(error))
      return { message: `上传失败: ${JSON.stringify(error)}`, status: 'fail', code: 500 }
    }
  }

  static async deleteConversation(account: number, reply: string): Promise<ConversationResponse> {
    const url = `${ConversationUtil.getBaseUrl()}/delete`
    // 注意：Delete 请求通常使用 query params，确保你的 HttpDeleteUtil 支持 params 传参
    const params: DeleteConversationParams = { account, reply }

    try {
      const result = await HttpDeleteUtil.request<ConversationResponse>({
        url,
        params
      })
      return result
    } catch (error) {
      console.error('[ConversationUtil] 删除对话失败:', error)
      return { message: `删除失败: ${error}`, status: 'fail' }
    }
  }
}