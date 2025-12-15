import webSocket from '@ohos.net.webSocket'

export class WSClient {
  private wsUrl: string
  private wsInstance: webSocket.WebSocket | null = null
  private isConnected: boolean = false
  private messageCallback: ((msg: string) => void) | null = null
  private binaryCallback: ((buf: ArrayBuffer) => void) | null = null
  private connectionCallback: ((success: boolean) => void) | null = null

  constructor(wsUrl: string) {
    this.wsUrl = wsUrl
  }

  connect(
    messageCb: (msg: string) => void,
    binaryCb: ((buf: ArrayBuffer) => void) | null = null,
    connectionCb?: (success: boolean) => void
  ) {
    this.messageCallback = messageCb
    this.binaryCallback = binaryCb
    this.connectionCallback = connectionCb || null

    const createAndConnect = () => {
      this.wsInstance = webSocket.createWebSocket()

      this.wsInstance.on('open', () => {
        console.log(`✅ WebSocket 连接成功: ${this.wsUrl}`)
        this.isConnected = true

        // 发送测试账号进行绑定
        this.send("role=app&account=123456")
        console.log('📤 发送绑定码: role=app&account=123456')

        // 通知组件连接成功
        if (this.connectionCallback) {
          this.connectionCallback(true)
        }
      })

      this.wsInstance.on('message', (err, value) => {
        if (err) {
          console.error('❌ WebSocket 接收消息出错:', err)
          return
        }

        if (typeof value === 'string') {
          console.log('📥 收到服务器消息:', value)
          this.messageCallback?.(value)
        } else if (value instanceof ArrayBuffer) {
          console.log('📥 收到二进制数据，长度:', value.byteLength)
          this.binaryCallback?.(value)
        }
      })

      this.wsInstance.on('error', (err) => {
        console.error(`❌ WebSocket 错误: ${err.message}`)
        this.isConnected = false
        if (this.connectionCallback) {
          this.connectionCallback(false)
        }
      })

      this.wsInstance.on('close', (code, reason) => {
        console.log(`🔌 WebSocket 已关闭: code=${code}, reason=${reason}`)
        this.isConnected = false
        if (this.connectionCallback) {
          this.connectionCallback(false)
        }
      })

      // 连接WebSocket
      console.log(`🔗 正在连接 WebSocket: ${this.wsUrl}`)
      this.wsInstance.connect(this.wsUrl, (err) => {
        if (err) {
          console.error(`❌ WebSocket 连接失败: ${err.message}`)
          this.isConnected = false
          if (this.connectionCallback) {
            this.connectionCallback(false)
          }
        }
      })
    }

    createAndConnect()
  }

  send(msg: string) {
    if (this.wsInstance && this.isConnected) {
      this.wsInstance.send(msg, (err) => {
        if (err) {
          console.error('❌ 发送消息失败:', err)
        } else {
          console.log('📤 消息发送成功:', msg)
        }
      })
    } else {
      console.warn('⚠️ WebSocket 未连接，无法发送消息')
    }
  }

  close() {
    if (this.wsInstance) {
      this.wsInstance.close()
      this.isConnected = false
      console.log('🔌 WebSocket 已主动关闭')
    }
  }

  // 获取连接状态
  getIsConnected(): boolean {
    return this.isConnected
  }
}