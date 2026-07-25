import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FontRegistry } from '../theme/FontRegistry';
import { AppTheme } from '../theme/Theme';
import { markExpiredPending } from '../utils/EventReminderLogic';
import { EventReminderScheduler } from '../utils/EventReminderScheduler';
import { EventReminderStore } from '../utils/EventReminderStore';
import { EventReminder } from '../utils/EventReminderTypes';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 应用启动一次性注册自定义字体，所有页面无需再单独 registerFont
    FontRegistry.registerAll();

    // 恢复用户上次保存的颜色模式偏好（light / dark / system）
    try {
      AppTheme.applyStoredMode(this.context.getApplicationContext());
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'applyStoredMode failed: %{public}s', JSON.stringify(e));
    }

    // 校准过期提醒状态（不弹通知权限）
    this.calibrateEventReminders();
  }

  private async calibrateEventReminders(): Promise<void> {
    try {
      await EventReminderStore.init(this.context);
      let list: EventReminder[] = await EventReminderStore.loadAll();
      const now: number = Date.now();
      const changed: boolean = markExpiredPending(list, now);
      if (changed) {
        await EventReminderStore.saveAll(list);
      }
      await EventReminderScheduler.ensureSlotOnly();
      // 补发到期通知 + 重建本地定时器
      list = await EventReminderScheduler.checkDueAndNotify(list, now);
      await EventReminderStore.saveAll(list);
      await EventReminderScheduler.syncSystemWithLocal(list);
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'calibrateEventReminders failed: %{public}s', JSON.stringify(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    globalThis.windowStage = windowStage;
    windowStage.getMainWindow()
      .then(async (win: window.Window): Promise<void> => {
        // 全屏沉浸：隐藏顶部状态栏（时间/电量），内容从窗口顶部开始
        await win.setWindowLayoutFullScreen(true);
        await win.setWindowSystemBarEnable(['navigation']);
        await win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#FF111113',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#FF111113'
        });
      })
      .catch((e: Error): void => {
        hilog.warn(DOMAIN, 'testTag', 'set fullscreen failed: %{public}s', JSON.stringify(e));
      })
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    // 回到前台时补扫到期提醒（本地回退模式关键）
    this.calibrateEventReminders();
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
