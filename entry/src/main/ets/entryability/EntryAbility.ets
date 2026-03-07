import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { copyUriToTempFile } from '../utils/AbilityUtils';

const DOMAIN = 0x0000;
const TAG = "Phira-ohos";
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    this.handleWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onNewWant');
    this.handleWant(want);
  }

  private async handleWant(want: Want): Promise<void> {
    if (want.uri) {
      hilog.info(DOMAIN, TAG, 'Received file URI: %{public}s', want.uri);
      try {
        const tempFilePath = await copyUriToTempFile(this.context, want.uri);
        if (tempFilePath) {
          AppStorage.setOrCreate('pendingImportFile', tempFilePath);
          hilog.info(DOMAIN, TAG, 'Saved pending import file: %{public}s', tempFilePath);
        } else {
          hilog.error(DOMAIN, TAG, 'Failed to copy file to temp directory');
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to handle file import. Cause: %{public}s', JSON.stringify(err));
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    windowStage.getMainWindow((err: BusinessError, windowClass: window.Window) => {
      if (err.code) {
        console.error(`Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`);
        return;
      }
      try {
        windowClass.setWindowDecorVisible(false);
      } catch (exception) {
        console.error(`Failed to setWindowDecorVisible. Cause code: ${exception.code}, message: ${exception.message}`);
      }
      try {
        windowClass.setWindowKeepScreenOn(true, (err: BusinessError) => {
          if (err.code) {
            console.error('Failed to set the screen to be always on. Cause: ' + JSON.stringify(err));
            return;
          }
        });
      } catch (exception) {
        console.error('Failed to set the screen to be always on. Cause: ' + JSON.stringify(exception));
      }
      try {
        windowClass.setWindowLayoutFullScreen(true);
        windowClass.setWindowSystemBarEnable([]);
      } catch (exception) {
        console.error(`Failed to set the window layout to full-screen mode. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}