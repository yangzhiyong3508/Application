import { LottieView } from "../utils/LottieView";
import { image } from '@kit.ImageKit'
import { WSClient } from '../utils/WebSocketClient'
import { font, promptAction } from "@kit.ArkUI"
import { DogAppController } from '../utils/DogAppController'
import http from '@ohos.net.http'
import { IotConnector } from '../utils/IotConnector'
import { authService, CommonConstant } from '../utils/GetIotToken'
// 引入 HttpPostUtil
import { HttpPostUtil } from '../utils/HttpPostUtil'

// ======================== 常量定义 ========================
interface VoiceOption {
  name: string;
  id: string;
}

// 发音人音色对应表 (使用字符串防止精度丢失)
const VOICE_OPTIONS: VoiceOption[] = [
  { name: '可爱女生', id: '7568423452617605174' },
  { name: '调皮公主', id: '7568423452617621558' },
  { name: '爽朗少年', id: '7568423452617637942' },
  { name: '天才同桌', id: '7568423452617654326' },
  { name: '知性灿灿', id: '7568423452617670710' }
]

// Define explicit types for the Tracker API
interface TrackerResponse {
  message: string;
}

interface TrackerBody {
  enable: number;
}

// 新增：后端用户信息返回结构
interface UserVoiceSettings {
  voiceId?: string;
  speedRatio?: number;
  vol?: number;
  wakeWord?: string;
}

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

// ============================================================
// 机械狗九宫格控制面板组件
// ============================================================
@Component
export struct DogControlPanel {
  @Link command_index: number
  @Link current_command: string
  @Link control_open: boolean

  // 回调函数定义
  onPressStart: (cmd: string) => void = () => {}
  onPressEnd: (cmd: string) => void = () => {}

  private send(cmd: string, type: 'start' | 'end') {
    if (type === 'start') {
      if (this.onPressStart) {
        this.onPressStart(cmd)
      }
    } else {
      if (this.onPressEnd) {
        this.onPressEnd(cmd)
      }
    }
  }

  build() {
    Column() {
      Image($r('app.media.down'))
        .width(20).height(20)
        .margin({ bottom: 6 })
        .fillColor('#888')
        .alignSelf(ItemAlign.Center)
        .onClick(() => this.control_open = false)

      Text('机械狗控制面板')
        .fontFamily('alibaba').fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin(20).fontColor('#000')

      // ================= 九宫格控制区 =================
      Column() {
        // 第一行
        Row() {
          // 左上
          Image($r("app.media.arrow_uptwo"))
            .width(50).height(50).margin(5).rotate({ angle: -45 }).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot', 'start')
              if (e.type === TouchType.Up) this.send('trot', 'end')
            })
          // 上
          Image($r("app.media.turn_up"))
            .width(50).height(50).margin(5).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot', 'start')
              if (e.type === TouchType.Up) this.send('trot', 'end')
            })
          // 右上
          Image($r("app.media.arrow_uptwo"))
            .width(50).height(50).margin(5).rotate({ angle: 45 }).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot', 'start')
              if (e.type === TouchType.Up) this.send('trot', 'end')
            })
        }
        .justifyContent(FlexAlign.SpaceBetween).width('90%')

        // 第二行
        Row() {
          // 左
          Image($r("app.media.turn_left"))
            .width(50).height(50).margin(5).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('turn_left', 'start')
              if (e.type === TouchType.Up) this.send('turn_left', 'end')
            })
          // 中间
          Image($r("app.media.round"))
            .width(50).height(50).margin(5).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('stop', 'start')
              if (e.type === TouchType.Up) this.send('stop', 'end')
            })
          // 右
          Image($r("app.media.turn_right"))
            .width(50).height(50).margin(5).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('turn_right', 'start')
              if (e.type === TouchType.Up) this.send('turn_right', 'end')
            })
        }
        .justifyContent(FlexAlign.SpaceBetween).width('90%').margin({ top: 8 })

        // 第三行
        Row() {
          // 左下
          Image($r("app.media.arrow_downtwo"))
            .width(50).height(50).margin(5).rotate({ angle: 45 }).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot_back', 'start')
              if (e.type === TouchType.Up) this.send('trot_back', 'end')
            })
          // 下
          Image($r("app.media.turn_down"))
            .width(50).height(50).margin(5).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot_back', 'start')
              if (e.type === TouchType.Up) this.send('trot_back', 'end')
            })
          // 右下
          Image($r("app.media.arrow_downtwo"))
            .width(50).height(50).margin(5).rotate({ angle: -45 }).fillColor('#FFF')
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) this.send('trot_back', 'start')
              if (e.type === TouchType.Up) this.send('trot_back', 'end')
            })
        }
        .justifyContent(FlexAlign.SpaceBetween).width('90%').margin({ top: 8 })

        // 当前指令显示
        Column() {
          Text('当前执行的指令：').fontSize(20).fontFamily('alibaba')
          Text(this.current_command).fontSize(20).fontFamily('alibaba')
        }
      }
      .width('70%').padding(10).borderRadius(16)
    }
    .width('100%').height('93%').alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start).borderRadius({ topLeft: 20, topRight: 20 })
    .backgroundBlurStyle(BlurStyle.Thick).backgroundColor('#22222280')
  }
}

