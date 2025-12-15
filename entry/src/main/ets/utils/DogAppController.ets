import webSocket from '@ohos.net.webSocket'

/**
 * 机械狗端 WebSocket 控制器
 * 功能：
 * - 连接后端 WebSocket 服务
 * - 以 role=app 身份注册
 * - 接收来自设备或服务器的消息
 * - 可主动发送指令或状态
 */
export class DogAppController {
  private wsUrl: string
  private wsInstance: webSocket.WebSocket | null = null
  private isConnected: boolean = false
  private messageCallback: ((msg: string) => void) | null = null
  private binaryCallback: ((buf: ArrayBuffer) => void) | null = null
  private connectionCallback: ((success: boolean) => void) | null = null

  // 新增 account 属性
  private account: number | string = 0;

  constructor(wsUrl: string) {
    this.wsUrl = wsUrl
  }

  /** 建立连接 (增加 account 参数) */
  connect(
    msgCb: (msg: string) => void,
    binCb: ((buf: ArrayBuffer) => void) | null = null,
    connCb?: (success: boolean) => void,
    account: number | string = 0 // 默认为 0
  ) {
    this.messageCallback = msgCb
    this.binaryCallback = binCb
    this.connectionCallback = connCb || null
    this.account = account // 保存传入的账号

    const createAndConnect = () => {
      this.wsInstance = webSocket.createWebSocket()

      // 打开事件
      this.wsInstance.on('open', () => {
        console.log(`✅ WebSocket 已连接: ${this.wsUrl}`)
        this.isConnected = true

        // 动态发送角色绑定信息，使用传入的 account
        const bindMsg = `role=app&account=${this.account}`
        this.send(bindMsg)
        console.log(`📤 已发送绑定角色: ${bindMsg}`)

        this.connectionCallback?.(true)
      })

      // 消息事件
      this.wsInstance.on('message', (err, value) => {
        if (err) {
          console.error('❌ 接收消息出错:', err)
          return
        }
        if (typeof value === 'string') {
          console.log('📥 收到服务器消息:', value)
          this.messageCallback?.(value)
        } else if (value instanceof ArrayBuffer) {
          console.log(`📥 收到二进制数据（${value.byteLength}字节）`)
          this.binaryCallback?.(value)
        }
      })

      // 错误事件
      this.wsInstance.on('error', (err) => {
        console.error(`❌ WebSocket 错误: ${err.message}`)
        this.isConnected = false
        this.connectionCallback?.(false)
      })

      // 关闭事件
      this.wsInstance.on('close', (code, reason) => {
        console.log(`🔌 WebSocket 已关闭: code=${code}, reason=${reason}`)
        this.isConnected = false
        this.connectionCallback?.(false)
      })

      // 执行连接
      console.log(`🔗 正在连接 WebSocket: ${this.wsUrl}`)
      this.wsInstance.connect(this.wsUrl, (err) => {
        if (err) {
          console.error(`❌ WebSocket 连接失败: ${err.message}`)
          this.isConnected = false
          this.connectionCallback?.(false)
        }
      })
    }

    createAndConnect()
  }

  /** 发送文本消息 */
  send(msg: string) {
    if (this.wsInstance && this.isConnected) {
      this.wsInstance.send(msg, (err) => {
        if (err) {
          console.error('❌ 发送失败:', err)
        } else {
          console.log(`📤 已发送: ${msg}`)
        }
      })
    } else {
      console.warn('⚠️ WebSocket 未连接，无法发送消息')
    }
  }

  /** 主动断开连接 */
  close() {
    if (this.wsInstance) {
      this.wsInstance.close()
      this.isConnected = false
      console.log('🔌 WebSocket 已主动关闭')
    }
  }

  /** 获取连接状态 */
  getIsConnected(): boolean {
    return this.isConnected
  }
}