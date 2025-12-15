import { font } from "@kit.ArkUI"
import promptAction from "@ohos.promptAction"
import { CommandUtil, Command } from '../utils/CommandUtil'

interface SelectOption {
  value: ResourceStr
  icon?: ResourceStr
}

@Builder
export function CommandBuilder() {
  CommandPage()
}

@Entry
@Component
struct CommandPage {
  @StorageLink('account') account: number = 0
  @State isAdding: boolean = false
  @State newContent: string = ''   // 输入框：命令内容
  @State newMessage: string = ''   // 选择框：对应消息
  @State selectedIndex: number = -1
  @State commandList: Command[] = []
  @State isLoading: boolean = true
  @State errorMsg: string = ''

  private readonly messageOptions: string[] = ['trot', 'trot_back', 'turn_left', 'turn_right']

  private getSelectOptions(): SelectOption[] {
    const opts: SelectOption[] = []
    for (let i = 0; i < this.messageOptions.length; i++) {
      opts.push({ value: this.messageOptions[i] as ResourceStr })
    }
    return opts
  }

  async aboutToAppear() {
    font.registerFont({
      familyName: 'alibaba',
      familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
    })
    await this.loadCommands()
  }

  private async loadCommands() {
    this.isLoading = true
    this.errorMsg = ''
    try {
      const res = await CommandUtil.getCommandsByAccount(this.account)
      if (res.success) {
        this.commandList = res.data ?? []
        if (this.commandList.length === 0) this.errorMsg = '暂无命令数据'
      } else {
        this.errorMsg = res.msg || '命令加载失败'
      }
    } catch (e) {
      console.error('加载命令失败:', e)
      this.errorMsg = '网络异常，请检查连接'
    } finally {
      this.isLoading = false
    }
  }

  private async addCommand() {
    if (this.newContent.trim() === '' || this.newMessage.trim() === '') {
      promptAction.showToast({ message: '请输入命令内容并选择对应消息', duration: 2000 })
      return
    }

    const newCmd: Command = {
      account: this.account,
      content: this.newContent,
      message: this.newMessage
    }

    const res = await CommandUtil.addCommand(newCmd)
    if (res.success) {
      promptAction.showToast({ message: '命令添加成功', duration: 1500 })
      this.newContent = ''
      this.newMessage = ''
      this.selectedIndex = -1
      this.isAdding = false
      await this.loadCommands()
    } else {
      promptAction.showToast({ message: res.msg || '添加失败', duration: 2000 })
    }
  }

  private async deleteCommand(content: string) {
    try {
      const result = await promptAction.showDialog({
        title: '删除确认',
        message: `确定要删除命令 "${content}" 吗？`,
        buttons: [
          { text: '取消', color: '#666' },
          { text: '删除', color: '#FF3B30' }
        ]
      })

      if (result.index === 1) {
        const res = await CommandUtil.deleteCommand(this.account, content)
        if (res.success) {
          promptAction.showToast({ message: '命令已删除', duration: 1500 })
          await this.loadCommands()
        } else {
          promptAction.showToast({ message: res.msg || '删除失败', duration: 2000 })
        }
      }
    } catch (err) {
      console.error('删除操作出错:', err)
      promptAction.showToast({ message: '操作取消或出错', duration: 2000 })
    }
  }

  pathStack: NavPathStack = new NavPathStack()

  build() {
    NavDestination() {
      Column() {

        /** 顶部导航栏 **/
        Row() {
          Image($r('app.media.arrow_return'))
            .width(24)
            .height(24)
            .margin({ right: 10 })
            .onClick(() => this.pathStack.pop())

          Text('返回')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontFamily('alibaba')
            .fontColor('#000')
        }
        .width('100%')
        .height(70)
        .padding({ left: 20 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .borderRadius({ bottomLeft: 15, bottomRight: 15 })


        /** 主体内容区 **/
        Scroll() {
          Column({ space: 20 }) {
            if (this.isLoading) {
              Text('正在加载命令...')
                .fontSize(18)
                .fontColor('#999')
                .margin(20)
            } else if (this.errorMsg !== '') {
              Text(this.errorMsg)
                .fontSize(18)
                .fontColor('#E53935')
                .margin(20)
            } else {
              // 表格卡片样式
              Column() {
                Row() {
                  Text('命令内容').width('50%').fontWeight(FontWeight.Bold).fontColor('#FFF')
                  Text('对应消息').width('50%').fontWeight(FontWeight.Bold).fontColor('#FFF')
                }
                .padding(10)
                .backgroundColor('#1C6AEB')
                .borderRadius({ topLeft: 8, topRight: 8 })

                ForEach(this.commandList, (cmd: Command) => {
                  Row() {
                    Text(cmd.content)
                      .width('50%')
                      .fontSize(18)
                      .fontColor('#333')
                    Text(cmd.message)
                      .width('50%')
                      .fontSize(18)
                      .fontColor('#555')
                  }
                  .padding(12)
                  .backgroundColor('#FFF')
                  .borderRadius(6)
                  .margin({ top: 4 })
                  .shadow({ radius: 3, color: '#DDD', offsetX: 0, offsetY: 2 })
                  .onClick(() => this.deleteCommand(cmd.content))
                }, (cmd: Command) => `${cmd.id ?? cmd.content}`)
              }
              .width('90%')
              .margin({ top: 10 })
            }

            /** 添加命令输入区 **/
            if (this.isAdding) {
              Column() {
                Row() {
                  Text('添加新命令')
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333')
                }
                .margin({ bottom: 8 })

                Row() {
                  TextInput({ placeholder: '请输入命令内容（如 walk）' })
                    .width('45%')
                    .height(40)
                    .borderRadius(8)
                    .backgroundColor('#fff')
                    .margin({ right: 10 })
                    .padding({ left: 8 })
                    .onChange((v: string) => this.newContent = v)

                  Select(this.getSelectOptions())
                    .selected(this.selectedIndex < 0 ? 0 : this.selectedIndex)
                    .width('25%')
                    .height(40)
                    .margin({ right: 10 })
                    .onSelect((index: number, value: string) => {
                      this.selectedIndex = index
                      this.newMessage = value
                    })

                  Button('确定')
                    .width('25%')
                    .height(40)
                    .backgroundColor('#34C759')
                    .fontColor('#fff')
                    .borderRadius(8)
                    .fontSize(17)
                    .onClick(() => this.addCommand())
                }
                .justifyContent(FlexAlign.Center)
                .margin({ top: 10, bottom: 10 })
              }
              .width('90%')
              .backgroundColor('#F9F9F9')
              .padding(10)
              .borderRadius(10)
              .shadow({ radius: 4, color: '#CCC' })
            }

            /** 底部添加按钮 **/
            Button(this.isAdding ? '取消添加' : '+ 添加命令')
              .width('80%')
              .height(45)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isAdding ? '#FF3B30' : '#007AFF')
              .fontColor('#fff')
              .borderRadius(10)
              .margin({ top: 20, bottom: 40 })
              .shadow({ radius: 5, color: '#AAA', offsetY: 3 })
              .onClick(() => this.isAdding = !this.isAdding)
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F4F7')
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      font.registerFont({
        familyName: "alibaba",
        familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf')
      })
    })
    .hideTitleBar(true)
  }
}