// ======================== 全局状态 ========================
// ⚠️ 注意：这里移除了 AppStorage.setOrCreate('account', 123456) 这种硬编码
// 账号信息应由 Login 页面设置，这里只设置一些非用户敏感的默认配置
if (!AppStorage.has('isLogin')) AppStorage.setOrCreate('isLogin', false)
if (!AppStorage.has('localhost')) AppStorage.setOrCreate('localhost', '118.195.133.25')
if (!AppStorage.has('deeplearning_ip')) AppStorage.setOrCreate('deeplearning_ip', '192.168.1.104')
if (!AppStorage.has('current_command')) AppStorage.setOrCreate('current_command', '')

// 默认语音参数 (如果没有登录，使用默认值)
if (!AppStorage.has('voiceId')) AppStorage.setOrCreate('voiceId', '7568423452617605174')
if (!AppStorage.has('speedRatio')) AppStorage.setOrCreate('speedRatio', 1.0)
if (!AppStorage.has('vol')) AppStorage.setOrCreate('vol', 50)
if (!AppStorage.has('wakeWord')) AppStorage.setOrCreate('wakeWord', '小狗小狗')

// ======================== 帧处理类 ========================
class FrameManager {
  private currentFrame: image.PixelMap | null = null
  private isProcessing: boolean = false
  private pendingBuffer: ArrayBuffer | null = null

  async processFrame(buffer: ArrayBuffer): Promise<image.PixelMap | null> {
    if (this.isProcessing) {
      this.pendingBuffer = buffer
      return null
    }
    this.isProcessing = true
    try {
      const imageSource = image.createImageSource(buffer)
      const pixelMap = await imageSource.createPixelMap()
      if (this.currentFrame) this.currentFrame.release()
      this.currentFrame = pixelMap
      return pixelMap
    } catch (err) {
      console.error('处理帧失败:', err)
      return null
    } finally {
      this.isProcessing = false
      if (this.pendingBuffer) {
        const next = this.pendingBuffer
        this.pendingBuffer = null
        setTimeout(() => this.processFrame(next), 0)
      }
    }
  }

  release() {
    if (this.currentFrame) this.currentFrame.release()
    this.currentFrame = null
    this.pendingBuffer = null
  }
}

// ======================== 主组件 ========================
@Builder
export function ControlBuilder() {
  Control()
}

@Component
export struct Control {
  @StorageLink('localhost') localhost: string = '192.168.1.107'
  @StorageLink('deeplearning_ip') deeplearning_ip: string = '192.168.1.104'

