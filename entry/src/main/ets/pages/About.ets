import { font } from "@kit.ArkUI";

@Builder
export function AboutBuilder(){
  About()
}

@Entry
@Component
struct About {
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination(){
      Column(){
        Row(){
          Image($r('app.media.arrow_return'))
            .width(25)
            .height(25)
            .onClick(() => {
              this.pathStack.pop()
            })
            .margin(20)

          Text('返回')
            .fontSize(25)
            .fontFamily('alibaba')
        }
        .width('100%')
        .height('10%')
        .margin(30)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        Column(){
          Text('版本号1.0')
            .fontSize(25)
            .fontFamily('alibaba')
            .margin(20)

          Text('版本功能：远程控制、语音参数设置、图像回传、自动追踪、语音交流、语音控制')
            .fontSize(20)
            .fontFamily('alibaba')
            .margin(20)
        }
        .width('100%')
        .height('90%')
      }
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .width('100%')
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) =>{
      this.pathStack = context.pathStack

      //注册字体
      font.registerFont({
        familyName: "alibaba", //字体名
        familySrc: $rawfile('AlimamaDongFangDaKai-Regular.otf') //字体资源
      })
    })
  }
}