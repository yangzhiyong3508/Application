import { WSClient } from './WebSocketClient'

export class AppDogController {
  private commandClient: WSClient | null = null
  private hmc_init: boolean = false

  /**
   * 初始化指令 WebSocket，用于后端下发动作指令
   * @param wsUrl WebSocket 地址
   */
  initCommandClient() {

    this.commandClient = new WSClient(`ws://${AppStorage.get<string>('localhost')}:8080/order`)

    this.commandClient.connect(
      (msg: string) => {
        console.log(`📩 收到消息: ${msg}`); // 打印收到的指令
      }
    )
  }

  /** 发送消息到后端（可选） */
  sendMessage(msg: string) {
    this.commandClient?.send(msg)
  }

  /** 关闭指令 WebSocket */
  closeCommandClient() {
    this.commandClient?.close()
    this.commandClient = null
  }
}