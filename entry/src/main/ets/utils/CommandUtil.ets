import { HttpGetUtil } from './HttpGetUtil'
import { HttpPostUtil } from './HttpPostUtil'
import { HttpPutUtil } from './HttpPutUtil'
import { HttpDeleteUtil } from './HttpDeleteUtil'

/**
 * 命令数据模型
 */
export interface Command {
  id?: number
  account: number
  content: string
  message: string
}

/**
 * 查询命令返回类型
 */
export interface CommandResponse {
  success: boolean
  msg: string
  data?: Command[]
}

/**
 * 添加/修改/删除命令返回类型
 */
export interface CommandUpdateResponse {
  success: boolean
  msg: string
}

/**
 * 命令工具类
 * 封装后端命令接口的 CRUD 操作
 */
export class CommandUtil {
  /** 获取命令列表（对应后端 @GetMapping("/{account}")） */
  static async getCommandsByAccount(account: number): Promise<CommandResponse> {
    const url: string = `http://${AppStorage.get<string>('localhost')}:8080/api/commands/${account}`
    try {
      const result = await HttpGetUtil.request<CommandResponse>({
        url: url,
        headers: { 'Content-Type': 'application/json' }
      })
      return result
    } catch (error) {
      console.error('命令查询失败:', JSON.stringify(error))
      return { success: false, msg: '网络错误', data: [] }
    }
  }

  /** 添加命令（对应后端 @PostMapping） */
  static async addCommand(command: Command): Promise<CommandUpdateResponse> {
    const body: Record<string, string | number> = {
      "account": command.account,
      "content": command.content,
      "message": command.message
    }
    const url: string = `http://${AppStorage.get<string>('localhost')}:8080/api/commands`
    try {
      const res = await HttpPostUtil.request<CommandUpdateResponse>({
        url: url,
        body: body,
        headers: { 'Content-Type': 'application/json' }
      })
      return res
    } catch (err) {
      console.error('添加命令失败:', JSON.stringify(err))
      return { success: false, msg: '服务器异常' }
    }
  }

  /** 修改命令（对应后端 @PutMapping("/update")） */
  static async updateCommand(command: Command): Promise<CommandUpdateResponse> {
    const body: Record<string, string | number> = {
      "account": command.account,
      "content": command.content,
      "message": command.message
    }
    const url: string = `http://${AppStorage.get<string>('localhost')}:8080/api/commands/update`
    try {
      const res = await HttpPutUtil.request<CommandUpdateResponse>({
        url: url,
        body: body,
        headers: { 'Content-Type': 'application/json' }
      })
      return res
    } catch (err) {
      console.error('修改命令失败:', JSON.stringify(err))
      return { success: false, msg: '服务器异常' }
    }
  }

  /** 删除命令（对应后端 @DeleteMapping） */
  static async deleteCommand(account: number, content: string): Promise<CommandUpdateResponse> {
    const url: string = `http://${AppStorage.get<string>('localhost')}:8080/api/commands/delete`
    try {
      const res = await HttpDeleteUtil.request<CommandUpdateResponse>({
        url: url,
        params: { "account": account, "content": content },
        headers: { 'Content-Type': 'application/json' }
      })
      return res
    } catch (err) {
      console.error('删除命令失败:', JSON.stringify(err))
      return { success: false, msg: '服务器异常' }
    }
  }
}