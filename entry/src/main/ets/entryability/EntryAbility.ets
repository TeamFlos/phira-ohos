import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window,display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    try {
      display.off('foldStatusChange');
      display.off('change');
    } catch (err) {
    }
  }

  private async adjustWindowForFoldablePC(win: window.Window): Promise<void> {
    if (!win) {
      return;
    }
    try {
      const isFoldable = display.isFoldable();
      if (!isFoldable) {
        hilog.info(DOMAIN, 'testTag', '[FoldAdapt] Not a foldable device, skip');
        return;
      }
      const foldStatus = display.getFoldStatus();
      hilog.info(DOMAIN, 'testTag', '[FoldAdapt] Current foldStatus: %{public}d', foldStatus);
      const allDisplays = await display.getAllDisplays();
      const defaultDisplay = display.getDefaultDisplaySync();
      const rotation = defaultDisplay.rotation;
      hilog.info(DOMAIN, 'testTag', '[FoldAdapt] Screen rotation: %{public}d', rotation);
      if (rotation !== 0) {
        hilog.info(DOMAIN, 'testTag', '[FoldAdapt] Not portrait mode, skip. Rotation: %{public}d', rotation);
        return;
      }
      hilog.info(DOMAIN, 'testTag', '[FoldAdapt] allDisplays.length: %{public}d', allDisplays.length);
      if (allDisplays.length >= 2) {
        hilog.info(DOMAIN, 'testTag', '[FoldAdapt] Half-folded with dual screens, moving ...');
        const moveConfig: window.MoveConfiguration = {
          displayId: 0
        };
        await win.moveWindowToGlobal(0, 0, moveConfig);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', '[FoldAdapt] Error: %{public}s', JSON.stringify(err));
    }
  }

  private initFoldStatusListener(data:window.Window): void {
    try {
      const isFoldable = display.isFoldable();
      if (!isFoldable || '2in1' !== deviceInfo.deviceType) {
        return;
      }
      display.on('foldStatusChange', (foldStatus: display.FoldStatus) => {
        hilog.info(DOMAIN, 'testTag', '[FoldListener] foldStatusChange: %{public}d', foldStatus);
        this.adjustWindowForFoldablePC(data);
      });
      display.on('change', (displayId: number) => {
        hilog.info(DOMAIN, 'testTag', '[FoldListener] display change, displayId: %{public}d', displayId);
        this.adjustWindowForFoldablePC(data);
      });
      this.adjustWindowForFoldablePC(data);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', '[FoldListener] Init error: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    let windowClass: window.Window | undefined = undefined;
    windowStage.getMainWindow((err: BusinessError, data) => {
      try{
        data?.setWindowDecorVisible(false);
      }catch (exception){
        console.error(`Failed to setWindowDecorVisible. Cause code: ${exception.code}, message: ${exception.message}`);
      }
      let errCode: number = err.code;
      if (errCode) {
        console.error(`Failed to obtain the main window. CCode:${err.code}, message:${err.message}`);
        return;
      }
      windowClass = data;
      AppStorage.setOrCreate<number>('windowID', windowClass.getWindowProperties().id);
      try {
        windowClass.setWindowKeepScreenOn(true, (err: BusinessError) => {
          if (err.code) {
            console.error('Failed to set the screen to be always on. Cause: ' + JSON.stringify(err));
            return;
          }
          console.info('Succeeded in setting the screen to be always on.');
        });
      } catch (exception) {
        console.error('Failed to set the screen to be always on. Cause: ' + JSON.stringify(exception));
      }

      console.info(`Succeeded in obtaining the main window. Result:${data}`);
      this.initFoldStatusListener(data);
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
    windowStage.getMainWindow((err: BusinessError, data) => {
      const errCode: number = err.code;
      if (errCode) {
        console.error(`Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`);
        return;
      }
      windowClass = data;
      let isLayoutFullScreen = true;
      try {
        windowClass.setWindowLayoutFullScreen(isLayoutFullScreen);
        let names = [];
        data.setWindowSystemBarEnable(names);
      } catch (exception) {
        console.error(`Failed to set the window layout to full-screen mode. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    });

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}