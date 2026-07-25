import promptAction from "@ohos.promptAction"
import { CommandUtil, Command } from '../utils/CommandUtil'
import { SurfaceCard } from '../components/SurfaceCard'
import { EmptyState } from '../components/EmptyState'
import { isTablet } from '../theme/Theme'

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
  @State newContent: string = ''
  @State newMessage: string = ''
  @State selectedIndex: number = -1
  @State commandList: Command[] = []
  @State isLoading: boolean = true
  @State errorMsg: string = ''
  @State pageWidth: number = 0

  private readonly messageOptions: string[] = ['trot', 'trot_back', 'turn_left', 'turn_right']

  private getSelectOptions(): SelectOption[] {
    const opts: SelectOption[] = []
    for (let i = 0; i < this.messageOptions.length; i++) {
      opts.push({ value: this.messageOptions[i] as ResourceStr })
    }
    return opts
  }

  async aboutToAppear() {
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
          { text: '取消', color: '#FF62758F' },
          { text: '删除', color: '#FFDF4B45' }
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
            .fillColor($r('app.color.text_primary'))
            .margin({ right: 10 })
            .onClick(() => this.pathStack.pop())

          Text('返回')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width(isTablet(this.pageWidth) ? 820 : '100%')
        .align(Alignment.Top)
        .height(70)
        .padding({ left: 20 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        /** 主体内容区 **/
        Scroll() {
          Column({ space: 20 }) {
            if (this.isLoading) {
              Row({ space: 10 }) {
                LoadingProgress()
                  .width(22)
                  .height(22)
                  .color($r('app.color.brand_primary'))

                Text('正在加载命令...')
                  .fontSize($r('app.float.font_size_subtitle'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .margin(20)
            } else if (this.commandList.length === 0) {
              EmptyState({
                icon: $r('app.media.command'),
                title: this.errorMsg !== '' ? this.errorMsg : '暂无命令数据',
                tip: '点击下方按钮添加你的第一条自定义命令'
              })
            } else {
              // 命令表格
              SurfaceCard({ contentPadding: 0, radius: 18 }) {
                Column() {
                  Row() {
                    Text('命令内容')
                      .width('50%')
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_on_brand'))

                    Text('对应消息')
                      .width('50%')
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_on_brand'))
                  }
                  .padding(14)
                  .backgroundColor($r('app.color.brand_primary'))
                  .borderRadius({ topLeft: 18, topRight: 18 })

                  ForEach(this.commandList, (cmd: Command, idx: number) => {
                    Row() {
                      Text(cmd.content)
                        .width('50%')
                        .fontSize($r('app.float.font_size_subtitle'))
                        .fontColor($r('app.color.text_primary'))

                      Text(cmd.message)
                        .width('50%')
                        .fontSize($r('app.float.font_size_subtitle'))
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .padding(14)
                    .backgroundColor($r('app.color.surface_card_solid'))
                    .onClick(() => this.deleteCommand(cmd.content))

                    if (idx < this.commandList.length - 1) {
                      Divider()
                        .color($r('app.color.divider'))
                        .strokeWidth(1)
                    }
                  }, (cmd: Command) => `${cmd.id ?? cmd.content}`)
                }
              }
            }

            /** 添加命令输入区 **/
            if (this.isAdding) {
              SurfaceCard({ contentPadding: 16, radius: 16 }) {
                Column({ space: 12 }) {
                  Row() {
                    Text('添加新命令')
                      .fontSize($r('app.float.font_size_title'))
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                  }

                  Row({ space: 10 }) {
                    TextInput({ placeholder: '请输入命令内容（如 walk）' })
                      .layoutWeight(2)
                      .height(44)
                      .borderRadius(10)
                      .backgroundColor($r('app.color.input_bg'))
                      .border({ width: 1, color: $r('app.color.input_border') })
                      .padding({ left: 12, right: 12 })
                      .fontColor($r('app.color.text_primary'))
                      .placeholderColor($r('app.color.text_tertiary'))
                      .onChange((v: string) => this.newContent = v)

                    Select(this.getSelectOptions())
                      .selected(this.selectedIndex < 0 ? 0 : this.selectedIndex)
                      .layoutWeight(1)
                      .height(44)
                      .onSelect((index: number, value: string) => {
                        this.selectedIndex = index
                        this.newMessage = value
                      })

                    Button('确定')
                      .height(44)
                      .padding({ left: 18, right: 18 })
                      .backgroundColor($r('app.color.brand_primary'))
                      .fontColor($r('app.color.text_on_brand'))
                      .borderRadius(10)
                      .fontSize($r('app.float.font_size_body'))
                      .onClick(() => this.addCommand())
                  }
                }
                .width('100%')
              }
            }

            /** 底部添加/取消按钮 **/
            Button(this.isAdding ? '取消添加' : '+ 添加命令')
              .width('80%')
              .height(48)
              .fontSize($r('app.float.font_size_subtitle'))
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isAdding
                ? $r('app.color.state_danger_subtle')
                : $r('app.color.brand_primary'))
              .fontColor(this.isAdding
                ? $r('app.color.state_danger')
                : $r('app.color.text_on_brand'))
              .borderRadius(12)
              .margin({ top: 20, bottom: 40 })
              .onClick(() => this.isAdding = !this.isAdding)
          }
          .alignItems(HorizontalAlign.Center)
          .width(isTablet(this.pageWidth) ? 820 : '100%')
          .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        const width: number = Number(newValue.width)
        if (!Number.isNaN(width)) {
          this.pageWidth = width
        }
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      // 字体注册已统一移至 EntryAbility.onCreate
    })
    .hideTitleBar(true)
  }
}
