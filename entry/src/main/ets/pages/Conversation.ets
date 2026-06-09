import promptAction from '@ohos.promptAction'
import { LottieView } from '../utils/LottieView'
import { IntercomService } from '../utils/IntercomService'
import webSocket from '@ohos.net.webSocket'
import common from '@ohos.app.ability.common'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'
import media from '@ohos.multimedia.media'
import { CozeService, CozeMessage, CozeRequestParams } from '../utils/CozeUtil'
import { ConversationUtil } from '../utils/ConversationUtil'
import { UpdateWakeWordUtil } from '../utils/UpdateWakeWordUtil'
import { DEFAULT_XFYUN_VOICE, normalizeXfyunVoiceId } from '../utils/XfyunVoiceUtil'
import { AppShadow, isTablet } from '../theme/Theme'

interface ActionItem {
  id: string
  title: string
  icon: ResourceStr
  color: ResourceColor
}

interface MoodChip {
  label: string
  value: string
  color: ResourceColor
  icon: ResourceStr
}

interface CozeContentPayload {
  question: string
  voice_id: string
  speed_ratio: number
}

PersistentStorage.persistProp('petName', '小E')
PersistentStorage.persistProp('wakeWord', '小E')
PersistentStorage.persistProp('petMood', 76)
PersistentStorage.persistProp('petSatiety', 72)
PersistentStorage.persistProp('petEnergy', 68)
PersistentStorage.persistProp('petClean', 70)
PersistentStorage.persistProp('petIntimacy', 18)
PersistentStorage.persistProp('petCareCount', 0)
PersistentStorage.persistProp('petLastPhrase', '')
PersistentStorage.persistProp('cozeConversationId', '')

if (!AppStorage.has('petName')) AppStorage.setOrCreate('petName', '小E')
if (!AppStorage.has('wakeWord')) AppStorage.setOrCreate('wakeWord', '小E')
if (!AppStorage.has('petMood')) AppStorage.setOrCreate('petMood', 76)
if (!AppStorage.has('petSatiety')) AppStorage.setOrCreate('petSatiety', 72)
if (!AppStorage.has('petEnergy')) AppStorage.setOrCreate('petEnergy', 68)
if (!AppStorage.has('petClean')) AppStorage.setOrCreate('petClean', 70)
if (!AppStorage.has('petIntimacy')) AppStorage.setOrCreate('petIntimacy', 18)
if (!AppStorage.has('petCareCount')) AppStorage.setOrCreate('petCareCount', 0)
if (!AppStorage.has('petLastPhrase')) AppStorage.setOrCreate('petLastPhrase', '')
if (!AppStorage.has('cozeConversationId')) AppStorage.setOrCreate('cozeConversationId', '')

@Builder
export function ConversationBuilder() {
  Conversation()
}

// 圆形动作按钮（8 件互动事件）
@Component
struct RoundActionButton {
  @Prop title: string
  @Prop icon: ResourceStr
  @Prop color: ResourceColor
  onTap: () => void = () => {}

  @State pressed: boolean = false

  build() {
    Column({ space: 8 }) {
      Row() {
        Image(this.icon)
          .width(25)
          .height(25)
          .objectFit(ImageFit.Contain)
      }
      .width(54)
      .height(54)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.color)
      .borderRadius(18)
      .shadow({
        radius: this.pressed ? 4 : 14,
        color: '#33000000',
        offsetY: this.pressed ? 2 : 6
      })
      .scale({ x: this.pressed ? 0.92 : 1, y: this.pressed ? 0.92 : 1 })
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })

      Text(this.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Center)
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) this.pressed = true
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.pressed = false
    })
    .onClick((): void => this.onTap())
  }
}

// 语音模式按钮（学话 / 聊天）
@Component
struct VoiceModeButton {
  @Prop title: string
  @Prop subtitle: string
  @Prop active: boolean = false
  @Prop color: ResourceColor
  @Prop icon: ResourceStr
  onTap: () => void = () => {}

  @State pressed: boolean = false

  build() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(56)
          .height(56)
          .backgroundColor(this.active ? this.color : '#0A000000')
          .borderRadius(28)
          .opacity(this.active ? 0.18 : 1)

        Row() {
          Image(this.icon)
            .width(19)
            .height(19)
            .fillColor($r('app.color.text_on_brand'))
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.active ? this.color : $r('app.color.text_tertiary'))
        .borderRadius(22)
        .shadow(this.active ? AppShadow.button : AppShadow.subtle)
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.active
            ? $r('app.color.text_primary')
            : $r('app.color.text_secondary'))
          .maxLines(1)

        Text(this.subtitle)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .height(72)
    .layoutWeight(1)
    .padding({ left: 10, right: 12 })
    .backgroundColor($r('app.color.surface_card'))
    .border({
      width: this.active ? 2 : 1,
      color: this.active ? this.color : $r('app.color.surface_border')
    })
    .borderRadius(18)
    .shadow(this.active ? AppShadow.cardHover : AppShadow.card)
    .scale({
      x: this.pressed ? 0.98 : this.active ? 1.01 : 1,
      y: this.pressed ? 0.98 : this.active ? 1.01 : 1
    })
    .animation({ duration: 150, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) this.pressed = true
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.pressed = false
    })
    .onClick((): void => this.onTap())
  }
}

// 聊天历史入口小按钮
@Component
struct ChatHistoryEntryButton {
  onTap: () => void = () => {}

  build() {
    Row({ space: 8 }) {
      Circle()
        .width(8)
        .height(8)
        .fill($r('app.color.brand_primary'))

      Text('聊天记录')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary'))
    }
    .height(34)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.surface_border') })
    .borderRadius(17)
    .shadow(AppShadow.subtle)
    .onClick((): void => this.onTap())
  }
}

// 状态胶囊（心情 / 饱食 / 亲密）
@Component
struct MoodPill {
  @Prop label: string
  @Prop value: string
  @Prop color: ResourceColor
  @Prop icon: ResourceStr

  build() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(34)
          .height(34)
          .fill(this.color)
          .opacity(0.15)

        Circle()
          .width(27)
          .height(27)
          .fill(this.color)

        Image(this.icon)
          .width(14)
          .height(14)
          .objectFit(ImageFit.Contain)
      }

      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.value)
          .fontSize(18)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(62)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.surface_border') })
    .borderRadius(20)
    .shadow(AppShadow.card)
  }
}

@Component
export struct Conversation {
  pathStack: NavPathStack = new NavPathStack()

  @StorageLink('petName') petName: string = '小E'
  @StorageLink('wakeWord') wakeWord: string = '小E'
  @StorageLink('petMood') petMood: number = 76
  @StorageLink('petSatiety') petSatiety: number = 72
  @StorageLink('petEnergy') petEnergy: number = 68
  @StorageLink('petClean') petClean: number = 70
  @StorageLink('petIntimacy') petIntimacy: number = 18
  @StorageLink('petCareCount') petCareCount: number = 0
  @StorageLink('petLastPhrase') petLastPhrase: string = ''
  @StorageLink('cozeConversationId') cozeConversationId: string = ''
  @StorageLink('localhost') localhost: string = '118.195.133.25'
  @StorageLink('account') account: number = 0

