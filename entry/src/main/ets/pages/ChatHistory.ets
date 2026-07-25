import promptAction from '@ohos.promptAction'
import { CozeConversationMessage, CozeService } from '../utils/CozeUtil'
import { ConversationRecord, ConversationResponse, ConversationUtil } from '../utils/ConversationUtil'
import { EmptyState } from '../components/EmptyState'
import { isTablet } from '../theme/Theme'

PersistentStorage.persistProp('deletedCozeMessageIds', '')
if (!AppStorage.has('deletedCozeMessageIds')) AppStorage.setOrCreate('deletedCozeMessageIds', '')

interface ChatHistoryItem {
  id: string
  role: string
  content: string
  time: string
}

interface ChatHistoryGroup {
  id: string
  source: string
  localReply: string
  messageIds: string[]
  items: ChatHistoryItem[]
  time: string
}

interface ChatPayload {
  question?: string
  voice_id?: string
  speed_ratio?: number
}

@Builder
export function ChatHistoryBuilder() {
  ChatHistory()
}

@Entry
@Component
struct ChatHistory {
  pathStack: NavPathStack = new NavPathStack()

  @StorageLink('account') account: number = 0
  @StorageLink('cozeConversationId') cozeConversationId: string = ''
  @StorageLink('petName') petName: string = '小E'
  @StorageLink('wakeWord') wakeWord: string = '小E'
  @StorageLink('deletedCozeMessageIds') deletedCozeMessageIds: string = ''

  @State pageWidth: number = 0
  @State isLoading: boolean = true
  @State isDeleting: boolean = false
  @State sourceText: string = ''
  @State hintText: string = ''
  @State conversations: ChatHistoryGroup[] = []

  private coze: CozeService = new CozeService()

  private getPetDisplayName(): string {
    const wakeName: string = this.wakeWord.trim()
    if (wakeName.length > 0) return wakeName
    const petName: string = this.petName.trim()
    return petName.length > 0 ? petName : '小E'
  }

  async aboutToAppear(): Promise<void> {
    await this.loadHistory()
  }

  private async loadHistory(): Promise<void> {
    this.isLoading = true
    this.hintText = ''
    this.sourceText = ''

    try {
      if (this.cozeConversationId.trim().length > 0) {
        const remoteMessages: CozeConversationMessage[] =
          await this.coze.listConversationMessages(this.cozeConversationId, 80)
        const remoteGroups: ChatHistoryGroup[] = this.normalizeCozeMessages(remoteMessages)
        if (remoteGroups.length > 0) {
          this.conversations = remoteGroups
          this.sourceText = `扣子会话 ${this.shortConversationId()} · ${remoteGroups.length} 轮`
          return
        }
        this.hintText = '扣子会话暂时没有返回记录，已尝试读取本地记录'
      }

      const localRecords: ConversationRecord[] = await ConversationUtil.getConversations(this.account || 0)
      const localGroups: ChatHistoryGroup[] = this.normalizeLocalRecords(localRecords)
      this.conversations = localGroups
      this.sourceText = localGroups.length > 0 ? `本地历史记录 · ${localGroups.length} 轮` : '暂无历史记录'
    } catch (err) {
      console.error('Load chat history failed:', JSON.stringify(err))
      this.conversations = []
      this.sourceText = '加载失败'
      this.hintText = '网络异常，请稍后重试'
    } finally {
      this.isLoading = false
    }
  }

  private normalizeCozeMessages(messages: CozeConversationMessage[]): ChatHistoryGroup[] {
    const groups: ChatHistoryGroup[] = []
    let fallbackIndex: number = 0
    let currentGroupIndex: number = -1

    for (let i = 0; i < messages.length; i++) {
      const message: CozeConversationMessage = messages[i]
      const messageId: string = message.id || `coze_${i}`
      if (this.isCozeMessageDeleted(messageId)) continue

      const content: string = this.extractContent(message.content || '').trim()
      if (content.length === 0) continue

      const role: string = this.normalizeRole(message)
      const time: string = this.formatTimestamp(message.created_at || message.updated_at || 0)
      const chatId: string = message.chat_id || ''
      let groupIndex: number = -1

      if (chatId.length > 0) {
        const groupId: string = `coze_${chatId}`
        groupIndex = this.findGroupIndex(groups, groupId)
        if (groupIndex < 0) {
          groupIndex = groups.length
          groups.push(this.createHistoryGroup(groupId, 'coze', time))
        }
      } else if (role === 'user' || currentGroupIndex < 0 || this.hasAssistant(groups[currentGroupIndex])) {
        groupIndex = groups.length
        currentGroupIndex = groupIndex
        groups.push(this.createHistoryGroup(`coze_pair_${fallbackIndex}`, 'coze', time))
        fallbackIndex++
      } else {
        groupIndex = currentGroupIndex
      }

      groups[groupIndex].messageIds.push(messageId)
      if (groups[groupIndex].time.length === 0 && time.length > 0) {
        groups[groupIndex].time = time
      }
      groups[groupIndex].items.push({ id: messageId, role, content, time })
    }

    return groups
  }

