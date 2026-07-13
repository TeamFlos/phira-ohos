import { common, Want } from "@kit.AbilityKit";
import { BusinessError, deviceInfo } from "@kit.BasicServicesKit";
import bundleManager from "@ohos.bundle.bundleManager";
import { JSON, taskpool } from "@kit.ArkTS";
import { picker, fileIo } from "@kit.CoreFileKit";
import fs from "@ohos.file.fs";
import { photoAccessHelper } from "@kit.MediaLibraryKit";

const OPENGTX_DISABLE_FLAG = "/data/storage/el2/base/disable_opengtx";

@Concurrent
function clearCacheDir(cacheDir: string): void {
  try {
    if (fileIo.accessSync(cacheDir)) {
      const files = fileIo.listFileSync(cacheDir);
      for (const file of files) {
        const filePath = cacheDir + "/" + file;
        const stat = fileIo.statSync(filePath);
        if (stat.isDirectory()) {
          fileIo.rmdirSync(filePath);
        } else {
          fileIo.unlinkSync(filePath);
        }
      }
    }
  } catch (err) {
    console.error("Failed to clear cache directory: " + JSON.stringify(err));
  }
}

export function executeClearCacheTask(cacheDir: string): void {
  const task = new taskpool.Task(clearCacheDir, cacheDir);
  taskpool.execute(task).catch((err: BusinessError) => {
    console.error("Cache cleanup task failed: " + JSON.stringify(err));
  });
}

export interface FileSaveResult {
  uri: string;
  fd: number;
}

export function startBrowsableAbility(context: common.UIAbilityContext, url: string): void {
  let want: Want = {
    action: "ohos.want.action.viewData",
    entities: ["entity.system.browsable"],
    uri: url,
    parameters: {
      "ohos.ability.params.showDefaultPicker": true,
    },
  };
  context.startAbility(want).catch((err: BusinessError) => {
    console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
  });
}
//todo: judge if OpenHarmony or HarmonyOS, if OpenHarmony, then disable OpenGTX
//these function are used to debug enable/disable OpenGTX

function isOpenGtxDisabled(): boolean {
  try {
    return fs.accessSync(OPENGTX_DISABLE_FLAG);
  } catch (error) {
    console.error("Failed to check OpenGTX state: " + JSON.stringify(error));
    return false;
  }
}

export function setOpenGtxEnabled(enabled: boolean): boolean {
  try {
    if (enabled) {
      if (isOpenGtxDisabled()) {
        fs.unlinkSync(OPENGTX_DISABLE_FLAG);
      }
    } else {
      const file = fs.openSync(
        OPENGTX_DISABLE_FLAG,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC,
      );
      fs.closeSync(file);
    }
    return true;
  } catch (error) {
    console.error("Failed to update OpenGTX state: " + JSON.stringify(error));
    return false;
  }
}

export function getSystemInfo(): string {
  try {
    let bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
    );
    let appBundleName = bundleInfo.name;
    let deviceModel = deviceInfo.marketName;
    let osVersion = deviceInfo.displayVersion;
    let sdkApi = deviceInfo.sdkApiVersion;
    let cpuModel = deviceInfo.chipType || "Unknown CPU";
    let performanceClassNum = deviceInfo.performanceClass;
    let devicetype = deviceInfo.deviceType;
    let performanceClassStr = "unknown";
    switch (performanceClassNum) {
      case 0:
        performanceClassStr = "HighLevel";
        break;
      case 1:
        performanceClassStr = "MediumLevel";
        break;
      case 2:
        performanceClassStr = "LowLevel";
        break;
      default:
        performanceClassStr = "unknown";
    }
    const openGtxState = !isOpenGtxDisabled() ? "OpenGTX:on" : "OpenGTX:off";
    const systemInfo = `${deviceModel}(${devicetype})${osVersion}(${sdkApi}) ${cpuModel}(${performanceClassStr}) ${appBundleName} ${openGtxState} 测试版本，不代表最终游戏品质`;
    console.error("system info:" + systemInfo);
    return systemInfo;
  } catch (error) {
    console.error("Failed to get system info: " + JSON.stringify(error));
    return "Debug Info Load Failed";
  }
}

