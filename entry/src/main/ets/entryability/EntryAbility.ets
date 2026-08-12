import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from "@kit.AbilityKit";
import { hilog, hiAppEvent } from "@kit.PerformanceAnalysisKit";
import { window } from "@kit.ArkUI";
import { BusinessError } from "@kit.BasicServicesKit";
import { copyUriToTempFile, executeClearCacheTask } from "../utils/AbilityUtils";
import { XComponentHolder } from "../utils/XComponentHolder";

const DOMAIN = 0x0000;
const TAG = "Phira-ohos";

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
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
      appEventFilters: [{ domain: hiAppEvent.domain.OS, names: [hiAppEvent.event.APP_CRASH] }],
      onReceive: (_domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
        for (const group of appEventGroups) {
          for (const info of group.appEventInfos) {
            const externalLog = info.params["external_log"] as string[];
            if (externalLog && externalLog.length > 0) {
              AppStorage.setOrCreate("pendingCrashLog", externalLog[0]);
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

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onNewWant");
    this.handleWant(want);
  }

  private async handleWant(want: Want): Promise<void> {
    if (!want.uri) {
      executeClearCacheTask(this.context.cacheDir);
      return;
    }
    hilog.info(DOMAIN, TAG, "Received file URI: %{public}s", want.uri);
    try {
      const tempFilePath = await copyUriToTempFile(this.context, want.uri);
      if (!tempFilePath) {
        hilog.error(DOMAIN, TAG, "Failed to copy file to temp directory");
        return;
      }
      AppStorage.setOrCreate("pendingImportFile", tempFilePath);
      hilog.info(DOMAIN, TAG, "Saved pending import file: %{public}s", tempFilePath);
    } catch (err) {
      hilog.error(
        DOMAIN,
        TAG,
        "Failed to handle file import. Cause: %{public}s",
        JSON.stringify(err),
      );
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onDestroy");
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "Ability onWindowStageCreate");
    windowStage.getMainWindow(async (err: BusinessError, windowClass: window.Window) => {
      if (err.code) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to obtain the main window. Cause code: %{public}s, message: %{public}s",
          err.code,
          err.message,
        );
        return;
      }
      try {
        windowClass.setWindowDecorVisible(false);
      } catch (e) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to setWindowDecorVisible. Cause: %{public}s",
          JSON.stringify(e),
        );
      }
      try {
        await windowClass.setWindowKeepScreenOn(true);
      } catch (e) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to set the screen to be always on. Cause: %{public}s",
          JSON.stringify(e),
        );
      }
      try {
        await windowClass.setWindowLayoutFullScreen(true);
        await windowClass.setWindowSystemBarEnable([]);
      } catch (e) {
        hilog.error(
          DOMAIN,
          TAG,
          "Failed to set the window layout to full-screen mode. Cause: %{public}s",
          JSON.stringify(e),
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
