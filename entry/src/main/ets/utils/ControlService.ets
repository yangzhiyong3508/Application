import { WSClient } from './WebSocketClient'
import { DogAppController } from './DogAppController'
import { image } from '@kit.ImageKit'

export class ControlService {
  videoWS: WSClient | null = null
  controlWS: DogAppController | null = null

  isVideoConnected: boolean = false
  isControlConnected: boolean = false

  imageData: image.PixelMap | null = null
  currentCommand: string = ""
  commandIndex: number = 0

  private frameManager = new FrameManager()
  private deeplearningIP: string;
  private controlIP: string;

  constructor(
  deeplearningIP: string,
  controlIP: string
  ) {
  this.deeplearningIP = deeplearningIP;
  this.controlIP = controlIP;
}

  /** 初始化两个连接 */
  connectAll(
    onVideoConnected: () => void,
    onControlConnected: () => void,
    onVideoFailed: () => void,
    onControlFailed: () => void,
  ) {
    // 视频连接
    this.videoWS = new WSClient(`ws://${this.deeplearningIP}:8766`)
    this.videoWS.connect(
      () => {},
      (buf: ArrayBuffer): Promise<void> => this.handleFrame(buf),
      (connected) => {
        this.isVideoConnected = connected
        connected ? onVideoConnected() : onVideoFailed()
      }
    )

    // 控制连接
    this.controlWS = new DogAppController(`ws://${this.controlIP}:8080/order`)
    this.controlWS.connect(
      () => {},
      () => {},
      (connected) => {
        this.isControlConnected = connected
        connected ? onControlConnected() : onControlFailed()
      }
    )
  }

  /** 断开两个连接 */
  disconnect() {
    this.videoWS?.close()
    this.controlWS?.close()

    this.isVideoConnected = false
    this.isControlConnected = false
    this.imageData = null

    this.frameManager.release()
  }

  /** 视频帧处理 */
  async handleFrame(buf: ArrayBuffer) {
    const frame = await this.frameManager.processFrame(buf)
    if (frame) {
      this.imageData = frame
    }
  }

  /** 计算动作并发送 */
  sendMotion() {
    const cmd = this.computeCommand()
    if (!cmd) return

    this.controlWS?.send(cmd)
  }

  /** 根据按键选择动作 */
  computeCommand(): string {
    switch (this.commandIndex) {
      case 1: return 'trot,2,0.017,0.012,-15'
      case 2: return 'trot,2,0.017,0.012,0'
      case 3: return 'trot,2,0.017,0.012,15'
      case 4: return 'turn_left,1,0.017,0.012,0'
      case 6: return 'turn_right,1,0.017,0.012,0'
      case 7: return 'trot_back,2,0.017,0.012,15'
      case 8: return 'trot_back,2,0.017,0.012,0'
      case 9: return 'trot_back,2,0.017,0.012,-15'
      default: return ''
    }
  }
}

/** 视频帧管理类 */
class FrameManager {
  private isProcessing: boolean = false
  private currentFrame: image.PixelMap | null = null
  private pending: ArrayBuffer | null = null

  async processFrame(buf: ArrayBuffer): Promise<image.PixelMap | null> {
    if (this.isProcessing) {
      this.pending = buf
      return null
    }
    this.isProcessing = true

    try {
      const src = image.createImageSource(buf)
      const frame = await src.createPixelMap()
      this.currentFrame?.release()
      this.currentFrame = frame
      return frame
    } finally {
      this.isProcessing = false

      if (this.pending) {
        const next = this.pending
        this.pending = null
        setTimeout(() => this.processFrame(next), 0)
      }
    }
  }

  release() {
    this.currentFrame?.release()
    this.currentFrame = null
    this.pending = null
  }
}