export async function copyUriToTempFile(
  context: common.UIAbilityContext,
  sourceUri: string,
): Promise<string | undefined> {
  const tempFilePath = `${context.cacheDir}/temp_${Date.now()}`;
  let sourceFile: fs.File | null = null;
  try {
    sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);
    await fs.copyFile(sourceFile.fd, tempFilePath);
    return tempFilePath;
  } catch (err) {
    const error = err as BusinessError;
    console.error(`copy file error: ${error.code}, ${error.message}`);
    return undefined;
  } finally {
    if (sourceFile) {
      try {
        await fs.close(sourceFile);
      } catch (err) {
        console.error(`Failed to close file: ${(err as BusinessError).message}`);
      }
    }
  }
}

export async function callFilePickerAndProcess(
  xComponentContext: ESObject,
  context: common.UIAbilityContext,
  isPhoto: boolean = false,
): Promise<void> {
  try {
    if (isPhoto) {
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoPicker.select(photoSelectOptions);
      if (
        photoSelectResult &&
        photoSelectResult.photoUris &&
        photoSelectResult.photoUris.length > 0
      ) {
        const uri = photoSelectResult.photoUris[0];
        const localPath = await copyUriToTempFile(context, uri);
        xComponentContext!.setChosenFile(localPath);
      }
    } else {
      let documentPicker = new picker.DocumentViewPicker();
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.fileSuffixFilters = [".pez", ".zip"];
      documentSelectOptions.maxSelectNumber = 1;
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult && documentSelectResult.length > 0) {
        const uri = documentSelectResult[0];
        const localPath = await copyUriToTempFile(context, uri);
        xComponentContext!.setChosenFile(localPath);
      }
    }
  } catch (err) {
    const error = err as BusinessError;
    console.error(`error: ${error.code}, ${error.message}`);
  }
}

export async function isDebugVersion(): Promise<boolean> {
  try {
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
    );
    return bundleInfo.appInfo.appProvisionType === "debug";
  } catch (err) {
    console.error(`Failed to get bundle info: ${err.message}`);
    return false;
  }
}

export async function exportCrashLog(crashLogPath: string): Promise<boolean> {
  try {
    const saveResult = await callFilePickerSaveFile(`crash_log_${Date.now()}.log`);
    if (!saveResult) {
      return false;
    }
    const src = await fs.open(crashLogPath, fs.OpenMode.READ_ONLY);
    try {
      await fs.copyFile(src.fd, saveResult.fd);
      return true;
    } finally {
      try {
        await fs.close(src);
      } catch (err) {
        console.error(`exportCrashLog close src failed: ${(err as BusinessError).message}`);
      }
      try {
        await fs.close(saveResult.fd);
      } catch (err) {
        console.error(`exportCrashLog close dst failed: ${(err as BusinessError).message}`);
      }
    }
  } catch (err) {
    console.error(`exportCrashLog error: ${(err as BusinessError).message}`);
    return false;
  }
}

export async function callFilePickerSaveFile(
  filename: string,
): Promise<FileSaveResult | undefined> {
  try {
    let documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [filename];
    let documentPicker = new picker.DocumentViewPicker();
    const documentSaveResult = await documentPicker.save(documentSaveOptions);
    if (documentSaveResult && documentSaveResult.length > 0) {
      const uri = documentSaveResult[0];
      let file: fs.File | null = null;
      try {
        file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        const fd = file.fd;
        return { uri, fd };
      } catch (openErr) {
        console.error(
          `callFilePickerSaveFile failed to open file: ${(openErr as BusinessError).message}`,
        );
        return { uri, fd: -1 };
      }
    }
    return undefined;
  } catch (err) {
    const error = err as BusinessError;
    console.error(`callFilePickerSaveFile error: ${error.code}, ${error.message}`);
    return undefined;
  }
}
