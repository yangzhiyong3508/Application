import webSocket from '@ohos.net.webSocket'

export class DogAppController {
  private wsUrl: string
  private wsInstance: webSocket.WebSocket | null = null
  private isConnected: boolean = false
  private messageCallback: ((msg: string) => void) | null = null
  private binaryCallback: ((buf: ArrayBuffer) => void) | null = null
  private connectionCallback: ((success: boolean) => void) | null = null
  private account: number | string = 0

  constructor(wsUrl: string) {
    this.wsUrl = wsUrl
  }

  connect(
    msgCb: (msg: string) => void,
    binCb: ((buf: ArrayBuffer) => void) | null = null,
    connCb?: (success: boolean) => void,
    account: number | string = 0
  ) {
    this.messageCallback = msgCb
    this.binaryCallback = binCb
    this.connectionCallback = connCb || null
    this.account = account

    this.wsInstance = webSocket.createWebSocket()

    this.wsInstance.on('open', () => {
      console.log(`Order WebSocket connected: ${this.wsUrl}`)
      this.isConnected = true
      const bindMsg = `role=app&account=${this.account}`
      this.send(bindMsg)
      this.connectionCallback?.(true)
    })

    this.wsInstance.on('message', (err, value) => {
      if (err) {
        console.error('Order WebSocket receive failed:', err)
        return
      }
      if (typeof value === 'string') {
        this.messageCallback?.(value)
      } else if (value instanceof ArrayBuffer) {
        this.binaryCallback?.(value)
      }
    })

    this.wsInstance.on('error', (err) => {
      console.error(`Order WebSocket error: ${err.message}`)
      this.isConnected = false
      this.connectionCallback?.(false)
    })

    this.wsInstance.on('close', (code, reason) => {
      console.log(`Order WebSocket closed: code=${code}, reason=${reason}`)
      this.isConnected = false
      this.connectionCallback?.(false)
    })

    this.wsInstance.connect(this.wsUrl, (err) => {
      if (err) {
        console.error(`Order WebSocket connect failed: ${err.message}`)
        this.isConnected = false
        this.connectionCallback?.(false)
      }
    })
  }

  send(msg: string) {
    if (this.wsInstance && this.isConnected) {
      this.wsInstance.send(msg, (err) => {
        if (err) {
          console.error('Text send failed:', err)
        }
      })
    } else {
      console.warn('Order WebSocket not connected, text dropped')
    }
  }

  sendBinary(data: ArrayBuffer) {
    if (this.wsInstance && this.isConnected) {
      this.wsInstance.send(data, (err) => {
        if (err) {
          console.error('Binary send failed:', err)
        }
      })
    } else {
      console.warn('Order WebSocket not connected, binary frame dropped')
    }
  }

  close() {
    if (this.wsInstance) {
      this.wsInstance.close()
      this.isConnected = false
    }
  }

  getIsConnected(): boolean {
    return this.isConnected
  }
}
