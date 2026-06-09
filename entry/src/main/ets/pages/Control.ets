import { LottieView } from "../utils/LottieView";
import { image } from '@kit.ImageKit'
import { WSClient } from '../utils/WebSocketClient'
import { promptAction } from "@kit.ArkUI"
import { DogAppController } from '../utils/DogAppController'
import { IntercomService } from '../utils/IntercomService'
import common from '@ohos.app.ability.common'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'
import http from '@ohos.net.http'
import { IotConnector } from '../utils/IotConnector'
import { authService, CommonConstant } from '../utils/GetIotToken'
import { HttpPostUtil } from '../utils/HttpPostUtil'
import { KeyCode } from '@kit.InputKit'
import {
  DEFAULT_XFYUN_VOICE,
  FALLBACK_XFYUN_VOICE_OPTIONS,
  XfyunVoiceOption,
  getXfyunVoiceLabel,
  getXfyunVoiceOptions,
  normalizeXfyunVoiceId
} from '../utils/XfyunVoiceUtil'
import { AppShadow } from '../theme/Theme'
import {
  GamepadControlAction,
  getGamepadActionFromAxisState,
  getGamepadActionFromDirection
} from '../utils/GamepadControlMapper'

// ======================== 常量定义 ========================
const COLLAPSED_VOICE_OPTION_COUNT: number = 4

function getCommandDisplayName(cmd: string): string {
  switch (cmd) {
    case 'trot':       return '前进'
    case 'trot_back':  return '后退'
    case 'turn_left':  return '左转'
    case 'turn_right': return '右转'
    case 'stop':       return '停止'
    default:           return cmd
  }
}

interface TrackerResponse {
  message: string
}

interface TrackerBody {
  enable: number
}

interface UserVoiceSettings {
  voiceId?: string
  speedRatio?: number
  vol?: number
  wakeWord?: string
}

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

// ============================================================
// 九宫格按钮（暗色滑出面板内使用）
// ============================================================
@Component
struct ControlPadButton {
  @Prop icon: ResourceStr
  @Prop cmd: string
  @Prop buttonId: string
  @Prop angle: number = 0
  @Prop isLatched: boolean = false

  onPressStart: (cmd: string, buttonId: string) => void = () => {}
  onPressEnd: (cmd: string, buttonId: string) => void = () => {}

  @State isPressed: boolean = false

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width('100%')
        .height('100%')
        .fill(this.isPressed || this.isLatched ? '#FF1F8BFF' : '#FFEAF5FF')

      Image(this.icon)
        .width(30)
        .height(30)
        .rotate({ angle: this.angle })
        .fillColor(this.isPressed || this.isLatched ? '#FFFFFFFF' : '#FF1F8BFF')
        .objectFit(ImageFit.Contain)
    }
    .width(72)
    .height(72)
    .borderRadius(36)
    .border({
      width: 1,
      color: this.isPressed || this.isLatched ? '#FF1F8BFF' : '#FFD4E4F5'
    })
    .shadow({
      radius: this.isPressed || this.isLatched ? 14 : 6,
      color: this.isPressed || this.isLatched ? '#331F78FF' : '#14000000',
      offsetY: 4
    })
    .scale({
      x: this.isPressed ? 0.93 : this.isLatched ? 0.97 : 1,
      y: this.isPressed ? 0.93 : this.isLatched ? 0.97 : 1
    })
    .animation({ duration: 110, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.isPressed = true
        this.onPressStart(this.cmd, this.buttonId)
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.isPressed = false
        this.onPressEnd(this.cmd, this.buttonId)
      }
    })
  }
}

@Component
export struct DogControlPanel {
  @Link command_index: number
  @Link current_command: string
  @Link control_open: boolean
  @Link panelHeightPercent: number
  @Prop selectedButtonId: string = ''

  onPressStart: (cmd: string, buttonId: string) => void = () => {}
  onPressEnd: (cmd: string, buttonId: string) => void = () => {}

  @State dragStartY: number = 0
  @State dragStartHeight: number = 72
  @State isDraggingPanel: boolean = false

  private send(cmd: string, buttonId: string, type: 'start' | 'end') {
    if (type === 'start') this.onPressStart(cmd, buttonId)
    else this.onPressEnd(cmd, buttonId)
  }

  private handlePanelDrag(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      if (e.touches && e.touches.length > 0) this.dragStartY = e.touches[0].y
      this.dragStartHeight = this.panelHeightPercent
      this.isDraggingPanel = true
      return
    }

    if (e.type === TouchType.Move && this.isDraggingPanel) {
      if (e.touches && e.touches.length > 0) {
        const deltaY: number = e.touches[0].y - this.dragStartY
        const nextHeight: number = this.dragStartHeight - deltaY / 6
        this.panelHeightPercent = Math.max(42, Math.min(90, nextHeight))
      }
      return
    }