  private normalizeLocalRecords(records: ConversationRecord[]): ChatHistoryGroup[] {
    const groups: ChatHistoryGroup[] = []
    for (let i = 0; i < records.length; i++) {
      const record: ConversationRecord = records[i]
      const recordId: string = record.id !== undefined ? `${record.id}` : `${i}`
      const group: ChatHistoryGroup = this.createHistoryGroup(`local_${recordId}`, 'local', record.create_time || '')
      group.localReply = record.reply || ''

      if (record.answer && record.answer.trim().length > 0) {
        group.items.push({
          id: `local_${recordId}_user`,
          role: 'user',
          content: record.answer,
          time: record.create_time || ''
        })
      }
      if (record.reply && record.reply.trim().length > 0) {
        group.items.push({
          id: `local_${recordId}_assistant`,
          role: 'assistant',
          content: record.reply,
          time: record.create_time || ''
        })
      }
      if (group.items.length > 0) groups.push(group)
    }
    return groups
  }

  private createHistoryGroup(id: string, source: string, time: string): ChatHistoryGroup {
    return { id, source, localReply: '', messageIds: [], items: [], time }
  }

  private findGroupIndex(groups: ChatHistoryGroup[], groupId: string): number {
    for (let i = 0; i < groups.length; i++) {
      if (groups[i].id === groupId) return i
    }
    return -1
  }

  private hasAssistant(group: ChatHistoryGroup): boolean {
    for (let i = 0; i < group.items.length; i++) {
      if (group.items[i].role === 'assistant') return true
    }
    return false
  }

  private normalizeRole(message: CozeConversationMessage): string {
    if (message.role === 'user' || message.type === 'question') return 'user'
    return 'assistant'
  }

  private extractContent(content: string): string {
    try {
      const payload: ChatPayload = JSON.parse(content) as ChatPayload
      if (payload.question && payload.question.trim().length > 0) {
        return payload.question
      }
    } catch (err) {}
    return content
  }

  private shortConversationId(): string {
    if (this.cozeConversationId.length <= 8) return this.cozeConversationId
    return this.cozeConversationId.substring(this.cozeConversationId.length - 8)
  }

