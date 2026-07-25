import lottie, { AnimationItem } from "@ohos/lottie";

@Component
export struct LottieView {
  @Prop name: string = "sleeping_2"

  private renderingSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvasRenderingContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderingSettings)
  private animationItem: AnimationItem | null = null;

  aboutToAppear(): void {
    this.animationItem = lottie.loadAnimation({
      container: this.canvasRenderingContext,
      renderer: 'canvas',
      loop: true,
      autoplay: true,
      name: this.name,
      contentMode: 'Contain',
      path: "lottie/" + this.name + ".json",
    })
  }

  build() {
    Column() {
      Stack() {
        Canvas(this.canvasRenderingContext)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.animationItem?.resize();
          })
          .onDisAppear(() => {
            lottie.destroy(this.name);
          })
      }
    }
  }
}