  @State petSpeech: string = '说点什么，我会学你说一遍。'
  @State talkText: string = ''
  @State showNameDialog: boolean = false
  @State tempPetName: string = ''

  @State petScale: number = 1
  @State petRotate: number = 0
  @State petTranslateY: number = 0
  @State stageBounce: number = 0
  @State reactionIcon: string = ''
  @State reactionOpacity: number = 0
  @State bubbleFloatY: number = 0
  @State micPulseScale: number = 1

  @State isAmbientListening: boolean = false
  @State isAsrConnected: boolean = false
  @State asrStatusText: string = '语音监听未开启'
  @State recognizedText: string = ''
  @State currentVoiceMode: string = 'idle'
  @State chatReplyText: string = ''
  @State chatReplyBubbleVisible: boolean = false
  @State chatReplyBubbleOpacity: number = 0
  @State chatReplyBubbleTranslateY: number = 10
  @State isChatThinking: boolean = false
  @State petFrameIndex: number = 0
  @State isPetSpeaking: boolean = false
  @State petLottieName: string = 'Smiling Dog'
  @State sceneLottieName: string = ''
  @State pageWidth: number = 0
  @State pageHeight: number = 0

  private ambientService: IntercomService = new IntercomService()
  private appAsrWs: webSocket.WebSocket | null = null
  private repeatAsrWs: webSocket.WebSocket | null = null
  private chatAsrWs: webSocket.WebSocket | null = null
  private appAsrConnecting: boolean = false
  private appAsrStarted: boolean = false
  private repeatAsrConnecting: boolean = false
  private chatAsrConnecting: boolean = false
  private repeatAsrConnected: boolean = false
  private chatAsrConnected: boolean = false
  private keepAsrAlive: boolean = false
  private phonePlayer: media.AVPlayer | null = null
  private coze: CozeService = new CozeService()
  private petFrameTimer: number = -1
  private petLottieTimer: number = -1
  private sceneLottieTimer: number = -1
  private chatReplyBubbleHideTimer: number = -1
  private chatReplyBubbleFadeTimer: number = -1
  private chatRequestVersion: number = 0

  @StorageLink('voiceId') voiceId: string = DEFAULT_XFYUN_VOICE
  @StorageLink('speedRatio') speedRatio: number = 1.0

  // 8 件互动事件 - 保留多彩 token 作为功能区分
  private readonly actions: ActionItem[] = [
    { id: 'feed',   title: '喂食', icon: $r('app.media.pet_feed'),   color: $r('app.color.pet_action_feed') },
    { id: 'play',   title: '逗它', icon: $r('app.media.pet_play'),   color: $r('app.color.pet_action_play') },
    { id: 'clean',  title: '洗澡', icon: $r('app.media.pet_clean'),  color: $r('app.color.pet_action_clean') },
    { id: 'sleep',  title: '哄睡', icon: $r('app.media.pet_sleep'),  color: $r('app.color.pet_action_sleep') },
    { id: 'praise', title: '夸奖', icon: $r('app.media.pet_praise'), color: $r('app.color.pet_action_praise') },
    { id: 'dress',  title: '换装', icon: $r('app.media.pet_dress'),  color: $r('app.color.pet_action_dress') },
    { id: 'name',   title: '改名', icon: $r('app.media.pet_rename'), color: $r('app.color.pet_action_rename') },
    { id: 'reset',  title: '复原', icon: $r('app.media.pet_reset'),  color: $r('app.color.pet_action_reset') }
  ]

  private stageContentWidth(): number {
    if (isTablet(this.pageWidth)) return 760
    if (this.pageWidth > 0) return this.pageWidth
    return 360
  }

  private centeredX(itemWidth: number): number {
    return Math.max(0, Math.floor((this.stageContentWidth() - itemWidth) / 2))
  }

  private openChatHistory(): void {
    this.pathStack.pushPathByName('ChatHistory', null)
  }

  private syncNameFromWakeWord(): void {
    const name: string = this.wakeWord.trim()
    if (name.length > 0 && this.petName !== name) this.petName = name
  }

  private getPetDisplayName(): string {
    const wakeName: string = this.wakeWord.trim()
    if (wakeName.length > 0) return wakeName
    const petName: string = this.petName.trim()
    return petName.length > 0 ? petName : '小E'
  }

  private clearPetLottieTimer(): void {
    if (this.petLottieTimer >= 0) {
      clearTimeout(this.petLottieTimer)
      this.petLottieTimer = -1
    }
  }

  private clearSceneLottieTimer(): void {
    if (this.sceneLottieTimer >= 0) {
      clearTimeout(this.sceneLottieTimer)
      this.sceneLottieTimer = -1
    }
  }

  private syncIdlePetLottie(): void {
    let nextName: string = ''
    if (this.isPetSpeaking) {
      nextName = this.currentVoiceMode === 'chat' ? 'Flirting Dog' : 'Happy Dog'
    } else if (this.currentVoiceMode === 'chat' &&
      (this.isChatThinking || this.chatReplyBubbleVisible || this.isAsrConnected || this.appAsrStarted)) {
      nextName = 'Flirting Dog'
    } else if (this.isAmbientListening && this.isAsrConnected) {
      nextName = this.currentVoiceMode === 'chat' ? 'Flirting Dog' : 'Happy Dog'
    } else {
      nextName = this.petMood > 82 ? 'Happy Dog' : 'Smiling Dog'
    }
    if (this.petLottieName !== nextName) this.petLottieName = nextName
  }

  private playPetLottie(name: string, duration: number = 1500): void {
    this.clearPetLottieTimer()
    if (this.petLottieName !== name) this.petLottieName = name
    if (duration > 0) {
      this.petLottieTimer = setTimeout((): void => {
        this.syncIdlePetLottie()
      }, duration)
    }
  }

  private showSceneLottie(name: string, duration: number = 1800): void {
    this.clearSceneLottieTimer()
    if (this.sceneLottieName !== name) this.sceneLottieName = name
    if (duration > 0) {
      this.sceneLottieTimer = setTimeout((): void => {
        this.sceneLottieName = ''
      }, duration)
    }
  }

  private stopSceneLottie(): void {
    this.clearSceneLottieTimer()
    this.sceneLottieName = ''
  }

  private clearChatReplyBubbleTimers(): void {
    if (this.chatReplyBubbleHideTimer >= 0) {
      clearTimeout(this.chatReplyBubbleHideTimer)
      this.chatReplyBubbleHideTimer = -1
    }
    if (this.chatReplyBubbleFadeTimer >= 0) {
      clearTimeout(this.chatReplyBubbleFadeTimer)
      this.chatReplyBubbleFadeTimer = -1
    }
  }