    if ((e.type === TouchType.Up || e.type === TouchType.Cancel) && this.isDraggingPanel) {
      this.isDraggingPanel = false
      if (this.panelHeightPercent < 46) {
        this.control_open = false
        this.panelHeightPercent = 72
      }
    }
  }

  build() {
    Column({ space: 16 }) {
      Column() {
        Rect()
          .width(48)
          .height(5)
          .fill('#73FFFFFF')
          .borderRadius(3)
      }
      .width('100%')
      .height(24)
      .justifyContent(FlexAlign.Center)
      .onTouch((e: TouchEvent): void => this.handlePanelDrag(e))

      Row() {
        Column({ space: 4 }) {
          Text('机械狗遥控台')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('长按持续动作，短按切换动作')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.down'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.brand_primary'))
          .padding(6)
          .borderRadius(16)
          .backgroundColor($r('app.color.brand_primary_subtle'))
          .onClick(() => this.control_open = false)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 12 }) {
        Row({ space: 14 }) {
          ControlPadButton({
            icon: $r('app.media.arrow_uptwo'), cmd: 'trot', buttonId: 'pad_up_left',
            isLatched: this.selectedButtonId === 'pad_up_left', angle: -45,
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.turn_up'), cmd: 'trot', buttonId: 'pad_up',
            isLatched: this.selectedButtonId === 'pad_up',
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.arrow_uptwo'), cmd: 'trot', buttonId: 'pad_up_right',
            isLatched: this.selectedButtonId === 'pad_up_right', angle: 45,
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
        }

        Row({ space: 14 }) {
          ControlPadButton({
            icon: $r('app.media.turn_left'), cmd: 'turn_left', buttonId: 'pad_left',
            isLatched: this.selectedButtonId === 'pad_left',
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.round'), cmd: 'stop', buttonId: 'pad_stop',
            isLatched: this.selectedButtonId === 'pad_stop',
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.turn_right'), cmd: 'turn_right', buttonId: 'pad_right',
            isLatched: this.selectedButtonId === 'pad_right',
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
        }

        Row({ space: 14 }) {
          ControlPadButton({
            icon: $r('app.media.arrow_downtwo'), cmd: 'trot_back', buttonId: 'pad_down_left',
            isLatched: this.selectedButtonId === 'pad_down_left', angle: 45,
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.turn_down'), cmd: 'trot_back', buttonId: 'pad_down',
            isLatched: this.selectedButtonId === 'pad_down',
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
          ControlPadButton({
            icon: $r('app.media.arrow_downtwo'), cmd: 'trot_back', buttonId: 'pad_down_right',
            isLatched: this.selectedButtonId === 'pad_down_right', angle: -45,
            onPressStart: (cmd, id): void => this.send(cmd, id, 'start'),
            onPressEnd: (cmd, id): void => this.send(cmd, id, 'end')
          })
        }
      }
      .padding(14)
      .backgroundColor($r('app.color.page_bg_alt'))
      .border({ width: 1, color: $r('app.color.surface_border') })
      .borderRadius(22)

      Row() {
        Text('当前指令')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Text(this.current_command.length > 0 ? getCommandDisplayName(this.current_command) : '待命')
          .fontSize(22)
          .fontColor($r('app.color.brand_primary'))
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 30 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.surface_card_solid'))
    .border({ width: 1, color: $r('app.color.surface_border') })
    .borderRadius({ topLeft: 30, topRight: 30 })
    .shadow({ radius: 24, color: '#1A1F78FF', offsetY: -6 })
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM))
    .animation({ duration: 260, curve: Curve.EaseOut })
  }
}

// ======================== 全局状态初始化 ========================
PersistentStorage.persistProp('account', 0)
PersistentStorage.persistProp('password', '')
PersistentStorage.persistProp('username', '请先登录')
PersistentStorage.persistProp('isLogin', false)
PersistentStorage.persistProp('avatar', 1)
PersistentStorage.persistProp('avatarUrl', '')

if (!AppStorage.has('isLogin')) AppStorage.setOrCreate('isLogin', false)
if (!AppStorage.has('localhost')) AppStorage.setOrCreate('localhost', '118.195.133.25')
if (!AppStorage.has('deeplearning_ip')) AppStorage.setOrCreate('deeplearning_ip', '192.168.77.219')
if (!AppStorage.has('current_command')) AppStorage.setOrCreate('current_command', '')

if (!AppStorage.has('voiceId')) AppStorage.setOrCreate('voiceId', DEFAULT_XFYUN_VOICE)
if (!AppStorage.has('speedRatio')) AppStorage.setOrCreate('speedRatio', 1.0)
if (!AppStorage.has('vol')) AppStorage.setOrCreate('vol', 50)
if (!AppStorage.has('wakeWord')) AppStorage.setOrCreate('wakeWord', '小E')
if (!AppStorage.has('petName')) AppStorage.setOrCreate('petName', '小E')

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
  @StorageLink('deeplearning_ip') deeplearning_ip: string = '192.168.77.219'
  @StorageLink('account') account: number = 0
  @StorageLink('current_command') current_command: string = ''
  @StorageLink('isTrace') isTrace: boolean = false
  @StorageLink('voiceId') voiceId: string = DEFAULT_XFYUN_VOICE
  @StorageLink('speedRatio') speedRatio: number = 1.0
  @StorageLink('vol') vol: number = 50
  @StorageLink('wakeWord') wakeWord: string = '小E'
  @StorageLink('petName') petName: string = '小E'

  @State isConnected: boolean = false
  @State isConnecting: boolean = false
  @State isIntercomActive: boolean = false
  @State imageData: image.PixelMap | null = null

  @State command_index: number = 0
  @State control_open: boolean = false
  @State showVoicePanel: boolean = false
  @State iotTokenReady: boolean = false
  @State selectedPadButtonId: string = ''
  @State voiceOptions: XfyunVoiceOption[] = FALLBACK_XFYUN_VOICE_OPTIONS
  @State showAllVoiceOptions: boolean = false

  @State tempWakeWord: string = ''
  @State controlPanelHeight: number = 66
  @State voicePanelHeight: number = 66
  @State voiceDragStartY: number = 0
  @State voiceDragStartHeight: number = 66
  @State isDraggingVoicePanel: boolean = false

  private wsClient: WSClient | null = null
  private frameManager: FrameManager = new FrameManager()
  private intercomService: IntercomService = new IntercomService()
  private dogAppController = new DogAppController(`ws://${this.localhost}:8080/order`)

  private pressTimer: number = -1
  private isLongPress: boolean = false
  private activeGamepadCommand: string = ''

  async aboutToAppear() {
    this.showToast("正在初始化...")
    this.tempWakeWord = this.wakeWord
    this.voiceId = normalizeXfyunVoiceId(this.voiceId, this.voiceOptions)

    await this.fetchVoiceOptions()
    await this.fetchUserSettings()

    try {
      this.showToast("正在连接 IoT 平台...")
      const token = await authService.login()
      CommonConstant.token = token
      this.iotTokenReady = true
      console.info("IoT 平台 Token 获取成功:", token)
    } catch (err) {
      this.iotTokenReady = false
      console.error("IoT Token 获取失败:", err)
      this.showToast("IoT 平台连接失败，请检查网络")
    }
  }

  async fetchVoiceOptions() {
    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${this.localhost}:8080/api/accounts/voices`,
        { method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000 }
      )

      if (response.responseCode !== 200) {
        console.error('获取音色列表失败, HTTP Code:', response.responseCode)
        return
      }

      const resText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      const voiceList = JSON.parse(resText) as XfyunVoiceOption[]
      if (!Array.isArray(voiceList) || voiceList.length === 0) return

      const normalizedOptions: XfyunVoiceOption[] = []
      for (let i = 0; i < voiceList.length; i++) {
        const item = voiceList[i]
        if (!item || !item.voice || item.voice.trim().length === 0) continue
        normalizedOptions.push({
          label: getXfyunVoiceLabel(item),
          voice: item.voice.trim(),
          supportedSampleRates: Array.isArray(item.supportedSampleRates) ? item.supportedSampleRates : []
        })
      }

      if (normalizedOptions.length > 0) {
        this.voiceOptions = normalizedOptions
        this.voiceId = normalizeXfyunVoiceId(this.voiceId, normalizedOptions)
        AppStorage.setOrCreate('voiceId', this.voiceId)
      }
    } catch (err) {
      console.error('获取音色列表异常:', JSON.stringify(err))
    }
  }

  async fetchUserSettings() {
    if (!this.account || this.account === 0) return

    try {
      const httpRequest = http.createHttp()
      const url = `http://${this.localhost}:8080/api/accounts/info/${this.account}`
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000
      })

      if (response.responseCode === 200) {
        const resText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
        const userData = JSON.parse(resText) as UserVoiceSettings

        if (userData) {
          if (userData.voiceId) {
            AppStorage.setOrCreate('voiceId', normalizeXfyunVoiceId(userData.voiceId, this.voiceOptions))
          }
          if (userData.speedRatio !== undefined) AppStorage.setOrCreate('speedRatio', Number(userData.speedRatio))
          if (userData.vol !== undefined) AppStorage.setOrCreate('vol', Number(userData.vol))
          if (userData.wakeWord) {
            AppStorage.setOrCreate('wakeWord', userData.wakeWord)
            AppStorage.setOrCreate('petName', userData.wakeWord)
            this.tempWakeWord = userData.wakeWord
          }
        }
      }
    } catch (err) {
      console.error('获取用户配置异常:', JSON.stringify(err))
    }
  }

  private getRenderableVoiceOptions(): XfyunVoiceOption[] {
    return getXfyunVoiceOptions(this.voiceOptions)
  }

  private getVisibleVoiceOptions(): XfyunVoiceOption[] {
    const options: XfyunVoiceOption[] = this.getRenderableVoiceOptions()
    if (this.showAllVoiceOptions || options.length <= COLLAPSED_VOICE_OPTION_COUNT) return options

    const visibleOptions: XfyunVoiceOption[] = options.slice(0, COLLAPSED_VOICE_OPTION_COUNT)
    const currentVoiceId: string = normalizeXfyunVoiceId(this.voiceId, options)

    for (let i = 0; i < visibleOptions.length; i++) {
      if (visibleOptions[i].voice === currentVoiceId) return visibleOptions
    }

    for (let i = 0; i < options.length; i++) {
      if (options[i].voice === currentVoiceId) {
        visibleOptions[visibleOptions.length - 1] = options[i]
        break
      }
    }

    return visibleOptions
  }

  private hasHiddenVoiceOptions(): boolean {
    return this.getRenderableVoiceOptions().length > COLLAPSED_VOICE_OPTION_COUNT
  }

  aboutToDisappear() {
    this.disconnectAll()
    if (this.pressTimer !== -1) clearTimeout(this.pressTimer)
  }

  onPressStart(cmd: string, buttonId: string): void {
    if (this.pressTimer !== -1) {
      clearTimeout(this.pressTimer)
      this.pressTimer = -1
    }
    this.isLongPress = false

    this.pressTimer = setTimeout((): void => {
      this.isLongPress = true
      this.current_command = cmd
      this.selectedPadButtonId = ''
      this.sendCommand(cmd)
    }, 500)
  }

  onPressEnd(cmd: string, buttonId: string): void {
    if (this.pressTimer !== -1) {
      clearTimeout(this.pressTimer)
      this.pressTimer = -1
    }

    if (this.isLongPress) {
      this.sendCommand('stop')
      this.current_command = ''
      this.selectedPadButtonId = ''
      this.isLongPress = false
      return
    }

    if (cmd === 'stop') {
      this.sendCommand('stop')
      this.current_command = ''
      this.selectedPadButtonId = this.selectedPadButtonId === buttonId ? '' : buttonId
      return
    }

    if (this.selectedPadButtonId === buttonId) {
      this.sendCommand('stop')
      this.current_command = ''
      this.selectedPadButtonId = ''
      return
    }

    if (this.current_command && this.current_command.length > 0) {
      this.sendCommand('stop')
    }
    this.sendCommand(cmd)
    this.current_command = cmd
    this.selectedPadButtonId = buttonId
  }

  async sendCommand(cmd: string) {
    if (!this.iotTokenReady || !CommonConstant.token) return

    try {
      await IotConnector.sendMessage(cmd)
    } catch (err) {
      console.error("动作发送失败:", JSON.stringify(err))
    }
  }

  private applyGamepadAction(action: GamepadControlAction, forceStop: boolean = false): void {
    if (action.command === 'stop') {
      if (!forceStop && this.activeGamepadCommand.length === 0) return

      this.sendCommand('stop')
      this.activeGamepadCommand = ''
      this.current_command = ''
      this.selectedPadButtonId = ''
      return
    }

    if (this.activeGamepadCommand === action.command) return

    if (this.current_command && this.current_command.length > 0) {
      this.sendCommand('stop')
    }

    this.sendCommand(action.command)
    this.activeGamepadCommand = action.command
    this.current_command = action.command
    this.selectedPadButtonId = action.buttonId
  }

  private handleGamepadKey(event: KeyEvent): void {
    if (!event) return

    if (event.type === KeyType.Up) {
      switch (event.keyCode) {
        case KeyCode.KEYCODE_DPAD_UP:
        case KeyCode.KEYCODE_DPAD_DOWN:
        case KeyCode.KEYCODE_DPAD_LEFT:
        case KeyCode.KEYCODE_DPAD_RIGHT:
          this.applyGamepadAction(getGamepadActionFromDirection('center'))
          break
        default:
          break
      }
      return
    }

    if (event.type !== KeyType.Down) return

    switch (event.keyCode) {
      case KeyCode.KEYCODE_DPAD_UP:
        this.applyGamepadAction(getGamepadActionFromDirection('up'))
        break
      case KeyCode.KEYCODE_DPAD_DOWN:
        this.applyGamepadAction(getGamepadActionFromDirection('down'))
        break
      case KeyCode.KEYCODE_DPAD_LEFT:
        this.applyGamepadAction(getGamepadActionFromDirection('left'))
        break
      case KeyCode.KEYCODE_DPAD_RIGHT:
        this.applyGamepadAction(getGamepadActionFromDirection('right'))
        break
      case KeyCode.KEYCODE_BUTTON_SELECT:
      case KeyCode.KEYCODE_BUTTON_START:
        this.applyGamepadAction(getGamepadActionFromDirection('center'), true)
        break
      default:
        break
    }
  }

  private handleGamepadAxis(event: FocusAxisEvent): void {
    if (!event || !event.axisMap) return

    const hatX: number = event.axisMap.get(AxisModel.ABS_HAT0X) ?? 0
    const hatY: number = event.axisMap.get(AxisModel.ABS_HAT0Y) ?? 0
    const axisX: number = event.axisMap.get(AxisModel.ABS_X) ?? 0
    const axisY: number = event.axisMap.get(AxisModel.ABS_Y) ?? 0
    this.applyGamepadAction(getGamepadActionFromAxisState(hatX, hatY, axisX, axisY))
  }

  async updateTrackerStatus(enable: boolean) {
    const url = `http://${this.localhost}:8080/tracker/status`
    const body: TrackerBody = { enable: enable ? 1 : 0 }

    try {
      const response = await HttpPostUtil.request<TrackerResponse, TrackerBody>({ url: url, body: body })
      console.info(`Tracker status updated: ${JSON.stringify(response)}`)
    } catch (err) {
      console.error(`Failed to update tracker status: ${JSON.stringify(err)}`)
      this.showToast('Failed to update tracker status')
    }
  }

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

    this.dogAppController.connect(
      (msg: string) => this.handleControlMessage(msg),
      () => {},
      (connected: boolean) => {
        if (connected) this.checkAllConnected()
        else {
          this.isConnecting = false
          this.showToast('控制服务器连接失败')
        }
      },
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
    if (this.isIntercomActive) this.stopIntercom()
    this.wsClient?.close()
    this.dogAppController.close?.()
    this.isConnected = false
    this.isConnecting = false
    this.isIntercomActive = false
    this.imageData = null
    this.current_command = ''
    this.selectedPadButtonId = ''
    this.frameManager.release()
  }

  private async ensureMicrophonePermission(): Promise<boolean> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.requestPermissionsFromUser(
        context,
        ['ohos.permission.MICROPHONE' as Permissions]
      )
      return !!result.authResults &&
        result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (err) {
      console.error('Microphone permission request failed:', JSON.stringify(err))
      return false
    }
  }

  private async startIntercom(): Promise<void> {
    if (!this.dogAppController.getIsConnected()) {
      this.showToast('请先连接控制服务器')
      return
    }

    const granted = await this.ensureMicrophonePermission()
    if (!granted) {
      this.showToast('麦克风权限未授予')
      return
    }

    try {
      this.dogAppController.send('__INTERCOM_START__')
      await this.intercomService.start((pcm: ArrayBuffer) => {
        this.dogAppController.sendBinary(pcm)
      })
      this.isIntercomActive = true
      this.showToast('对讲已开启')
    } catch (err) {
      console.error('Start intercom failed:', JSON.stringify(err))
      this.isIntercomActive = false
      this.showToast('开启对讲失败')
      this.dogAppController.send('__INTERCOM_STOP__')
      await this.intercomService.stop()
    }
  }

  private async stopIntercom(): Promise<void> {
    try {
      this.dogAppController.send('__INTERCOM_STOP__')
      await this.intercomService.stop()
    } catch (err) {
      console.error('Stop intercom failed:', JSON.stringify(err))
    } finally {
      this.isIntercomActive = false
      this.showToast('对讲已关闭')
    }
  }

  private async toggleIntercom(): Promise<void> {
    if (this.isIntercomActive) await this.stopIntercom()
    else await this.startIntercom()
  }

  private async handleControlMessage(msg: string): Promise<void> {
    if (msg === 'INTERCOM_DEVICE_OFFLINE') {
      await this.intercomService.stop()
      this.isIntercomActive = false
      this.showToast('设备音频通道未在线')
    } else if (msg === 'INTERCOM_READY') {
      this.showToast('设备已进入对讲')
    } else if (msg === 'INTERCOM_STOPPED') {
      this.isIntercomActive = false
    }
  }

  async handleVideoFrame(buf: ArrayBuffer) {
    const frame = await this.frameManager.processFrame(buf)
    if (frame) this.imageData = frame
  }

  showToast(msg: string) {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  private getConnectStateText(): string {
    if (this.isConnected) return '在线'
    if (this.isConnecting) return '连接中'
    return '离线'
  }

  private getConnectStateColor(): ResourceColor {
    if (this.isConnected) return $r('app.color.state_success')
    if (this.isConnecting) return $r('app.color.state_warning')
    return $r('app.color.state_danger')
  }

  private getConnectStateBg(): ResourceColor {
    if (this.isConnected) return $r('app.color.state_success_subtle')
    if (this.isConnecting) return $r('app.color.state_warning_subtle')
    return $r('app.color.state_danger_subtle')
  }

  private handleVoicePanelDrag(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      if (e.touches && e.touches.length > 0) this.voiceDragStartY = e.touches[0].y
      this.voiceDragStartHeight = this.voicePanelHeight
      this.isDraggingVoicePanel = true
      return
    }

    if (e.type === TouchType.Move && this.isDraggingVoicePanel) {
      if (e.touches && e.touches.length > 0) {
        const deltaY: number = e.touches[0].y - this.voiceDragStartY
        const nextHeight: number = this.voiceDragStartHeight - deltaY / 6
        this.voicePanelHeight = Math.max(42, Math.min(90, nextHeight))
      }
      return
    }

    if ((e.type === TouchType.Up || e.type === TouchType.Cancel) && this.isDraggingVoicePanel) {
      this.isDraggingVoicePanel = false
      if (this.voicePanelHeight < 46) {
        this.showVoicePanel = false
        this.showAllVoiceOptions = false
        this.voicePanelHeight = 66
      }
    }
  }

  async updateVoiceSetting() {
    if (!this.account || this.account === 0) {
      this.showToast('请先登录后再保存设置')
      return
    }

    try {
      const normalizedVoiceId: string = normalizeXfyunVoiceId(this.voiceId, this.voiceOptions)
      this.voiceId = normalizedVoiceId
      AppStorage.setOrCreate('voiceId', normalizedVoiceId)
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(
        `http://${this.localhost}:8080/api/accounts/updateVoice`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify({
            account: this.account,
            voiceId: normalizedVoiceId,
            speedRatio: this.speedRatio,
            vol: this.vol
          })
        }
      )
      if (response.responseCode === 200) promptAction.showToast({ message: '语音参数已应用' })
      else promptAction.showToast({ message: '参数应用失败' })
    } catch (err) {
      console.error('语音参数更新异常:', err)
      promptAction.showToast({ message: '网络请求错误' })
    }
  }

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
          extraData: JSON.stringify({ account: this.account, wakeWord: this.tempWakeWord.trim() })
        }
      )
      if (response.responseCode === 200) {
        const savedWakeWord: string = this.tempWakeWord.trim()
        AppStorage.setOrCreate('wakeWord', savedWakeWord)
        AppStorage.setOrCreate('petName', savedWakeWord)
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
    Stack({ alignContent: Alignment.Bottom }) {
      // 页面背景（淡蓝渐变）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [$r('app.color.brand_primary_subtle'), 0.0],
            [$r('app.color.page_bg_alt'), 0.46],
            [$r('app.color.page_bg'), 1.0]
          ]
        })

      // 装饰圆
      Circle()
        .width(320)
        .height(320)
        .fill('#22178A7A')
        .position({ x: 250, y: -150 })

      Circle()
        .width(260)
        .height(260)
        .fill('#1FE28B2D')
        .position({ x: -108, y: 440 })

      Column({ space: 14 }) {
        // 顶部栏
        Row() {
          Column() {
            Text('智控中心')
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text(this.isConnected ? '设备链路已就绪' : this.isConnecting ? '正在建立视频与控制链路' : '连接设备后开始实时操控')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row({ space: 7 }) {
            Circle()
              .width(8)
              .height(8)
              .fill(this.getConnectStateColor())

            Text(this.getConnectStateText())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getConnectStateColor())
          }
          .padding({ left: 13, right: 13, top: 7, bottom: 7 })
          .backgroundColor(this.getConnectStateBg())
          .borderRadius(16)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 2, right: 2, top: 3 })

        // 视频监控卡片
        Column({ space: 12 }) {
          Row() {
            Column({ space: 2 }) {
              Text('实时视频')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text(this.isConnected ? '画面同步中' : '等待连接视频服务器')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row({ space: 6 }) {
              Circle()
                .width(7)
                .height(7)
                .fill(this.isConnected ? $r('app.color.state_success') : $r('app.color.text_tertiary'))

              Text(this.isConnected ? 'LIVE' : 'OFF')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isConnected ? $r('app.color.state_success') : $r('app.color.text_tertiary'))
            }
            .height(28)
            .padding({ left: 10, right: 10 })
            .backgroundColor(this.isConnected ? $r('app.color.state_success_subtle') : $r('app.color.input_bg'))
            .borderRadius(14)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Stack({ alignContent: Alignment.Bottom }) {
            if (this.imageData) {
              Image(this.imageData)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
            } else {
              Column({ space: 10 }) {
                LottieView({ name: 'loading' })
                  .width(146)
                  .height(146)
                Text(this.isConnecting ? '正在连接视频服务...' : '点击下方按钮开始连接')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .width('100%')
              .height('100%')
            }

            if (this.isConnected || this.isConnecting) {
              Row() {
                Text(this.isConnected ? '已连接视频服务器' : '视频链路连接中')
                  .fontSize(12)
                  .fontColor($r('app.color.brand_primary'))
              }
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor($r('app.color.brand_primary_subtle'))
              .borderRadius(14)
              .margin({ bottom: 13 })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .borderRadius(22)
          .clip(true)
          .backgroundColor($r('app.color.page_bg_alt'))
          .border({ width: 1, color: $r('app.color.surface_border') })
        }
        .layoutWeight(5)
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 1, color: $r('app.color.surface_border') })
        .borderRadius(28)
        .shadow(AppShadow.card)

        // 操作卡片
        Stack({ alignContent: Alignment.Bottom }) {
          Column({ space: 14 }) {
            // 状态行
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('控制链路')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))

                Text(this.getConnectStateText())
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getConnectStateColor())
              }
              .layoutWeight(1)
              .height(60)
              .justifyContent(FlexAlign.Center)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.getConnectStateBg())
              .border({ width: 1, color: $r('app.color.surface_border') })
              .borderRadius(18)

              Column({ space: 4 }) {
                Text('智能追踪')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))

                Text(this.isTrace ? '运行中' : '未开启')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isTrace
                    ? $r('app.color.state_success')
                    : $r('app.color.text_primary'))
              }
              .layoutWeight(1)
              .height(60)
              .justifyContent(FlexAlign.Center)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.isTrace ? $r('app.color.state_success_subtle') : $r('app.color.input_bg'))
              .border({ width: 1, color: $r('app.color.surface_border') })
              .borderRadius(18)
            }
            .width('100%')

            Column({ space: 14 }) {
              // 一键连接 + 智能追踪
              Row({ space: 14 }) {
                Button(this.isConnected ? '断开连接' : '一键连接')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height(58)
                  .fontColor($r('app.color.text_on_brand'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: this.isConnected
                      ? [['#FFFF8B5C', 0], [$r('app.color.state_danger'), 1]]
                      : [[$r('app.color.brand_gradient_start'), 0], [$r('app.color.brand_gradient_end'), 1]]
                  })
                  .borderRadius(22)
                  .shadow(AppShadow.button)
                  .onClick(() => {
                    if (this.isConnected) {
                      this.disconnectAll()
                      this.showToast('已断开所有连接')
                    } else {
                      this.onConnectClick()
                    }
                  })

                Button(this.isTrace ? '停止追踪' : '智能追踪')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height(58)
                  .fontColor($r('app.color.text_on_brand'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: this.isTrace
                      ? [['#FFFFA070', 0], [$r('app.color.state_warning'), 1]]
                      : [[$r('app.color.state_success'), 0], ['#FF21B592', 1]]
                  })
                  .borderRadius(22)
                  .shadow(AppShadow.button)
                  .onClick(async () => {
                    this.isTrace = !this.isTrace
                    AppStorage.setOrCreate('isTrace', this.isTrace)
                    await this.updateTrackerStatus(this.isTrace)
                    this.showToast(this.isTrace ? '自动追踪已开启' : '自动追踪已关闭')
                  })
              }
              .width('100%')

              // 运动遥控 + 语音配置
              Row({ space: 14 }) {
                Button(this.control_open ? '隐藏遥控' : '运动遥控')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height(58)
                  .fontColor($r('app.color.text_on_brand'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: this.control_open
                      ? [['#FFA4B3C8', 0], [$r('app.color.text_tertiary'), 1]]
                      : [[$r('app.color.brand_gradient_start'), 0], [$r('app.color.brand_gradient_end'), 1]]
                  })
                  .borderRadius(22)
                  .shadow(AppShadow.button)
                  .onClick(() => {
                    this.control_open = !this.control_open
                    if (this.control_open) {
                      this.showVoicePanel = false
                      this.showAllVoiceOptions = false
                      this.controlPanelHeight = Math.max(56, this.controlPanelHeight)
                    }
                  })

                Button(this.showVoicePanel ? '隐藏设置' : '语音配置')
                  .type(ButtonType.Normal)
                  .layoutWeight(1)
                  .height(58)
                  .fontColor($r('app.color.text_on_brand'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: this.showVoicePanel
                      ? [['#FFA4B3C8', 0], [$r('app.color.text_tertiary'), 1]]
                      : [[$r('app.color.state_info'), 0], [$r('app.color.brand_primary_pressed'), 1]]
                  })
                  .borderRadius(22)
                  .shadow(AppShadow.button)
                  .onClick(() => {
                    this.showVoicePanel = !this.showVoicePanel
                    if (this.showVoicePanel) {
                      this.control_open = false
                      this.voicePanelHeight = this.controlPanelHeight
                      this.showAllVoiceOptions = false
                      this.voiceId = normalizeXfyunVoiceId(this.voiceId, this.voiceOptions)
                    } else {
                      this.showAllVoiceOptions = false
                    }
                    this.tempWakeWord = this.wakeWord
                  })
              }
              .width('100%')

              // 语音通话
              Row() {
                Button(this.isIntercomActive ? '关闭语音通话' : '开启语音通话')
                  .type(ButtonType.Normal)
                  .width('100%')
                  .height(58)
                  .fontColor($r('app.color.text_on_brand'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: this.isIntercomActive
                      ? [['#FFFF8B5C', 0], [$r('app.color.state_danger'), 1]]
                      : [[$r('app.color.brand_gradient_start'), 0], [$r('app.color.brand_gradient_end'), 1]]
                  })
                  .borderRadius(22)
                  .shadow(AppShadow.button)
                  .onClick(async () => {
                    await this.toggleIntercom()
                  })
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.surface_border') })
          .borderRadius(28)
          .shadow(AppShadow.cardHover)
        }
        .layoutWeight(5)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.control_open) {
        DogControlPanel({
          command_index: this.command_index,
          current_command: this.current_command,
          control_open: this.control_open,
          panelHeightPercent: this.controlPanelHeight,
          selectedButtonId: this.selectedPadButtonId,
          onPressStart: (cmd, id): void => this.onPressStart(cmd, id),
          onPressEnd: (cmd, id): void => this.onPressEnd(cmd, id)
        })
        .width('100%')
        .height(`${this.controlPanelHeight}%`)
        .zIndex(60)
      }

      // 语音设置滑出面板
      if (this.showVoicePanel) {
        Column() {
          Column() {
            Rect()
              .width(48)
              .height(5)
              .fill($r('app.color.text_tertiary'))
              .borderRadius(3)
          }
          .width('100%')
          .height(24)
          .justifyContent(FlexAlign.Center)
          .onTouch((e: TouchEvent): void => this.handleVoicePanelDrag(e))

          Row() {
            Text('语音参数面板')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            Image($r('app.media.down'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_tertiary'))
              .onClick(() => {
                this.showVoicePanel = false
                this.showAllVoiceOptions = false
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 4, right: 4, bottom: 8 })

          Scroll() {
            Column({ space: 12 }) {
              // 唤醒词
              Column({ space: 10 }) {
                Text('唤醒词')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Row({ space: 10 }) {
                  TextInput({ text: this.tempWakeWord, placeholder: '输入唤醒词（与宠物名一致）' })
                    .layoutWeight(1)
                    .height(42)
                    .borderRadius(10)
                    .padding({ left: 12, right: 12 })
                    .backgroundColor($r('app.color.input_bg'))
                    .border({ width: 1, color: $r('app.color.input_border') })
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .onChange((val) => this.tempWakeWord = val)

                  Button('保存')
                    .height(42)
                    .fontSize(14)
                    .fontColor($r('app.color.text_on_brand'))
                    .backgroundColor($r('app.color.brand_primary'))
                    .borderRadius(10)
                    .onClick(() => this.saveWakeWord())
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.surface_card_solid'))
              .borderRadius(14)

              // 音色
              Column({ space: 10 }) {
                Text('音色')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(this.getVisibleVoiceOptions(), (item: XfyunVoiceOption) => {
                    Button() {
                      Text(getXfyunVoiceLabel(item))
                        .fontSize(13)
                        .fontColor(this.voiceId === item.voice
                          ? $r('app.color.text_on_brand')
                          : $r('app.color.text_primary'))
                        .textAlign(TextAlign.Center)
                        .maxLines(2)
                        .width('100%')
                    }
                    .width('48%')
                    .height(44)
                    .padding({ left: 8, right: 8 })
                    .backgroundColor(this.voiceId === item.voice
                      ? $r('app.color.brand_primary')
                      : $r('app.color.input_bg'))
                    .borderRadius(12)
                    .margin({ bottom: 10 })
                    .onClick(() => this.voiceId = item.voice)
                  }, (item: XfyunVoiceOption) => item.voice)
                }
                .width('100%')

                if (this.hasHiddenVoiceOptions()) {
                  Row() {
                    Button(this.showAllVoiceOptions ? '收起' : '展开更多')
                      .type(ButtonType.Normal)
                      .fontSize(13)
                      .fontColor($r('app.color.brand_primary'))
                      .backgroundColor($r('app.color.brand_primary_subtle'))
                      .borderRadius(10)
                      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                      .onClick(() => this.showAllVoiceOptions = !this.showAllVoiceOptions)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.surface_card_solid'))
              .borderRadius(14)

              // 语速 / 音量
              Column({ space: 12 }) {
                Text('语速与音量')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Row() {
                  Image($r('app.media.ic_public_speed'))
                    .width(20)
                    .height(20)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 10 })

                  Text('语速')
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .width(42)

                  Slider({ value: this.speedRatio, min: 0.2, max: 3.0, step: 0.1 })
                    .layoutWeight(1)
                    .blockColor($r('app.color.brand_primary'))
                    .trackColor($r('app.color.divider'))
                    .selectedColor($r('app.color.brand_primary'))
                    .showSteps(false)
                    .onChange((v) => this.speedRatio = v)

                  Text(`${this.speedRatio.toFixed(1)}`)
                    .fontSize(15)
                    .fontColor($r('app.color.brand_primary'))
                    .width(34)
                    .textAlign(TextAlign.End)
                }
                .width('100%')

                Row() {
                  Image($r('app.media.ic_public_sound'))
                    .width(20)
                    .height(20)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 10 })

                  Text('音量')
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .width(42)

                  Slider({ value: this.vol, min: 0, max: 100, step: 1 })
                    .layoutWeight(1)
                    .blockColor($r('app.color.state_info'))
                    .trackColor($r('app.color.divider'))
                    .selectedColor($r('app.color.state_info'))
                    .showSteps(false)
                    .onChange((v) => this.vol = Math.round(v))

                  Text(`${this.vol}`)
                    .fontSize(15)
                    .fontColor($r('app.color.state_info'))
                    .width(34)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.surface_card_solid'))
              .borderRadius(14)

              Button('保存语音参数')
                .width('100%')
                .height(50)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor($r('app.color.brand_primary'))
                .borderRadius(14)
                .onClick(() => this.updateVoiceSetting())
                .margin({ bottom: 14 })
            }
            .width('100%')
            .padding({ bottom: 16 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')
        .height(`${this.voicePanelHeight}%`)
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .backgroundColor($r('app.color.page_bg_alt'))
        .borderRadius({ topLeft: 28, topRight: 28 })
        .shadow({ radius: 32, color: '#47071223', offsetY: -6 })
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM))
        .animation({ duration: 280, curve: Curve.EaseOut })
        .zIndex(61)
      }
    }
    .width('100%')
    .height('100%')
    .focusable(true)
    .defaultFocus(true)
    .focusScopeId('dogControlGamepad', true, false)
    .onKeyEvent((event: KeyEvent): void => this.handleGamepadKey(event))
    .onFocusAxisEvent((event: FocusAxisEvent): void => this.handleGamepadAxis(event))
    // 字体注册已统一移至 EntryAbility.onCreate
  }
}
