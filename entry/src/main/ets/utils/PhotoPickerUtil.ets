// PhotoPickerUtil.ts
import {
  PickerController,
  PickerOptions,
  ItemInfo,
  ItemType,
  ClickType,
  photoAccessHelper,
  ReminderMode
} from '@kit.MediaLibraryKit';

export class PhotoPickerUtil {
  private pickerOptions: PickerOptions = new PickerOptions();
  private pickerController: PickerController = new PickerController();

  private resolveCallback: ((uris: Array<string>) => void) | null = null;

  private selectedUris: Array<string> = [];

  constructor() {
    // 单选模式
    this.pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; // 强制只显示图片
    this.pickerOptions.maxSelectNumber = 1;  // ★ 单选的关键
    this.pickerOptions.maxSelectedReminderMode = ReminderMode.TOAST;
    this.pickerOptions.isSearchSupported = true;
    this.pickerOptions.isPhotoTakingSupported = true;
  }

  /**
   * 打开选择器，并返回用户选择的图片 URI 数组
   */
  public pickImages(): Promise<Array<string>> {
    return new Promise((resolve) => {
      this.resolveCallback = resolve;
    });
  }

  public getPickerOptions(): PickerOptions {
    return this.pickerOptions;
  }

  public getPickerController(): PickerController {
    return this.pickerController;
  }

  /**
   * 资源点击事件（单选版）
   */
  public onItemClicked(item: ItemInfo, clickType: ClickType): boolean {
    if (!item) return false;

    let uri = item.uri;

    // 相机入口
    if (item.itemType === ItemType.CAMERA) {
      return true;
    }

    // -----------------------
    // 单选处理逻辑
    // -----------------------

    if (clickType === ClickType.SELECTED && uri) {
      // 用户点击另一张时，清空旧选择
      this.selectedUris = [uri];

      // 刷新预选列表
      this.pickerOptions.preselectedUris = [...this.selectedUris];

      return true;
    }

    if (clickType === ClickType.SELECTED && uri) {
      // 用户取消选中最后一张图
      this.selectedUris = [];
      this.pickerOptions.preselectedUris = [];

      return true;
    }

    return true;
  }

  /**
   * 退出图片选择器：返回选中的 URI
   */
  public finishPick() {
    if (this.resolveCallback) {
      this.resolveCallback(this.selectedUris);
    }
  }
}