  private resetChatReplyBubble(): void {
    this.clearChatReplyBubbleTimers()
    this.chatReplyText = ''
    this.chatReplyBubbleVisible = false
    this.chatReplyBubbleOpacity = 0
    this.chatReplyBubbleTranslateY = 10
  }

  private showChatReplyBubble(): void {
    this.clearChatReplyBubbleTimers()
    if (!this.chatReplyBubbleVisible) {
      this.chatReplyBubbleVisible = true
      this.chatReplyBubbleOpacity = 0
      this.chatReplyBubbleTranslateY = 10
    }
    animateTo({ duration: 280, curve: Curve.EaseOut }, (): void => {
      this.chatReplyBubbleOpacity = 1
      this.chatReplyBubbleTranslateY = 0
    })
  }

  private hideChatReplyBubble(delay: number = 900): void {
    if (!this.chatReplyBubbleVisible) return
    if (this.chatReplyBubbleHideTimer >= 0) clearTimeout(this.chatReplyBubbleHideTimer)
    this.chatReplyBubbleHideTimer = setTimeout((): void => {
      this.chatReplyBubbleHideTimer = -1
      animateTo({ duration: 520, curve: Curve.EaseInOut }, (): void => {
        this.chatReplyBubbleOpacity = 0
        this.chatReplyBubbleTranslateY = -8
      })
      this.chatReplyBubbleFadeTimer = setTimeout((): void => {
        this.chatReplyBubbleFadeTimer = -1
        this.chatReplyBubbleVisible = false
        this.chatReplyText = ''
        this.chatReplyBubbleTranslateY = 10
      }, 540)
    }, delay)
  }

  private getChatReplyBubbleText(): string {
    const text: string = this.chatReplyText.trim()
    const maxLength: number = isTablet(this.pageWidth) ? 220 : 150
    if (text.length <= maxLength) return text
    return `...${text.substring(text.length - maxLength)}`
  }

  private playActionLottie(actionId: string): void {
    switch (actionId) {
      case 'feed':
        this.playPetLottie('Happy Dog', 1600)
        this.stopSceneLottie()
        break
      case 'play':
        this.playPetLottie('Flirting Dog', 1600)
        this.stopSceneLottie()
        break
      case 'clean':
        this.playPetLottie('Happy Dog', 1600)
        this.showSceneLottie('sunshine', 1600)
        break
      case 'sleep':
        this.playPetLottie('Smiling Dog', 1600)
        this.stopSceneLottie()
        break
      case 'praise':
        this.playPetLottie('Happt_Dog_With_Love', 1800)
        this.stopSceneLottie()
        break
      case 'dress':
        this.playPetLottie('Happy Unicorn Dog', 2200)
        this.stopSceneLottie()
        break
      case 'name':
        this.playPetLottie('Smiling Dog', 1500)
        this.showSceneLottie('register_lottie', 1500)
        break
      case 'reset':
        this.playPetLottie('Smiling Dog', 1200)
        this.stopSceneLottie()
        break
      default:
        this.stopSceneLottie()
        this.syncIdlePetLottie()
        break
    }
  }

  private playTouchLottie(area: string): void {
    switch (area) {
      case 'head':
        this.playPetLottie('Flirting Dog', 1200)
        break
      case 'belly':
        this.playPetLottie('Happy Dog', 1300)
        this.showSceneLottie('sunshine', 1300)
        break
      case 'tail':
        this.playPetLottie('Angry Dog', 1400)
        this.stopSceneLottie()
        break
      case 'feet':
        this.playPetLottie('Angry Dog', 1200)
        break
      default:
        this.playPetLottie('Smiling Dog', 900)
        break
    }
  }

  @Builder
  private PetLottieBuilder() {
    if (this.petLottieName === 'Happy Unicorn Dog') {
      LottieView({ name: 'Happy Unicorn Dog' }).width('100%').height('100%')
    } else if (this.petLottieName === 'Happt_Dog_With_Love') {
      LottieView({ name: 'Happt_Dog_With_Love' }).width('100%').height('100%')
    } else if (this.petLottieName === 'Happy Dog') {
      LottieView({ name: 'Happy Dog' }).width('100%').height('100%')
    } else if (this.petLottieName === 'Angry Dog') {
      LottieView({ name: 'Angry Dog' }).width('100%').height('100%')
    } else if (this.petLottieName === 'Flirting Dog') {
      LottieView({ name: 'Flirting Dog' }).width('100%').height('100%')
    } else if (this.petLottieName === 'pet_idle') {
      LottieView({ name: 'pet_idle' }).width('100%').height('100%')
    } else {
      LottieView({ name: 'Smiling Dog' }).width('100%').height('100%')
    }
  }

  @Builder
  private SceneLottieBuilder() {
    if (this.sceneLottieName === 'sunshine') {
      LottieView({ name: 'sunshine' }).width('100%').height('100%')
    } else if (this.sceneLottieName === 'loading') {
      LottieView({ name: 'loading' }).width('100%').height('100%')
    } else if (this.sceneLottieName === 'login_lottie') {
      LottieView({ name: 'login_lottie' }).width('100%').height('100%')
    } else if (this.sceneLottieName === 'register_lottie') {
      LottieView({ name: 'register_lottie' }).width('100%').height('100%')
    }
  }

