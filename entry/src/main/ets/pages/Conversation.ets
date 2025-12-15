import { font } from "@kit.ArkUI"
import { CozeService, CozeMessage, CozeRequestParams } from '../utils/CozeUtil'
import { ConversationUtil, ConversationRecord } from '../utils/ConversationUtil'
import promptAction from '@ohos.promptAction'

interface Message {
  from: string
  text: string
}

interface CozeContentPayload {
  question: string;
  voice_id: string;
  speed_ratio: number;
}

@Builder
export function ConversationBuilder() {
  Conversation()
}

@Component
export struct Conversation {
  private coze = new CozeService()
  @State messages: Message[] = []
  @State inputText: string = ''

  // ================= 状态链接 =================
  @StorageLink('account') account: number = 0
  @StorageLink('isLogin') isLogin: boolean = false
  @StorageLink('avatar') avatar: number | string = 1
  @StorageLink('voiceId') voiceId: string = '7568423452617605174'
  @StorageLink('speedRatio') speedRatio: number = 1.0

  @State isBotReplying: boolean = false

  private scroller: Scroller = new Scroller()
  pathStack: NavPathStack = new NavPathStack()
  private silenceTimer: number = -1

  private localAvatarList: Array<ResourceStr> = [
    $r('app.media.avatar0'), $r('app.media.avatar1'), $r('app.media.avatar2'), $r('app.media.avatar3')
  ]

  private getAvatarSrc(): ResourceStr | string {
    if (!this.isLogin) return this.localAvatarList[0];
    if (typeof this.avatar === 'string' && this.avatar.length > 0) return this.avatar;
    else if (typeof this.avatar === 'number') return this.localAvatarList[this.avatar] || this.localAvatarList[0];
    return this.localAvatarList[0];
  }