  private formatTimestamp(timestamp: number): string {
    if (timestamp <= 0) return ''
    const millis: number = timestamp > 10000000000 ? timestamp : timestamp * 1000
    const date: Date = new Date(millis)
    return `${date.getFullYear()}-${this.two(date.getMonth() + 1)}-${this.two(date.getDate())} ${this.two(date.getHours())}:${this.two(date.getMinutes())}`
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private isCozeMessageDeleted(messageId: string): boolean {
    if (messageId.length === 0 || this.deletedCozeMessageIds.length === 0) return false
    return `|${this.deletedCozeMessageIds}|`.indexOf(`|${messageId}|`) >= 0
  }

  private rememberDeletedCozeMessageIds(messageIds: string[]): void {
    let value: string = this.deletedCozeMessageIds
    for (let i = 0; i < messageIds.length; i++) {
      const messageId: string = messageIds[i]
      if (messageId.length === 0 || `|${value}|`.indexOf(`|${messageId}|`) >= 0) continue
      value = value.length > 0 ? `${value}|${messageId}` : messageId
    }
    this.deletedCozeMessageIds = value
    AppStorage.setOrCreate('deletedCozeMessageIds', value)
  }

  private getGroupContent(group: ChatHistoryGroup, role: string): string {
    for (let i = 0; i < group.items.length; i++) {
      if (group.items[i].role === role) return group.items[i].content
    }
    return ''
  }

  private getGroupPreview(group: ChatHistoryGroup): string {
    const question: string = this.getGroupContent(group, 'user')
    const reply: string = this.getGroupContent(group, 'assistant')
    const content: string = question.length > 0 ? question : reply
    if (content.length <= 28) return content
    return `${content.substring(0, 28)}...`
  }

  private isDeleteResponseOk(response: ConversationResponse): boolean {
    if (response.status === 'fail') return false
    if (response.code !== undefined && response.code !== 0 && response.code !== 1 && response.code !== 200) {
      return false
    }
    return true
  }

  private refreshSourceTextAfterMutation(next: ChatHistoryGroup[]): void {
    if (next.length === 0) {
      this.sourceText = '暂无历史记录'
      return
    }
    if (next[0].source === 'coze') {
      this.sourceText = `扣子会话 ${this.shortConversationId()} · ${next.length} 轮`
      return
    }
    this.sourceText = `本地历史记录 · ${next.length} 轮`
  }

  private async confirmDeleteConversation(group: ChatHistoryGroup): Promise<void> {
    if (this.isDeleting) return
    try {
      const result = await promptAction.showDialog({
        title: '删除对话',
        message: `确定删除这轮对话吗？\n${this.getGroupPreview(group)}`,
        buttons: [
          { text: '取消', color: '#FF62758F' },
          { text: '删除', color: '#FFDF4B45' }
        ]
      })
      if (result.index === 1) await this.deleteConversationGroup(group)
    } catch (err) {
      console.info('Delete conversation canceled:', JSON.stringify(err))
    }
  }

  private async confirmClearAll(): Promise<void> {
    if (this.isDeleting) return
    if (this.conversations.length === 0) {
      promptAction.showToast({ message: '暂无可删除的对话' })
      return
    }

    try {
      const result = await promptAction.showDialog({
        title: '清空对话记录',
        message: `确定删除全部 ${this.conversations.length} 轮历史对话吗？`,
        buttons: [
          { text: '取消', color: '#FF62758F' },
          { text: '清空', color: '#FFDF4B45' }
        ]
      })
      if (result.index === 1) await this.clearAllConversations()
    } catch (err) {
      console.info('Clear conversations canceled:', JSON.stringify(err))
    }
  }

  private async deleteConversationGroup(group: ChatHistoryGroup): Promise<void> {
    this.isDeleting = true
    try {
      let ok: boolean = true
      if (group.source === 'local') {
        ok = await this.deleteLocalByReply(group.localReply)
      } else {
        ok = await this.deleteMatchingLocalRecord(group)
        if (ok) this.rememberDeletedCozeMessageIds(group.messageIds)
      }

      if (!ok) {
        promptAction.showToast({ message: '删除失败，请稍后重试' })
        return
      }

      const next: ChatHistoryGroup[] = []
      for (let i = 0; i < this.conversations.length; i++) {
        if (this.conversations[i].id !== group.id) next.push(this.conversations[i])
      }
      this.conversations = next
      this.refreshSourceTextAfterMutation(next)
      promptAction.showToast({ message: '已删除这轮对话' })
    } catch (err) {
      console.error('Delete conversation failed:', JSON.stringify(err))
      promptAction.showToast({ message: '删除失败，请稍后重试' })
    } finally {
      this.isDeleting = false
    }
  }

  private async clearAllConversations(): Promise<void> {
    this.isDeleting = true
    try {
      for (let i = 0; i < this.conversations.length; i++) {
        this.rememberDeletedCozeMessageIds(this.conversations[i].messageIds)
      }

      let localOk: boolean = await this.deleteAllLocalRecords()
      if (this.cozeConversationId.trim().length > 0) {
        await this.coze.clearConversationContext(this.cozeConversationId)
      }

      this.conversations = []
      this.sourceText = '暂无历史记录'
      this.hintText = localOk ? '' : '部分本地记录删除失败，请稍后重试'
      promptAction.showToast({ message: localOk ? '已清空历史对话' : '已隐藏记录，部分本地删除失败' })
    } catch (err) {
      console.error('Clear conversations failed:', JSON.stringify(err))
      promptAction.showToast({ message: '清空失败，请稍后重试' })
    } finally {
      this.isDeleting = false
    }
  }

  private async deleteMatchingLocalRecord(group: ChatHistoryGroup): Promise<boolean> {
    const reply: string = this.getGroupContent(group, 'assistant').trim()
    if (reply.length === 0) return true

    const question: string = this.getGroupContent(group, 'user').trim()
    const records: ConversationRecord[] = await ConversationUtil.getConversations(this.account || 0)
    for (let i = 0; i < records.length; i++) {
      const record: ConversationRecord = records[i]
      if (record.reply.trim() === reply && (question.length === 0 || record.answer.trim() === question)) {
        return await this.deleteLocalByReply(record.reply)
      }
    }
    return true
  }

  private async deleteAllLocalRecords(): Promise<boolean> {
    const records: ConversationRecord[] = await ConversationUtil.getConversations(this.account || 0)
    let ok: boolean = true
    for (let i = 0; i < records.length; i++) {
      if (records[i].reply && records[i].reply.trim().length > 0) {
        const deleted: boolean = await this.deleteLocalByReply(records[i].reply)
        ok = ok && deleted
      }
    }
    return ok
  }

  private async deleteLocalByReply(reply: string): Promise<boolean> {
    if (reply.trim().length === 0) return true
    const response: ConversationResponse = await ConversationUtil.deleteConversation(this.account || 0, reply)
    return this.isDeleteResponseOk(response)
  }

  @Builder
  private MessageBubble(item: ChatHistoryItem) {
    Row() {
      if (item.role === 'user') {
        Blank().layoutWeight(1)
      }

      Column({ space: 5 }) {
        Row() {
          Text(item.role === 'user' ? '我' : this.getPetDisplayName())
            .fontSize(11)
            .fontColor(item.role === 'user'
              ? $r('app.color.brand_primary')
              : $r('app.color.state_success'))
            .fontWeight(FontWeight.Bold)

          if (item.time.length > 0) {
            Text(item.time)
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .justifyContent(item.role === 'user' ? FlexAlign.End : FlexAlign.Start)

        Text(item.content)
          .fontSize(15)
          .lineHeight(24)
          .fontColor(item.role === 'user'
            ? $r('app.color.text_on_brand')
            : $r('app.color.text_primary'))
          .padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .backgroundColor(item.role === 'user'
            ? $r('app.color.brand_primary')
            : $r('app.color.surface_card_solid'))
          .borderRadius(item.role === 'user'
            ? { topLeft: 18, topRight: 6, bottomLeft: 18, bottomRight: 18 }
            : { topLeft: 6, topRight: 18, bottomLeft: 18, bottomRight: 18 })
      }
      .alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
      .constraintSize({ maxWidth: isTablet(this.pageWidth) ? 560 : '78%' })

      if (item.role !== 'user') {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
  }

  @Builder
  private ConversationCard(group: ChatHistoryGroup) {
    Column({ space: 10 }) {
      Row() {
        Text(group.time.length > 0 ? group.time : '这轮对话')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))

        Blank()

        Text('删除')
          .fontSize(11)
          .fontColor($r('app.color.state_danger'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.state_danger_subtle'))
          .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      ForEach(group.items, (item: ChatHistoryItem): void => {
        this.MessageBubble(item)
      }, (item: ChatHistoryItem): string => item.id)
    }
    .width('100%')
    .padding({ top: 2, bottom: 10 })
    .opacity(this.isDeleting ? 0.72 : 1)
    .onClick((): void => {
      this.confirmDeleteConversation(group)
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg'))

        Column({ space: 14 }) {
          // 顶部栏
          Row({ space: 10 }) {
            Image($r('app.media.arrow_return'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
              .onClick((): void => {
                this.pathStack.pop()
              })

            Column({ space: 2 }) {
              Text('陪我聊天记录')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text(this.sourceText)
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button('清空')
              .height(36)
              .fontSize(13)
              .fontColor($r('app.color.state_danger'))
              .backgroundColor($r('app.color.state_danger_subtle'))
              .borderRadius(18)
              .padding({ left: 13, right: 13 })
              .opacity(this.conversations.length > 0 && !this.isDeleting ? 1 : 0.46)
              .onClick((): void => {
                this.confirmClearAll()
              })

            Button(this.isDeleting ? '处理中' : '刷新')
              .height(36)
              .fontSize(13)
              .fontColor($r('app.color.text_on_brand'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius(18)
              .padding({ left: 13, right: 13 })
              .onClick((): void => {
                if (!this.isDeleting) this.loadHistory()
              })
          }
          .width('100%')
          .height(62)
          .alignItems(VerticalAlign.Center)

          // 提示条
          if (this.hintText.length > 0) {
            Text(this.hintText)
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.state_warning'))
              .padding({ left: 14, right: 14, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.state_warning_subtle'))
              .borderRadius(14)
          }

          // 加载 / 空态 / 列表
          if (this.isLoading) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(34)
                .height(34)
                .color($r('app.color.brand_primary'))

              Text('正在读取聊天记录')
                .fontSize(15)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.conversations.length === 0) {
            Column() {
              EmptyState({
                icon: $r('app.media.conservation'),
                title: '还没有聊天记录',
                tip: `和 ${this.getPetDisplayName()} 聊一次后，这里会显示你们的对话`
              })
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Column({ space: 16 }) {
                ForEach(this.conversations, (group: ChatHistoryGroup): void => {
                  this.ConversationCard(group)
                }, (group: ChatHistoryGroup): string => group.id)
              }
              .width('100%')
              .padding({ top: 8, bottom: 28 })
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
          }
        }
        .width(isTablet(this.pageWidth) ? 720 : '100%')
        .height('100%')
        .padding({
          left: isTablet(this.pageWidth) ? 0 : 18,
          right: isTablet(this.pageWidth) ? 0 : 18,
          top: isTablet(this.pageWidth) ? 20 : 28,
          bottom: 18
        })
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pathStack = context.pathStack
    })
  }
}
