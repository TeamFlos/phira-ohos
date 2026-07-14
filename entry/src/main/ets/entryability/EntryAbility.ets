import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from "@kit.AbilityKit";
import { hilog, hiAppEvent } from "@kit.PerformanceAnalysisKit";
import { window, display } from "@kit.ArkUI";
import { BusinessError } from "@kit.BasicServicesKit";
import { copyUriToTempFile, executeClearCacheTask } from "../utils/AbilityUtils";
import { XComponentHolder } from "../utils/XComponentHolder";

const DOMAIN = 0x0000;
const TAG = "Phira-ohos";

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context
        .getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, "Failed to set colorMode. Cause: %{public}s", JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onCreate");
    this.registerCrashWatcher();
    this.handleWant(want);
  }

  private registerCrashWatcher(): void {
    const watcher: hiAppEvent.Watcher = {
      name: "gameCrashWatcher",
      appEventFilters: [
        {
          domain: hiAppEvent.domain.OS,
          names: [hiAppEvent.event.APP_CRASH],
        },
      ],
      onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
        for (const group of appEventGroups) {
          for (const info of group.appEventInfos) {
            const externalLog = info.params["external_log"] as string[];
            if (externalLog && externalLog.length > 0) {
              const logPath = externalLog[0];
              AppStorage.setOrCreate("pendingCrashLog", logPath);
              hilog.info(DOMAIN, TAG, "Detected previous crash log: %{public}s", logPath);
            }
          }
        }
      },
    };
    try {
      hiAppEvent.addWatcher(watcher);
    } catch (err) {
      hilog.error(DOMAIN, TAG, "Failed to add crash watcher: %{public}s", JSON.stringify(err));
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onNewWant");
    this.handleWant(want);
  }

  private async handleWant(want: Want): Promise<void> {
    if (want.uri) {
      hilog.info(DOMAIN, TAG, "Received file URI: %{public}s", want.uri);
      try {
        const tempFilePath = await copyUriToTempFile(this.context, want.uri);
        if (tempFilePath) {
          AppStorage.setOrCreate("pendingImportFile", tempFilePath);
          hilog.info(DOMAIN, TAG, "Saved pending import file: %{public}s", tempFilePath);
        } else {
          hilog.error(DOMAIN, TAG, "Failed to copy file to temp directory");
        }
      } catch (err) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to handle file import. Cause: %{public}s",
          JSON.stringify(err),
        );
      }
    } else {
      executeClearCacheTask(this.context.cacheDir);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onDestroy");
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onWindowStageCreate");
    windowStage.getMainWindow((err: BusinessError, windowClass: window.Window) => {
      if (err.code) {
        console.error(
          `Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`,
        );
        return;
      }
      try {
        windowClass.setWindowDecorVisible(false);
      } catch (exception) {
        console.error(
          `Failed to setWindowDecorVisible. Cause code: ${exception.code}, message: ${exception.message}`,
        );
      }
      try {
        windowClass.setWindowKeepScreenOn(true, (err: BusinessError) => {
          if (err.code) {
            console.error(
              "Failed to set the screen to be always on. Cause: " + JSON.stringify(err),
            );
            return;
          }
        });
      } catch (exception) {
        console.error(
          "Failed to set the screen to be always on. Cause: " + JSON.stringify(exception),
        );
      }
      try {
        windowClass.setWindowLayoutFullScreen(true);
        windowClass.setWindowSystemBarEnable([]);
      } catch (exception) {
        console.error(
          `Failed to set the window layout to full-screen mode. Cause code: ${exception.code}, message: ${exception.message}`,
        );
      }
    });
    windowStage.loadContent("pages/Index", (err) => {
      if (err.code) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to load the content. Cause: %{public}s",
          JSON.stringify(err),
        );
        return;
      }
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onWindowStageDestroy");
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onForeground");
    XComponentHolder.ifPresent((ctx: ESObject): void => {
      ctx.onForeground();
    });
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onBackground");
    XComponentHolder.ifPresent((ctx: ESObject): void => {
      ctx.onBackground();
    });
  }
}