  async aboutToAppear() {
    try {
      font.registerFont({ familyName: 'alibaba', familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf') })
    } catch (e) {}

    this.messages = [{ from: 'bot', text: '你好，我是你的智能宠物狗助手，有什么可以帮你的吗？🐶' }]

    try {
      const history: ConversationRecord[] = await ConversationUtil.getConversations(this.account)
      if (history && history.length > 0) {
        const loadedMessages: Message[] = []
        for (let i = 0; i < history.length; i++) {
          const item = history[i]
          loadedMessages.push({ from: 'user', text: item.answer })
          loadedMessages.push({ from: 'bot', text: item.reply })
        }
        this.messages = [...this.messages, ...loadedMessages]
        setTimeout(() => {
          this.scroller.scrollTo({ xOffset: 0, yOffset: Number.MAX_SAFE_INTEGER })
        }, 200)
      }
    } catch (error) {
      console.error('[加载历史对话失败]', JSON.stringify(error))
    }
  }

  sendMessage() {
    if (!this.isLogin) {
      promptAction.showToast({ message: '请先登录！' })
      this.pathStack.pushPathByName('Login', null)
      return
    }
    if (this.inputText.trim() === '') return

    const currentQuestion = this.inputText
    this.inputText = ''

    // 1. 插入用户问题
    this.messages.push({ from: 'user', text: currentQuestion })
    // 2. 预插入 Bot 空回复
    this.messages.push({ from: 'bot', text: '' })
    const botIndex = this.messages.length - 1

    this.isBotReplying = true
    setTimeout(() => {
      this.scroller.scrollTo({ xOffset: 0, yOffset: Number.MAX_SAFE_INTEGER })
    }, 100)

    // ============================================================
    // 修复重点：回复内容累加器
    // ============================================================
    let fullReplyContent = ''
    let isSaved = false // 防止重复保存

    // 封装保存逻辑
    const saveAndClose = () => {
      if (isSaved) return

      // ⚠️ 关键修复：如果局部变量为空，尝试从 UI 状态中再次获取作为兜底
      // 这能解决“能看到文字但保存为空”的问题
      if (!fullReplyContent || fullReplyContent.length === 0) {
        if (this.messages[botIndex] && this.messages[botIndex].text) {
          fullReplyContent = this.messages[botIndex].text;
          console.info('[Debug] 从 UI 状态中恢复了回复内容');
        }
      }

      console.info(`[Debug] 结束对话，准备保存。问题: ${currentQuestion}, 回复长度: ${fullReplyContent.length}`)

      clearTimeout(this.silenceTimer)
      isSaved = true

      animateTo({ duration: 200 }, () => {
        this.isBotReplying = false
      })

      if (fullReplyContent && fullReplyContent.trim().length > 0) {
        ConversationUtil.addConversation(this.account, currentQuestion, fullReplyContent)
          .then((res) => {
            console.info('✅ 保存请求已发送:', JSON.stringify(res))
          })
          .catch((e: Error) => {
            console.error("❌ 保存请求失败:", JSON.stringify(e))
          })
      } else {
        console.warn('[Debug] 回复内容确实为空，跳过保存。')
      }
    }

    // 处理 voice_id 为 0 的逻辑
    let currentVoiceId = String(this.voiceId);
    if (!currentVoiceId || currentVoiceId === 'undefined' || currentVoiceId === 'null') {
      currentVoiceId = "0";
    }

    const inputPayload: CozeContentPayload = {
      question: currentQuestion,
      voice_id: currentVoiceId,
      speed_ratio: this.speedRatio || 1.0
    };

    const params: CozeRequestParams = {
      bot_id: '7534905232841785370',
      user: 'petdog_user',
      query: JSON.stringify(inputPayload),
      stream: true
    }

    // 20s 超时强制保存
    this.silenceTimer = setTimeout(() => {
      console.warn('对话超时，强制结束');
      saveAndClose();
    }, 20000)

    try {
      this.coze.sendMessage(params, async (msg: CozeMessage) => {
        clearTimeout(this.silenceTimer)
        // 缩短超时时间，防止 socket 挂起
        this.silenceTimer = setTimeout(() => {
          console.warn('流式响应中断，强制结束');
          saveAndClose();
        }, 10000)

        // 1. 优先处理内容
        if (msg.message?.content) {
          const content = msg.message.content;

          // 调试日志：看看扣子到底发了什么
          // console.info('[Coze Stream] 收到片段:', content);

          const isAudioLink = (content.includes('http://') || content.includes('https://')) &&
            (content.includes('.mp3') || content.includes('.wav'));

          if (!isAudioLink) {
            fullReplyContent += content
            // 实时更新 UI
            this.messages[botIndex] = { from: 'bot', text: fullReplyContent }
            this.scroller.scrollTo({ xOffset: 0, yOffset: Number.MAX_SAFE_INTEGER })
          }
        }

        // 2. 处理结束信号 (增加延迟，防止 content 还没处理完)
        if (msg.is_finish) {
          console.info('[Conversation] 收到结束信号 is_finish=true');
          // 延迟 200ms 保存，确保上面的 content 处理逻辑已经跑完
          setTimeout(() => {
            saveAndClose()
          }, 200);
        }
      })
    } catch (err) {
      console.error('发送请求异常:', JSON.stringify(err))
      this.messages[botIndex] = { from: 'bot', text: '网络请求失败 😣' }
      this.isBotReplying = false
    }
  }

  // --- 下面是 build 和 deleteMessage 代码，保持不变即可 ---
  async deleteMessage(replyText: string, messageIndex: number) {
    const confirm = await promptAction.showDialog({
      title: '删除对话',
      message: '确定要删除这条对话记录吗？',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    })

    if (confirm.index === 1) {
      try {
        await ConversationUtil.deleteConversation(this.account, replyText)
        const updated = [...this.messages]
        if (messageIndex > 0 && updated[messageIndex - 1].from === 'user') {
          updated.splice(messageIndex - 1, 2)
        } else {
          updated.splice(messageIndex, 1)
        }
        this.messages = updated
        promptAction.showToast({ message: '删除成功' })
      } catch (error) {
        promptAction.showToast({ message: '删除失败' })
      }
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {
        Stack() {
          Image($r('app.media.coze_background'))
            .width('100%').height('100%').objectFit(ImageFit.Cover).opacity(0.8).blur(10)
          Column().width('100%').height('100%').backgroundColor('rgba(255,255,255,0.4)')
        }.width('100%').height('100%')

        Column() {
          Row() {
            Text('智能助手').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
          }
          .width('100%').height(50).justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(255,255,255,0.6)').backdropBlur(20)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 2 }).zIndex(10)

          List({ space: 20, scroller: this.scroller }) {
            ListItem().height(10)
            ForEach(this.messages, (msg: Message, index: number) => {
              ListItem() {
                if (msg.from === 'bot') {
                  Row({ space: 10 }) {
                    Image($r('app.media.dog')).width(44).height(44).borderRadius(22)
                      .border({ width: 1, color: '#FFF' }).shadow({ radius: 5, color: 'rgba(0,0,0,0.1)' })
                    Column() {
                      Text(msg.text).fontSize(16).fontFamily('alibaba').fontColor('#333').lineHeight(26)
                    }
                    .padding(14).backgroundColor(Color.White)
                    .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
                    .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
                    .constraintSize({ maxWidth: '75%' })
                    .onClick(() => this.deleteMessage(msg.text, index))
                  }.width('100%').padding({ left: 16, right: 16 }).alignItems(VerticalAlign.Top).justifyContent(FlexAlign.Start)
                } else {
                  Row({ space: 10 }) {
                    Column() {
                      Text(msg.text).fontSize(16).fontFamily('alibaba').fontColor(Color.White).lineHeight(26)
                    }
                    .padding(14)
                    .linearGradient({ angle: 135, colors: [['#6A85B6', 0.0], ['#BAC8E0', 1.0]] })
                    .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
                    .shadow({ radius: 8, color: 'rgba(65, 88, 208, 0.25)', offsetY: 4 })
                    .constraintSize({ maxWidth: '75%' })

                    Image(this.getAvatarSrc()).width(44).height(44).borderRadius(22)
                      .border({ width: 2, color: '#FFF' }).shadow({ radius: 5, color: 'rgba(0,0,0,0.1)' })
                      .objectFit(ImageFit.Cover)
                  }.width('100%').padding({ left: 16, right: 16 }).alignItems(VerticalAlign.Top).justifyContent(FlexAlign.End)
                }
              }
            })
            ListItem().height(20)
          }.layoutWeight(1).width('100%')

          Column() {
            Row({ space: 12 }) {
              TextInput({ placeholder: this.isBotReplying ? '对方正在输入...' : '聊点什么吧...', text: this.inputText })
                .layoutWeight(1).height(44).backgroundColor('#F7F8FA').borderRadius(22)
                .padding({ left: 16, right: 16 }).fontSize(16)
                .enterKeyType(EnterKeyType.Send)
                .onChange((val) => this.inputText = val)
                .onSubmit(() => this.sendMessage())
                .enabled(!this.isBotReplying)
                .stateStyles({
                  focused: { .border({ width: 1, color: '#4158D0' }) },
                  normal: { .border({ width: 1, color: Color.Transparent }) }
                }).animation({ duration: 200 })

              Button() {
                if (this.isBotReplying) {
                  LoadingProgress().width(20).height(20).color(Color.White)
                } else {
                  Text('发送').fontColor(Color.White).fontWeight(FontWeight.Bold).fontSize(15)
                }
              }
              .width(60).height(40).borderRadius(20)
              .backgroundColor(this.inputText.trim() === '' ? '#CFD6E6' : '#4158D0')
              .enabled(!this.isBotReplying && this.inputText.trim() !== '')
              .onClick(() => this.sendMessage())
              .animation({ duration: 200 })
            }
            .width('100%').padding({ top: 12, bottom: 20, left: 16, right: 16 })
            .backgroundColor(Color.White).shadow({ radius: 30, color: 'rgba(0,0,0,0.05)', offsetY: -5 })
            .borderRadius({ topLeft: 24, topRight: 24 })
          }
        }.width('100%').height('100%')
      }
    }.hideTitleBar(true)
  }
}