  // 🔥 核心：通过 @StorageLink 自动绑定全局 account，这通常是在 Login 页设置的
  @StorageLink('account') account: number = 0

  @StorageLink('current_command') current_command: string = ''
  @StorageLink('isTrace') isTrace: boolean = false

  // 语音相关状态 (双向绑定)
  @StorageLink('voiceId') voiceId: string = '7568423452617605174'
  @StorageLink('speedRatio') speedRatio: number = 1.0
  @StorageLink('vol') vol: number = 50
  @StorageLink('wakeWord') wakeWord: string = '小狗小狗'

  @State isConnected: boolean = false
  @State isConnecting: boolean = false
  @State imageData: image.PixelMap | null = null

  @State command_index: number = 0
  @State control_open: boolean = false
  @State showVoicePanel: boolean = false
  @State iotTokenReady: boolean = false

  // 临时编辑状态
  @State tempWakeWord: string = ''

  private wsClient: WSClient | null = null
  private frameManager: FrameManager = new FrameManager()
  // 控制器 URL
  private dogAppController = new DogAppController(`ws://${this.localhost}:8080/order`)

  private pressTimer: number = -1
  private isLongPress: boolean = false

  async aboutToAppear() {
    this.showToast("正在初始化...")

    // 初始化临时变量 (用于 UI 显示，防止直接修改全局变量导致未保存就生效)
    this.tempWakeWord = this.wakeWord

    // 🔥 1. 尝试从后端获取用户配置 (依赖 this.account)
    await this.fetchUserSettings()

    // 2. 连接 IoT 平台
    try {
      this.showToast("正在连接 IoT 平台...")
      const token = await authService.login()
      CommonConstant.token = token
      this.iotTokenReady = true
      console.info("IoT 平台 Token 获取成功:", token)
      this.showToast("IoT 平台连接成功")
    } catch (err) {
      this.iotTokenReady = false
      console.error("IoT Token 获取失败:", err)
      this.showToast("IoT 平台连接失败，请检查网络")
    }
  }

  // ============================================================
  // 🔥 新增：从后端拉取当前账号的语音配置
  // ============================================================
  async fetchUserSettings() {
    // 检查是否有登录账号
    if (!this.account || this.account === 0) {
      console.warn('未登录或账号为空，使用默认语音配置')
      return
    }

    try {
      const httpRequest = http.createHttp()
      // 调用后端的 /info/{account} 接口
      const url = `http://${this.localhost}:8080/api/accounts/info/${this.account}`

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      })