  @Builder
  private ChatReplyBubbleBuilder() {
    Column({ space: 0 }) {
      Column({ space: 6 }) {
        Text(this.getPetDisplayName())
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .maxLines(1)

        Text(this.getChatReplyBubbleText())
          .fontSize(14)
          .lineHeight(21)
          .fontColor($r('app.color.text_primary'))
          .maxLines(isTablet(this.pageWidth) ? 6 : 5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.surface_card'))
      .border({ width: 1, color: $r('app.color.surface_border') })
      .borderRadius(18)
      .shadow(AppShadow.card)

      Row()
        .width(16)
        .height(16)
        .backgroundColor($r('app.color.surface_card_solid'))
        .rotate({ angle: 45 })
        .translate({ y: -8 })
        .shadow(AppShadow.subtle)
    }
    .width(isTablet(this.pageWidth) ? 420 : 306)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.chatReplyBubbleOpacity)
    .translate({ y: this.chatReplyBubbleTranslateY })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  private isVoiceModeActive(mode: string): boolean {
    return this.currentVoiceMode === mode &&
      (this.isAmbientListening || this.appAsrConnecting || this.appAsrStarted ||
       this.isChatThinking || this.isPetSpeaking)
  }

  private async cancelVoiceMode(): Promise<void> {
    this.chatRequestVersion += 1
    this.isChatThinking = false
    await this.stopAmbientListening()
    await this.stopPhoneAudio()
    this.resetChatReplyBubble()
    this.petSpeech = '我先休息一下，想继续的时候再点我。'
    this.stopSceneLottie()
    this.refreshActiveAsrState()
    this.refreshActiveAsrState()
    this.syncIdlePetLottie()
    this.preconnectAsrServices()
  }

  private async toggleVoiceMode(mode: string): Promise<void> {
    if (this.isVoiceModeActive(mode)) {
      await this.cancelVoiceMode()
      return
    }
    if (this.currentVoiceMode !== 'idle' && this.currentVoiceMode !== mode) {
      this.chatRequestVersion += 1
      this.isChatThinking = false
      await this.stopPhoneAudio()
    }
    await this.startAmbientListening(mode)
  }

  private getAsrWs(mode: string): webSocket.WebSocket | null {
    return mode === 'chat' ? this.chatAsrWs : this.repeatAsrWs
  }

  private setAsrWs(mode: string, ws: webSocket.WebSocket | null): void {
    if (mode === 'chat') this.chatAsrWs = ws
    else this.repeatAsrWs = ws
  }

  private isAsrModeConnected(mode: string): boolean {
    return mode === 'chat' ? this.chatAsrConnected : this.repeatAsrConnected
  }

  private setAsrModeConnected(mode: string, connected: boolean): void {
    if (mode === 'chat') this.chatAsrConnected = connected
    else this.repeatAsrConnected = connected
  }

  private isAsrModeConnecting(mode: string): boolean {
    return mode === 'chat' ? this.chatAsrConnecting : this.repeatAsrConnecting
  }

  private setAsrModeConnecting(mode: string, connecting: boolean): void {
    if (mode === 'chat') this.chatAsrConnecting = connecting
    else this.repeatAsrConnecting = connecting
  }

  private refreshActiveAsrState(): void {
    if (this.currentVoiceMode === 'chat' || this.currentVoiceMode === 'repeat') {
      this.appAsrWs = this.getAsrWs(this.currentVoiceMode)
      this.isAsrConnected = this.isAsrModeConnected(this.currentVoiceMode)
      this.appAsrConnecting = this.isAsrModeConnecting(this.currentVoiceMode)
      this.appAsrStarted = this.isAsrConnected || this.appAsrConnecting
      return
    }
    this.appAsrWs = null
    this.isAsrConnected = false
    this.appAsrConnecting = false
    this.appAsrStarted = false
  }

  private ensureAsrConnection(mode: string): void {
    if (this.isAsrModeConnected(mode) || this.isAsrModeConnecting(mode)) return

    this.setAsrModeConnecting(mode, true)
    if (this.currentVoiceMode === mode) this.refreshActiveAsrState()

    const wsUrl: string = `ws://${this.localhost}:8080/app-asr?account=${this.account}&mode=${mode}`
    const ws: webSocket.WebSocket = webSocket.createWebSocket()
    this.setAsrWs(mode, ws)

    ws.on('open', async (): Promise<void> => {
      this.setAsrModeConnecting(mode, false)
      this.setAsrModeConnected(mode, true)
      if (this.currentVoiceMode === mode) {
        this.refreshActiveAsrState()
        this.asrStatusText = mode === 'chat' ? '聊天模式：正在听你说话' : '学话模式：正在听你说话'
        await this.startAmbientCapture(mode)
      }
    })

    ws.on('message', (err, value): void => {
      if (err) {
        console.error(`App ASR ${mode} message failed:`, JSON.stringify(err))
        return
      }
      if (typeof value === 'string') this.handleAsrServerMessage(value, mode)
    })

    ws.on('error', (err): void => {
      console.error(`App ASR ${mode} websocket error: ${err.message}`)
      this.setAsrModeConnecting(mode, false)
      this.setAsrModeConnected(mode, false)
      if (this.currentVoiceMode === mode) {
        this.asrStatusText = '语音识别服务连接失败'
        this.refreshActiveAsrState()
        this.stopSceneLottie()
        this.syncIdlePetLottie()
      }
    })

    ws.on('close', (): void => {
      this.setAsrModeConnecting(mode, false)
      this.setAsrModeConnected(mode, false)
      if (this.getAsrWs(mode) === ws) this.setAsrWs(mode, null)
      if (this.currentVoiceMode === mode) {
        this.isAmbientListening = false
        this.isPetSpeaking = false
        this.asrStatusText = this.currentVoiceMode === 'idle' ? '语音监听未开启' : '语音监听已断开'
        this.refreshActiveAsrState()
        this.stopSceneLottie()
        this.syncIdlePetLottie()
      }
      if (this.keepAsrAlive) {
        setTimeout((): void => this.ensureAsrConnection(mode), 1200)
      }
    })

    ws.connect(wsUrl, (err): void => {
      if (err) {
        console.error(`App ASR ${mode} websocket connect failed: ${err.message}`)
        this.setAsrModeConnecting(mode, false)
        this.setAsrModeConnected(mode, false)
        if (this.currentVoiceMode === mode) {
          this.asrStatusText = '语音识别服务连接失败'
          this.currentVoiceMode = 'idle'
          this.refreshActiveAsrState()
          this.stopSceneLottie()
          this.syncIdlePetLottie()
        }
        if (this.keepAsrAlive) {
          setTimeout((): void => this.ensureAsrConnection(mode), 1200)
        }
      }
    })
  }

  private preconnectAsrServices(): void {
    this.keepAsrAlive = true
    this.ensureAsrConnection('repeat')
    this.ensureAsrConnection('chat')
  }

  private closeAsrConnections(): void {
    this.keepAsrAlive = false
    const repeatWs: webSocket.WebSocket | null = this.repeatAsrWs
    const chatWs: webSocket.WebSocket | null = this.chatAsrWs
    this.repeatAsrWs = null
    this.chatAsrWs = null
    this.repeatAsrConnecting = false
    this.chatAsrConnecting = false
    this.repeatAsrConnected = false
    this.chatAsrConnected = false
    try { repeatWs?.close() } catch (err) {}
    try { chatWs?.close() } catch (err) {}
    this.refreshActiveAsrState()
  }

  aboutToAppear(): void {
    this.syncNameFromWakeWord()
    this.petSpeech = this.petLastPhrase.length > 0 ? `上次你说：${this.petLastPhrase}` : '说点什么，我会学你说一遍。'
    this.syncIdlePetLottie()
  }

  aboutToDisappear(): void {
    this.stopAmbientListening()
    this.stopPhoneAudio()
    this.closeAsrConnections()
    this.isPetSpeaking = false
    this.resetChatReplyBubble()
    this.clearPetLottieTimer()
    this.stopSceneLottie()
  }

  private startBubbleFloatAnimation() {
    animateTo({ duration: 2000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.bubbleFloatY = -6
    })
  }

  private startMicPulseAnimation() {
    this.micPulseScale = 1.12
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
      console.error('Pet page microphone permission failed:', JSON.stringify(err))
      return false
    }
  }

  private async startAmbientCapture(mode: string): Promise<void> {
    if (this.currentVoiceMode !== mode || !this.isAsrModeConnected(mode)) return
    if (this.ambientService.isActive()) {
      this.isAmbientListening = true
      this.startMicPulseAnimation()
      return
    }
    try {
      await this.ambientService.start((pcm: ArrayBuffer): void => {
        this.sendAmbientPcm(pcm)
      })
      this.isAmbientListening = true
      this.startMicPulseAnimation()
    } catch (err) {
      console.error('Start ambient listening failed:', JSON.stringify(err))
      this.asrStatusText = '麦克风启动失败'
      this.isAmbientListening = false
    }
  }

  private async startAmbientListening(mode: string): Promise<void> {
    if (this.isAmbientListening && this.currentVoiceMode === mode) {
      this.petSpeech = mode === 'chat' ? '我已经在听你聊天啦。' : '我已经在听，准备学你说话。'
      return
    }

    if (this.isAmbientListening && this.currentVoiceMode !== mode) {
      this.currentVoiceMode = mode
    }

    const granted: boolean = await this.ensureMicrophonePermission()
    if (!granted) {
      this.asrStatusText = '未获得麦克风权限'
      this.petSpeech = '我需要麦克风权限，才能听到你的声音。'
      this.currentVoiceMode = 'idle'
      return
    }

    this.currentVoiceMode = mode
    this.appAsrConnecting = true
    this.asrStatusText = mode === 'chat' ? '聊天模式：正在连接识别服务' : '学话模式：正在连接识别服务'
    this.petSpeech = mode === 'chat' ? '陪我聊天开启啦，说一句我来回应你。' : '学我说话开启啦，我会让设备端复读你说的话。'
    this.playPetLottie(mode === 'chat' ? 'Flirting Dog' : 'Happy Dog', 0)
    if (mode === 'chat') this.showSceneLottie('login_lottie', 1400)
    else this.stopSceneLottie()
    this.ensureAsrConnection(mode)
    this.refreshActiveAsrState()
    if (this.isAsrModeConnected(mode)) {
      this.asrStatusText = mode === 'chat' ? '聊天模式：正在听你说话' : '学话模式：正在听你说话'
      await this.startAmbientCapture(mode)
    }
  }

  private sendAmbientPcm(pcm: ArrayBuffer): void {
    const ws: webSocket.WebSocket | null = this.getAsrWs(this.currentVoiceMode)
    if (!ws || !this.isAsrModeConnected(this.currentVoiceMode) || pcm.byteLength === 0) return
    ws.send(pcm, (err): void => {
      if (err) console.error('Send ambient PCM failed:', JSON.stringify(err))
    })
  }

  private async stopAmbientListening(clearMode: boolean = true): Promise<void> {
    this.appAsrConnecting = false
    this.appAsrStarted = false
    this.isAmbientListening = false
    this.micPulseScale = 1
    this.stopSceneLottie()

    try { await this.ambientService.stop() } catch (err) {
      console.error('Stop ambient listening failed:', JSON.stringify(err))
    }

    if (clearMode) {
      this.currentVoiceMode = 'idle'
      this.asrStatusText = '语音监听未开启'
    }
    this.refreshActiveAsrState()
    this.syncIdlePetLottie()
  }

  private handleAsrServerMessage(message: string, mode: string = this.currentVoiceMode): void {
    try {
      const event = JSON.parse(message) as Record<string, string>
      const type: string = event.type || ''
      if (mode !== this.currentVoiceMode) return
      if (type === 'ready') {
        this.asrStatusText = this.currentVoiceMode === 'chat' ? '聊天模式：正在听你说话' : '学话模式：正在听你说话'
        this.playPetLottie(this.currentVoiceMode === 'chat' ? 'Flirting Dog' : 'Happy Dog', 0)
        return
      }
      if (type === 'asr') {
        const text: string = event.text || ''
        if (text.length === 0) return
        this.recognizedText = text
        this.petLastPhrase = text
        this.popReaction('ASR')
        if (this.currentVoiceMode === 'chat') this.handleChatRecognizedText(text)
        else this.petSpeech = `识别到：${text}`
        return
      }
      if (type === 'tts') {
        this.isPetSpeaking = event.state === 'start'
        if (event.state === 'start') {
          this.playPetLottie(this.currentVoiceMode === 'chat' ? 'Flirting Dog' : 'Happy Dog', 0)
          this.stopSceneLottie()
        } else {
          this.syncIdlePetLottie()
        }
        this.asrStatusText = event.state === 'start' ? '设备端正在复读' : '学话模式：正在听你说话'
        return
      }
      if (type === 'device') {
        this.asrStatusText = event.state === 'offline' ? '设备端音频未连接' : this.asrStatusText
        return
      }
      if (type === 'error') {
        this.isPetSpeaking = false
        this.asrStatusText = event.message || '语音识别异常'
        this.stopSceneLottie()
        this.syncIdlePetLottie()
      }
    } catch (err) {
      console.info('App ASR server:', message)
    }
  }

  private async handleChatRecognizedText(text: string): Promise<void> {
    if (this.isChatThinking) return
    const requestVersion: number = ++this.chatRequestVersion
    this.isChatThinking = true
    this.resetChatReplyBubble()
    this.petSpeech = `你说：${text}`
    this.asrStatusText = '正在发送给扣子'
    await this.stopAmbientListening(false)

    try {
      await this.askCozeAndPlay(text, requestVersion)
    } catch (err) {
      console.error('Coze chat failed:', JSON.stringify(err))
      this.resetChatReplyBubble()
      this.petSpeech = '扣子回复失败了，等一下再聊。'
      this.asrStatusText = '扣子回复失败'
    } finally {
      if (requestVersion !== this.chatRequestVersion) return
      this.isChatThinking = false
      if (this.currentVoiceMode === 'chat') {
        setTimeout((): void => {
          this.startAmbientListening('chat')
        }, 700)
      } else {
        this.stopSceneLottie()
        this.syncIdlePetLottie()
      }
    }
  }

  private askCozeAndPlay(question: string, requestVersion: number): Promise<void> {
    return new Promise<void>((resolve) => {
      let fullReply: string = ''
      let finished: boolean = false
      const botId: string = '7534905232841785370'

      const inputPayload: CozeContentPayload = {
        question,
        voice_id: this.normalizeVoiceId(this.voiceId),
        speed_ratio: this.speedRatio || 1.0
      }

      const closeOnce = async (): Promise<void> => {
        if (finished) return
        finished = true
        if (requestVersion !== this.chatRequestVersion) {
          resolve()
          return
        }
        this.chatReplyText = fullReply

        if (fullReply.trim().length > 0) {
          this.showChatReplyBubble()
          this.saveChatRecord(question, fullReply)
          this.asrStatusText = '手机正在播放扣子回复'
          await this.playPhoneAudio(this.buildPhoneTtsUrl(fullReply))
          this.hideChatReplyBubble(900)
          this.asrStatusText = '聊天模式：准备继续听你说话'
        } else {
          this.asrStatusText = '扣子没有返回可播报内容'
          this.hideChatReplyBubble(0)
        }
        resolve()
      }

      setTimeout((): void => { closeOnce() }, 26000)

      this.ensureCozeConversationId(botId)
        .then((conversationId: string): void => {
          if (requestVersion !== this.chatRequestVersion) {
            closeOnce()
            return
          }

          const params: CozeRequestParams = {
            bot_id: botId,
            user: `petdog_user_${this.account || 0}`,
            query: JSON.stringify(inputPayload),
            stream: true,
            conversation_id: conversationId.length > 0 ? conversationId : undefined
          }

          this.coze.sendMessage(params, (msg: CozeMessage): void => {
            if (requestVersion !== this.chatRequestVersion) return
            const content: string = msg.message?.content || ''
            if (msg.conversation_id && msg.conversation_id.length > 0 && msg.conversation_id !== this.cozeConversationId) {
              this.cozeConversationId = msg.conversation_id
              AppStorage.setOrCreate('cozeConversationId', msg.conversation_id)
            }
            if (content.length > 0) {
              fullReply += content
              this.chatReplyText = fullReply
              this.showChatReplyBubble()
            }
            if (msg.is_finish) closeOnce()
          })
        })
        .catch((): void => {
          this.asrStatusText = '扣子会话创建失败'
          return
        })
    })
  }

  private async ensureCozeConversationId(botId: string): Promise<string> {
    const currentId: string = this.cozeConversationId.trim()
    if (currentId.length > 0) return currentId

    const createdId: string = await this.coze.createConversation(botId)
    if (createdId.length > 0) {
      this.cozeConversationId = createdId
      AppStorage.setOrCreate('cozeConversationId', createdId)
    }
    return createdId
  }

  private saveChatRecord(question: string, reply: string): void {
    if (question.trim().length === 0 || reply.trim().length === 0) return
    ConversationUtil.addConversation(this.account || 0, question, reply)
      .then((): void => {})
      .catch((): void => { console.error('Save chat history failed') })
  }

  private buildPhoneTtsUrl(text: string): string {
    const speechText: string = text.length > 500 ? text.substring(0, 500) : text
    const query: string = `text=${encodeURIComponent(speechText)}` +
      `&voiceId=${encodeURIComponent(this.normalizeVoiceId(this.voiceId))}` +
      `&speedRatio=${encodeURIComponent(String(this.speedRatio || 1.0))}` +
      '&volume=80'
    return `http://${this.localhost}:8080/api/tts/phone?${query}`
  }

  private normalizeVoiceId(voiceId: string): string {
    return normalizeXfyunVoiceId(voiceId)
  }

  private async playPhoneAudio(url: string): Promise<void> {
    await this.stopPhoneAudio()
    const player: media.AVPlayer = await media.createAVPlayer()
    this.phonePlayer = player
    this.isPetSpeaking = true
    this.playPetLottie('Flirting Dog', 0)

    return new Promise<void>((resolve) => {
      let resolved: boolean = false
      const done = async (): Promise<void> => {
        if (resolved) return
        resolved = true
        this.isPetSpeaking = false
        this.syncIdlePetLottie()
        try { await player.release() } catch (err) {}
        if (this.phonePlayer === player) this.phonePlayer = null
        resolve()
      }

      player.on('error', (err): void => {
        console.error('Phone audio playback failed:', JSON.stringify(err))
        done()
      })

      player.on('stateChange', async (state: string): Promise<void> => {
        if (state === 'initialized') {
          await player.prepare()
        } else if (state === 'prepared') {
          this.isPetSpeaking = true
          this.playPetLottie('Flirting Dog', 0)
          await player.play()
        } else if (state === 'completed' || state === 'stopped' || state === 'released') {
          await done()
        }
      })

      player.url = url
    })
  }

  private async stopPhoneAudio(): Promise<void> {
    if (!this.phonePlayer) return
    const player: media.AVPlayer = this.phonePlayer
    this.phonePlayer = null
    this.isPetSpeaking = false
    this.syncIdlePetLottie()
    try { await player.stop() } catch (err) {}
    try { await player.release() } catch (err) {}
  }

  private clamp(value: number): number { return Math.max(0, Math.min(100, Math.round(value))) }

  private getMoodText(): string {
    if (this.petEnergy < 25) return '困了'
    if (this.petSatiety < 30) return '饿了'
    if (this.petClean < 30) return '脏脏'
    if (this.petMood > 82) return '兴奋'
    return '在线'
  }

  private getMoodChips(): MoodChip[] {
    return [
      { label: '心情', value: `${this.petMood}`,     color: $r('app.color.brand_primary'),     icon: $r('app.media.pet_stat_mood') },
      { label: '饱食', value: `${this.petSatiety}`, color: $r('app.color.state_success'),     icon: $r('app.media.pet_stat_satiety') },
      { label: '亲密', value: `${this.petIntimacy}`, color: $r('app.color.pet_action_praise'), icon: $r('app.media.pet_stat_intimacy') }
    ]
  }

  private popReaction(icon: string): void {
    this.reactionIcon = icon
    animateTo({ duration: 120, curve: Curve.EaseOut }, (): void => {
      this.reactionOpacity = 1
      this.stageBounce = -10
    })
    setTimeout((): void => {
      animateTo({ duration: 260, curve: Curve.EaseOut }, (): void => {
        this.reactionOpacity = 0
        this.stageBounce = 0
      })
    }, 650)
  }

  private animatePet(scale: number, rotate: number, translateY: number): void {
    animateTo({ duration: 130, curve: Curve.EaseOut }, (): void => {
      this.petScale = scale
      this.petRotate = rotate
      this.petTranslateY = translateY
    })
    setTimeout((): void => {
      animateTo({ duration: 230, curve: Curve.EaseOut }, (): void => {
        this.petScale = 1
        this.petRotate = 0
        this.petTranslateY = 0
      })
    }, 180)
  }

  private finishInteraction(message: string, icon: string, mood: number, intimacy: number, energy: number, satiety: number, clean: number): void {
    this.petMood = this.clamp(this.petMood + mood)
    this.petIntimacy = this.clamp(this.petIntimacy + intimacy)
    this.petEnergy = this.clamp(this.petEnergy + energy)
    this.petSatiety = this.clamp(this.petSatiety + satiety)
    this.petClean = this.clamp(this.petClean + clean)
    this.petCareCount += 1
    this.petSpeech = message
    this.popReaction(icon)
  }

  private handleAction(id: string): void {
    this.playActionLottie(id)
    switch (id) {
      case 'talk':
        this.petSpeech = '我在听，下面输入一句话吧。'
        this.popReaction('SAY')
        break
      case 'feed':
        this.animatePet(1.08, -4, -2)
        this.finishInteraction('好吃！我还能再吃一口。', 'YUM', 7, 2, 4, 18, -2)
        break
      case 'play':
        this.animatePet(1.1, 6, -12)
        this.finishInteraction('嘿嘿，再来一次！', 'HA', 14, 6, -8, -5, -1)
        break
      case 'clean':
        this.animatePet(1.04, 0, -4)
        this.finishInteraction('干净清爽，心情都亮了。', 'OK', 6, 3, 2, 0, 24)
        break
      case 'sleep':
        this.animatePet(0.96, 0, 8)
        this.finishInteraction('我眯一会儿，醒来继续陪你。', 'ZZZ', 2, 1, 20, -2, 0)
        break
      case 'praise':
        this.animatePet(1.12, -6, -10)
        this.finishInteraction('夸得我尾巴都想摇起来啦！', 'LOVE', 14, 10, -2, -1, 0)
        break
      case 'dress':
        this.animatePet(1.08, 6, -8)
        this.finishInteraction('新造型准备好啦，今天也要可可爱爱。', 'NEW', 10, 7, -1, 0, 0)
        break
      case 'name':
        this.tempPetName = this.petName
        this.showNameDialog = true
        break
      case 'reset':
        this.petMood = 76
        this.petSatiety = 72
        this.petEnergy = 68
        this.petClean = 70
        this.petIntimacy = Math.max(18, this.petIntimacy)
        this.petSpeech = '我又精神起来了。'
        this.animatePet(1.06, 0, -6)
        this.popReaction('OK')
        break
    }
  }

  private touchPet(area: string): void {
    this.playTouchLottie(area)
    switch (area) {
      case 'head':
        this.animatePet(1.06, -3, -4)
        this.finishInteraction('摸头可以，但别把发型弄乱哦。', 'HI', 8, 6, -1, 0, 0)
        break
      case 'belly':
        this.animatePet(1.12, 5, -8)
        this.finishInteraction('哈哈，肚子那里很痒！', 'HA', 12, 7, -4, -2, 0)
        break
      case 'tail':
        this.animatePet(1.03, 8, -4)
        this.finishInteraction('尾巴很敏感，别一直戳啦！', 'HEY', -4, -2, -1, 0, 0)
        break
      case 'feet':
        this.animatePet(1.04, -7, -5)
        this.finishInteraction('脚脚被点到啦，我要躲一下。', 'HEY', 6, 3, -2, 0, 0)
        break
      default:
        this.animatePet(1.05, 0, -5)
        this.finishInteraction('你摸到我身上啦，舒服。', 'HI', 5, 4, -1, 0, 0)
        break
    }
  }

  private repeatText(): void {
    const phrase: string = this.talkText.trim()
    if (phrase.length === 0) {
      promptAction.showToast({ message: '说一句话试试' })
      return
    }
    const shortPhrase: string = phrase.length > 32 ? phrase.substring(0, 32) : phrase
    this.petLastPhrase = shortPhrase
    this.petSpeech = `${this.petName}学着说：${shortPhrase}`
    this.talkText = ''
    this.animatePet(1.12, 4, -10)
    this.finishInteraction(`${this.petName}学着说：${shortPhrase}`, 'SAY', 10, 8, -3, -1, 0)
  }

  private async confirmName(): Promise<void> {
    const name: string = this.tempPetName.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: '名字不能为空' })
      return
    }
    const unifiedName: string = name.length > 8 ? name.substring(0, 8) : name
    this.petName = unifiedName
    this.wakeWord = unifiedName
    this.showNameDialog = false
    this.finishInteraction(`记住啦，我叫${this.petName}！`, 'OK', 6, 8, 0, 0, 0)
    if (this.account && this.account !== 0) {
      const result = await UpdateWakeWordUtil.updateWakeWord(this.account, unifiedName)
      if (!result.success) {
        console.warn(`Update wake word failed after pet rename: ${result.msg}`)
      }
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {
        // 1. 背景：上浅下深的陪伴空间
        Column() {
          Row()
            .width('100%')
            .height('58%')
            .backgroundColor($r('app.color.pet_room_bg_top'))

          Row()
            .width('100%')
            .height('42%')
            .backgroundColor($r('app.color.pet_room_bg_bottom'))
        }
        .width('100%')
        .height('100%')

        // 2. 顶部状态栏（心情/饱食/亲密 + 聊天历史入口）
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            ForEach(this.getMoodChips(), (item: MoodChip): void => {
              MoodPill({
                label: item.label,
                value: item.value,
                color: item.color,
                icon: item.icon
              })
                .layoutWeight(1)
            }, (item: MoodChip): string => item.label)
          }
          .width('100%')

          Row() {
            ChatHistoryEntryButton({
              onTap: (): void => { this.openChatHistory() }
            })
          }
          .width('100%')
          .height(28)
          .padding({ left: 2 })
          .justifyContent(FlexAlign.Start)
        }
        .width(isTablet(this.pageWidth) ? 760 : '100%')
        .padding({
          left: isTablet(this.pageWidth) ? 0 : 14,
          right: isTablet(this.pageWidth) ? 0 : 14,
          top: isTablet(this.pageWidth) ? 20 : 34
        })
        .align(Alignment.Top)
        .zIndex(20)

        // 3. 宠物舞台（决定性区域：Lottie + 触摸感应区）
        Stack({ alignContent: Alignment.Center }) {
          // 地面光晕
          Ellipse()
            .width(isTablet(this.pageWidth) ? 620 : 420)
            .height(isTablet(this.pageWidth) ? 260 : 210)
            .fill('#9A51D0BD')
            .align(Alignment.Bottom)
            .translate({ y: isTablet(this.pageWidth) ? -46 : -32 })

          Circle()
            .width(isTablet(this.pageWidth) ? 92 : 72)
            .height(isTablet(this.pageWidth) ? 92 : 72)
            .fill('#94FFB75E')
            .align(Alignment.BottomStart)
            .translate({ x: isTablet(this.pageWidth) ? 98 : 48, y: isTablet(this.pageWidth) ? -182 : -124 })

          Circle()
            .width(isTablet(this.pageWidth) ? 116 : 92)
            .height(isTablet(this.pageWidth) ? 116 : 92)
            .fill('#9B55A6E8')
            .align(Alignment.BottomEnd)
            .translate({ x: isTablet(this.pageWidth) ? -104 : -50, y: isTablet(this.pageWidth) ? -176 : -118 })

          // 宠物脚下阴影
          Ellipse()
            .width(isTablet(this.pageWidth) ? 300 : 224)
            .height(isTablet(this.pageWidth) ? 44 : 34)
            .fill('#1F102040')
            .position({ x: '50%', y: isTablet(this.pageWidth) ? 486 : 428 })
            .translate({ x: '-50%' })

          // 反应小气泡
          if (this.reactionIcon.length > 0) {
            Text(this.reactionIcon)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius(20)
              .shadow(AppShadow.button)
              .opacity(this.reactionOpacity)
              .position({
                x: this.centeredX(isTablet(this.pageWidth) ? 330 : 260) + (isTablet(this.pageWidth) ? 235 : 170),
                y: (isTablet(this.pageWidth) ? 210 : 190) + this.stageBounce
              })
              .zIndex(10)
          }

          // Lottie 容器
          Stack() {
            if (this.sceneLottieName.length > 0) {
              this.SceneLottieBuilder()
            }
            this.PetLottieBuilder()

            if (this.chatReplyBubbleVisible && this.chatReplyText.trim().length > 0) {
              Stack() {
                this.ChatReplyBubbleBuilder()
              }
              .width(isTablet(this.pageWidth) ? 420 : 306)
              .align(Alignment.Top)
              .translate({ y: isTablet(this.pageWidth) ? -170 : -148 })
              .zIndex(4)
            }
          }
          .width(isTablet(this.pageWidth) ? 380 : 300)
          .height(isTablet(this.pageWidth) ? 380 : 300)
          .scale({ x: this.petScale, y: this.petScale })
          .rotate({ angle: this.petRotate })
          .translate({ y: this.petTranslateY + this.stageBounce + (isTablet(this.pageWidth) ? 98 : 88) })
          .animation({ duration: 220, curve: Curve.EaseOut })
          .onClick((): void => this.touchPet('body'))

          // 透明触摸感应区
          Column()
            .width(132)
            .height(82)
            .position({ x: this.centeredX(132), y: isTablet(this.pageWidth) ? 274 : 248 })
            .backgroundColor('#00FFFFFF')
            .onClick((): void => this.touchPet('head'))

          Column()
            .width(148)
            .height(84)
            .position({ x: this.centeredX(148), y: isTablet(this.pageWidth) ? 364 : 332 })
            .backgroundColor('#00FFFFFF')
            .onClick((): void => this.touchPet('belly'))

          Column()
            .width(isTablet(this.pageWidth) ? 150 : 126)
            .height(isTablet(this.pageWidth) ? 150 : 126)
            .position({
              x: this.centeredX(isTablet(this.pageWidth) ? 380 : 300) - (isTablet(this.pageWidth) ? 20 : 12),
              y: isTablet(this.pageWidth) ? 366 : 326
            })
            .backgroundColor('#00FFFFFF')
            .onClick((): void => this.touchPet('tail'))

          Row()
            .width(178)
            .height(52)
            .position({ x: this.centeredX(178), y: isTablet(this.pageWidth) ? 470 : 420 })
            .backgroundColor('#00FFFFFF')
            .onClick((): void => this.touchPet('feet'))
        }
        .width(isTablet(this.pageWidth) ? 760 : '100%')
        .height('100%')
        .padding({
          top: isTablet(this.pageWidth) ? 140 : 100,
          bottom: isTablet(this.pageWidth) ? 280 : 320
        })
        .align(Alignment.Center)

        // 4. 底部：语音模式按钮 + 互动操作横向滚动
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            VoiceModeButton({
              title: '学我说话',
              subtitle: this.currentVoiceMode === 'repeat' && this.isAmbientListening ? '正在监听' : '识别后复读',
              active: this.isVoiceModeActive('repeat'),
              color: $r('app.color.state_success'),
              icon: $r('app.media.pet_mic'),
              onTap: (): void => { this.toggleVoiceMode('repeat') }
            })

            VoiceModeButton({
              title: '陪我聊天',
              subtitle: this.isChatThinking ? '正在回复' : '识别后互动',
              active: this.isVoiceModeActive('chat'),
              color: $r('app.color.brand_primary'),
              icon: $r('app.media.pet_chat'),
              onTap: (): void => { this.toggleVoiceMode('chat') }
            })
          }
          .width('100%')

          Scroll() {
            Row({ space: isTablet(this.pageWidth) ? 22 : 16 }) {
              ForEach(this.actions, (item: ActionItem): void => {
                RoundActionButton({
                  title: item.title,
                  icon: item.icon,
                  color: item.color,
                  onTap: (): void => this.handleAction(item.id)
                })
                  .width(isTablet(this.pageWidth) ? 88 : 76)
              }, (item: ActionItem): string => item.id)
            }
            .padding({
              left: isTablet(this.pageWidth) ? 18 : 14,
              right: isTablet(this.pageWidth) ? 18 : 14,
              top: 10,
              bottom: 8
            })
          }
          .width('100%')
          .height(isTablet(this.pageWidth) ? 132 : 118)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.surface_border') })
          .borderRadius(22)
          .shadow(AppShadow.card)
          .padding({ left: 2, right: 2 })
        }
        .width(isTablet(this.pageWidth) ? 760 : '100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .padding({
          left: isTablet(this.pageWidth) ? 0 : 12,
          right: isTablet(this.pageWidth) ? 0 : 12,
          bottom: isTablet(this.pageWidth) ? 12 : 24
        })
        .zIndex(6)

        // 5. 改名对话框
        if (this.showNameDialog) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.overlay_bg'))
              .onClick((): void => { this.showNameDialog = false })

            Column({ space: 24 }) {
              Text('给宠物起个新名字吧')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              TextInput({ text: this.tempPetName, placeholder: '输入可爱的新名字' })
                .width('100%')
                .height(52)
                .backgroundColor($r('app.color.input_bg'))
                .border({ width: 1, color: $r('app.color.input_border') })
                .borderRadius(14)
                .padding({ left: 16, right: 16 })
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .maxLength(8)
                .onChange((value: string): void => { this.tempPetName = value })

              Row({ space: 16 }) {
                Button('取消')
                  .layoutWeight(1)
                  .height(46)
                  .fontSize(16)
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.input_bg'))
                  .borderRadius(23)
                  .onClick((): void => { this.showNameDialog = false })

                Button('保存')
                  .layoutWeight(1)
                  .height(46)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.brand_primary'))
                  .shadow(AppShadow.button)
                  .borderRadius(23)
                  .onClick((): void => { this.confirmName() })
              }
              .width('100%')
            }
            .width('80%')
            .padding(28)
            .backgroundColor($r('app.color.surface_card_solid'))
            .borderRadius(28)
            .shadow(AppShadow.dialog)
          }
          .width('100%')
          .height('100%')
          .zIndex(99)
        }
      }
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        const height: number = Number(newValue.height)
        if (!Number.isNaN(width)) this.pageWidth = width
        if (!Number.isNaN(height)) this.pageHeight = height
      })
    }
    .hideTitleBar(true)
    .onAppear((): void => {
      this.syncNameFromWakeWord()
      this.micPulseScale = 1
      this.asrStatusText = '语音监听未开启'
    })
    .onDisAppear((): void => {
      this.stopAmbientListening()
      this.stopPhoneAudio()
      this.closeAsrConnections()
      this.isPetSpeaking = false
      this.clearPetLottieTimer()
      this.stopSceneLottie()
    })
  }
}