      if (response.responseCode === 200) {
        // 解析数据
        const resText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
        // 直接解析为 Account 对象
        const userData = JSON.parse(resText) as UserVoiceSettings

        if (userData) {
          console.info('成功获取用户配置:', JSON.stringify(userData))

          // 更新全局 AppStorage
          if (userData.voiceId) AppStorage.setOrCreate('voiceId', userData.voiceId)
          if (userData.speedRatio !== undefined) AppStorage.setOrCreate('speedRatio', Number(userData.speedRatio))
          if (userData.vol !== undefined) AppStorage.setOrCreate('vol', Number(userData.vol))
          if (userData.wakeWord) {
            AppStorage.setOrCreate('wakeWord', userData.wakeWord)
            this.tempWakeWord = userData.wakeWord // 同步更新 UI
          }
        }
      } else {
        console.error('获取配置失败, HTTP Code:', response.responseCode)
      }
    } catch (err) {
      console.error('获取用户配置异常:', JSON.stringify(err))
    }
  }

  aboutToDisappear() {
    this.disconnectAll()
    if (this.pressTimer !== -1) clearTimeout(this.pressTimer)
  }

  // ======================== 核心逻辑：按键开始 ========================
  onPressStart(cmd: string): void {
    if (this.pressTimer !== -1) {
      clearTimeout(this.pressTimer)
      this.pressTimer = -1
    }

    this.isLongPress = false

    // 500ms 判定长按
    this.pressTimer = setTimeout((): void => {
      this.isLongPress = true
      this.current_command = cmd
      this.sendCommand(cmd)
    }, 500)
  }

  // ======================== 核心逻辑：按键松开 ========================
  onPressEnd(cmd: string): void {
    if (this.pressTimer !== -1) {
      clearTimeout(this.pressTimer)
      this.pressTimer = -1
    }

    // 1) 长按松开：必发 stop
    if (this.isLongPress) {
      this.sendCommand('stop')
      this.current_command = ''
      this.isLongPress = false
      return
    }

    // 2) 短按逻辑（toggle）
    // stop 按钮：直接 stop
    if (cmd === 'stop') {
      this.sendCommand('stop')
      this.current_command = ''
      return
    }

    // 再次短按同一按钮：stop
    if (this.current_command === cmd) {
      this.sendCommand('stop')
      this.current_command = ''
      return
    }

    // 切换到新动作：先 stop 旧的，再发新的
    if (this.current_command && this.current_command.length > 0) {
      this.sendCommand('stop')
    }
    this.sendCommand(cmd)
    this.current_command = cmd
  }

  // =============================================
  //   发送机械狗动作 (IoT)
  // =============================================
  async sendCommand(cmd: string) {
    if (!this.iotTokenReady || !CommonConstant.token) {
      console.warn("IoT 服务未连接，无法发送指令")
      return
    }

    try {
      await IotConnector.sendMessage(cmd)
    } catch (err) {
      console.error("动作发送失败:", JSON.stringify(err))
    }
  }

  // =============================================
  //   更新追踪状态 (HTTP POST)
  // =============================================
  async updateTrackerStatus(enable: boolean) {
    const url = `http://${this.localhost}:8080/tracker/status`;

    // Explicitly type the body object
    const body: TrackerBody = { enable: enable ? 1 : 0 };

    try {
      // Use named interfaces <TrackerResponse, TrackerBody> instead of inline types
      const response = await HttpPostUtil.request<TrackerResponse, TrackerBody>({
        url: url,
        body: body
      });

      console.info(`Tracker status updated: ${JSON.stringify(response)}`);
    } catch (err) {
      console.error(`Failed to update tracker status: ${JSON.stringify(err)}`);
      this.showToast('Failed to update tracker status')
    }
  }

  // ======================== 网络连接 ========================
  onConnectClick() {
    if (this.isConnected || this.isConnecting) {
      this.showToast(this.isConnected ? '已连接服务器' : '正在连接中...')
      return
    }

    this.showToast('正在连接视频与控制服务器...')
    this.isConnecting = true

    this.frameManager = new FrameManager()
    this.wsClient = new WSClient(`ws://${this.deeplearning_ip}:8766`)
    this.wsClient.connect(
      (msg: string) => console.log('视频消息:', msg),
      (buf: ArrayBuffer): Promise<void> => this.handleVideoFrame(buf),
      (connected: boolean) => {
        if (connected) this.checkAllConnected()
        else {
          this.isConnecting = false
          this.showToast('视频服务器连接失败')
        }
      }
    )

    // 连接控制 WebSocket
    // 🔥 注意：这里假设 DogAppController 已经修改为支持传递 account
    // 如果没有修改 DogAppController，请确保它内部能获取到 AppStorage 中的 account
    this.dogAppController.connect(
      (msg: string) => console.log('控制消息:', msg),
      () => { },
      (connected: boolean) => {
        if (connected) this.checkAllConnected()
        else {
          this.isConnecting = false
          this.showToast('控制服务器连接失败')
        }
      },
      // 传递当前登录的账号
      this.account
    )
  }

  private checkAllConnected() {
    const video = this.wsClient?.getIsConnected?.() ?? false
    const control = this.dogAppController.getIsConnected()
    if (video && control) {
      this.isConnected = true
      this.isConnecting = false
      this.showToast('所有服务器连接成功')
    }
  }

  disconnectAll() {
    this.wsClient?.close()
    this.dogAppController.close?.()
    this.isConnected = false
    this.isConnecting = false
    this.imageData = null
    this.frameManager.release()
  }

  async handleVideoFrame(buf: ArrayBuffer) {
    const frame = await this.frameManager.processFrame(buf)
    if (frame) this.imageData = frame
  }

  showToast(msg: string) {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  // ======================== 语音设置 API (适配新后端) ========================

  // 更新语音参数 (VoiceID, Speed, Volume)
  async updateVoiceSetting() {
    if (!this.account || this.account === 0) {
      this.showToast('请先登录后再保存设置')
      return
    }

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${this.localhost}:8080/api/accounts/updateVoice`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          // 🔥 使用 this.account 全局变量
          extraData: JSON.stringify({
            account: this.account,
            voiceId: this.voiceId,
            speedRatio: this.speedRatio,
            vol: this.vol
          })
        }
      )
      if (response.responseCode === 200) {
        promptAction.showToast({ message: '语音参数已应用' })
      } else {
        promptAction.showToast({ message: '参数应用失败' })
      }
    } catch (err) {
      console.error('语音参数更新异常:', err)
      promptAction.showToast({ message: '网络请求错误' })
    }
  }

  // 更新唤醒词
  async saveWakeWord() {
    if (!this.account || this.account === 0) {
      this.showToast('请先登录后再保存设置')
      return
    }
    if (!this.tempWakeWord || this.tempWakeWord.trim().length === 0) {
      promptAction.showToast({ message: '请输入唤醒词' })
      return
    }
    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${this.localhost}:8080/api/accounts/updateWakeWord`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          // 🔥 使用 this.account 全局变量
          extraData: JSON.stringify({
            account: this.account,
            wakeWord: this.tempWakeWord.trim()
          })
        }
      )
      if (response.responseCode === 200) {
        // 更新全局状态
        AppStorage.setOrCreate('wakeWord', this.tempWakeWord.trim())
        promptAction.showToast({ message: '唤醒词修改成功' })
      } else {
        promptAction.showToast({ message: '保存失败，请重试' })
      }
    } catch (err) {
      console.error('保存唤醒词异常:', err)
      promptAction.showToast({ message: '网络请求错误' })
    }
  }

  // ======================== UI 构建 ========================
  build() {
    Stack() {
      Column() {
        // 1. 视频显示区
        Column() {
          Row(){
            Text('视频监控')
              .fontSize(22)
              .fontColor('#333')
              .fontFamily('alibaba')
              .fontWeight(FontWeight.Bold)
              .padding({ left: 16, top: 12, bottom: 8 })
              .width('100%')
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          if (this.imageData) {
            Image(this.imageData).width('100%').height('100%').objectFit(ImageFit.Contain)
          } else {
            Column() {
              LottieView({ name: 'loading' }).width(150).height(150)
              Text(this.isConnecting ? '连接视频服务中...' : '等待连接')
                .fontSize(16).fontFamily('alibaba').fontColor('#999').margin({ top: 10 })
            }.justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).height('80%')
          }
        }
        .width('100%')
        .height('40%')
        .backgroundColor('#FFF')

        // 2. 主控制按钮区 (占满剩余 60% 高度)
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            // 使用 flex 布局让按钮组填满空间
            Column() {
              // 第一行按钮
              Row({ space: 15 }) {
                Button(this.isConnected ? '断开连接' : '一键连接')
                  .type(ButtonType.Normal)
                  .layoutWeight(1) // 宽度平分
                  .height('100%') // 填满行高
                  .fontColor(Color.White)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(this.isConnected ? '#FF453A' : '#30B0C7')
                  .shadow({ radius: 8, color: '#00000020', offsetY: 4 })
                  .borderRadius(20)
                  .onClick(() => {
                    if (this.isConnected) {
                      this.disconnectAll()
                      this.showToast('已断开所有连接')
                    } else this.onConnectClick()
                  })

                Button(this.isTrace ? '停止追踪' : '智能追踪')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height('100%')
                  .fontColor(Color.White)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(this.isTrace ? '#FF9F0A' : '#32D74B')
                  .shadow({ radius: 8, color: '#00000020', offsetY: 4 })
                  .borderRadius(20)
                  .onClick(async () => {
                    // 1. 切换状态
                    this.isTrace = !this.isTrace
                    AppStorage.setOrCreate('isTrace', this.isTrace)

                    // 2. 发送 HTTP 请求通知后端
                    await this.updateTrackerStatus(this.isTrace)

                    this.showToast(this.isTrace ? '自动追踪已开启' : '自动追踪已关闭')
                  })
              }
              .width('100%')
              .layoutWeight(1) // 高度平分
              .margin({ bottom: 15 })

              // 第二行按钮
              Row({ space: 15 }) {
                Button(this.control_open ? '隐藏遥控' : '运动遥控')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height('100%')
                  .fontColor(Color.White)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(this.control_open ? '#636366' : '#0A84FF')
                  .shadow({ radius: 8, color: '#00000020', offsetY: 4 })
                  .borderRadius(20)
                  .onClick(() => this.control_open = !this.control_open)

                Button(this.showVoicePanel ? '隐藏设置' : '语音配置')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height('100%')
                  .fontColor(Color.White)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(this.showVoicePanel ? '#636366' : '#BF5AF2')
                  .shadow({ radius: 8, color: '#00000020', offsetY: 4 })
                  .borderRadius(20)
                  .onClick(() => {
                    this.showVoicePanel = !this.showVoicePanel
                    this.tempWakeWord = this.wakeWord // 重置输入框
                  })
              }
              .width('100%')
              .layoutWeight(1) // 高度平分
            }
            .width('100%')
            .height('100%')
            .padding(20) // 外边距
            .justifyContent(FlexAlign.SpaceEvenly)
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#F2F2F7')

          // ================= 运动控制面板 (保持原样) =================
          if (this.control_open) {
            DogControlPanel({
              command_index: this.command_index,
              current_command: this.current_command,
              control_open: this.control_open,
              onPressStart: (cmd: string): void => this.onPressStart(cmd),
              onPressEnd: (cmd: string): void => this.onPressEnd(cmd)
            })
          }

          // ================= 新版语音配置面板 =================
          if (this.showVoicePanel) {
            Column() {
              // 1. 面板把手
              Image($r('app.media.down'))
                .width(24)
                .height(24)
                .margin({ top: 12, bottom: 4 })
                .fillColor('#C7C7CC')
                .onClick(() => this.showVoicePanel = false)

              Text('语音交互配置')
                .fontFamily('alibaba')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#000')
                .margin({ bottom: 10 })

              // 2. 可滚动区域，使用 layoutWeight(1) 占满剩余空间
              Scroll() {
                Column() {
                  // --- 唤醒词设置 ---
                  Column() {
                    Text('唤醒设置').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({bottom: 10})
                    Row({ space: 10 }) {
                      TextInput({ text: this.tempWakeWord, placeholder: '输入唤醒词（如：小狗小狗）' })
                        .layoutWeight(1)
                        .height(40)
                        .borderRadius(8)
                        .backgroundColor('#F2F2F7')
                        .onChange((val) => this.tempWakeWord = val)

                      Button('保存唤醒词')
                        .height(40)
                        .fontSize(14)
                        .backgroundColor('#30B0C7')
                        .onClick(() => this.saveWakeWord())
                    }
                  }
                  .padding(15)
                  .backgroundColor('#FFF')
                  .borderRadius(12)
                  .width('90%')
                  .margin({ bottom: 15 })

                  // --- 发音人选择 ---
                  Column() {
                    Text('发音人音色').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({bottom: 10})
                    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                      ForEach(VOICE_OPTIONS, (item: VoiceOption) => {
                        Button(item.name)
                          .fontSize(14)
                          .fontColor(this.voiceId === item.id ? '#FFF' : '#333')
                          .backgroundColor(this.voiceId === item.id ? '#BF5AF2' : '#F2F2F7')
                          .height(32)
                          .margin({ right: 10, bottom: 10 })
                          .onClick(() => this.voiceId = item.id)
                      })
                    }
                  }
                  .padding(15)
                  .backgroundColor('#FFF')
                  .borderRadius(12)
                  .width('90%')
                  .margin({ bottom: 15 })

                  // --- 参数微调 ---
                  Column() {
                    Text('参数微调').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({bottom: 10})

                    // 语速 (0.2 - 3.0)
                    Row() {
                      Image($r("app.media.ic_public_speed")).width(20).height(20).fillColor('#666').margin({right: 10})
                      Text('语速').fontSize(15).width(40)

                      // 语速滑块: min 0.2, max 3.0, step 0.1
                      Slider({ value: this.speedRatio, min: 0.2, max: 3.0, step: 0.1 })
                        .layoutWeight(1)
                        .blockColor('#BF5AF2')
                        .trackColor('#E5E5EA')
                        .selectedColor('#BF5AF2')
                        .showSteps(false)
                        .onChange((v) => this.speedRatio = v) // 不需要取整，保留小数

                      // 显示保留1位小数
                      Text(`${this.speedRatio.toFixed(1)}`).fontSize(15).fontColor('#BF5AF2').width(30).textAlign(TextAlign.End)
                    }.width('100%').margin({bottom: 15})

                    // 音量 (0 - 100)
                    Row() {
                      Image($r("app.media.ic_public_sound")).width(20).height(20).fillColor('#666').margin({right: 10})
                      Text('音量').fontSize(15).width(40)

                      // 音量滑块: min 0, max 100
                      Slider({ value: this.vol, min: 0, max: 100, step: 1 })
                        .layoutWeight(1)
                        .blockColor('#0A84FF')
                        .trackColor('#E5E5EA')
                        .selectedColor('#0A84FF')
                        .showSteps(false)
                        .onChange((v) => this.vol = Math.round(v))

                      Text(`${this.vol}`).fontSize(15).fontColor('#0A84FF').width(30).textAlign(TextAlign.End)
                    }.width('100%')
                  }
                  .padding(15)
                  .backgroundColor('#FFF')
                  .borderRadius(12)
                  .width('90%')
                  .margin({ bottom: 20 })

                  // --- 应用按钮 ---
                  Button('应用音频参数')
                    .width('90%')
                    .height(50)
                    .backgroundColor('#0A84FF')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .onClick(() => this.updateVoiceSetting())
                    .margin({ bottom: 40 }) // 增加底部边距，防止贴底
                }
                .width('100%')
                // 确保内容底部有足够的内边距，方便滚动查看最底部的按钮
                .padding({ bottom: 20 })
              }
              .layoutWeight(1) // 关键：让 Scroll 占据所有剩余高度
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .height('85%') // 面板高度
            .borderRadius({ topLeft: 24, topRight: 24 })
            .backgroundColor('#F9F9F9') // 浅灰背景
            .shadow({ radius: 30, color: '#00000040', offsetY: -5 })
            .transition(TransitionEffect.move(TransitionEdge.BOTTOM))
            .animation({ duration: 300, curve: Curve.EaseOut })
          }
        }
        .width('100%')
        .height('60%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F9FB')
      .onAppear(() => {
        // 注册字体
        font.registerFont({
          familyName: 'alibaba',
          familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
        })
      })
    }
  }
}