import { common, Want } from "@kit.AbilityKit";
import { BusinessError, deviceInfo } from "@kit.BasicServicesKit";
import bundleManager from "@ohos.bundle.bundleManager";
import { taskpool } from "@kit.ArkTS";
import { picker, fileIo } from "@kit.CoreFileKit";
import fs from "@ohos.file.fs";
import { photoAccessHelper } from "@kit.MediaLibraryKit";

const OPENGTX_DISABLE_FLAG = "/data/storage/el2/base/disable_opengtx";
const PERFORMANCE_CLASS_NAMES: string[] = ["HighLevel", "MediumLevel", "LowLevel"];

@Concurrent
function clearCacheDir(cacheDir: string): void {
  try {
    if (!fileIo.accessSync(cacheDir)) {
      return;
    }
    for (const file of fileIo.listFileSync(cacheDir)) {
      const filePath = `${cacheDir}/${file}`;
      if (fileIo.statSync(filePath).isDirectory()) {
        fileIo.rmdirSync(filePath);
      } else {
        fileIo.unlinkSync(filePath);
      }
    }
  } catch (err) {
    console.error("Failed to clear cache directory: " + JSON.stringify(err));
  }
}

export function executeClearCacheTask(cacheDir: string): void {
  taskpool.execute(new taskpool.Task(clearCacheDir, cacheDir)).catch((err: BusinessError) => {
    console.error("Cache cleanup task failed: " + JSON.stringify(err));
  });
}

export interface FileSaveResult {
  uri: string;
  fd: number;
}

export function startBrowsableAbility(context: common.UIAbilityContext, url: string): void {
  const want: Want = {
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

async function closeQuietly(file: fs.File | number, label: string): Promise<void> {
  try {
    await fs.close(file);
  } catch (err) {
    console.error(`${label}: ${(err as BusinessError).message}`);
  }
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
      const mode = fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC;
      fs.closeSync(fs.openSync(OPENGTX_DISABLE_FLAG, mode));
    }
    return true;
  } catch (error) {
    console.error("Failed to update OpenGTX state: " + JSON.stringify(error));
    return false;
  }
}

export function getSystemInfo(): string {
  try {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
    );
    const performanceClass = PERFORMANCE_CLASS_NAMES[deviceInfo.performanceClass] ?? "unknown";
    const openGtxState = isOpenGtxDisabled() ? "OpenGTX:off" : "OpenGTX:on";
    const systemInfo =
      `${deviceInfo.marketName}(${deviceInfo.deviceType})` +
      `${deviceInfo.displayVersion}(${deviceInfo.sdkApiVersion})` +
      ` ${deviceInfo.chipType || "Unknown CPU"}(${performanceClass})` +
      ` ${bundleInfo.name} ${openGtxState} 测试版本，不代表最终游戏品质`;
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
      await closeQuietly(sourceFile, "Failed to close file");
    }
  }
}

async function pickPhotoUri(): Promise<string | undefined> {
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 1;
  try {
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    const uris = result?.photoUris;
    return uris && uris.length > 0 ? uris[0] : undefined;
  } catch (err) {
    const error = err as BusinessError;
    console.error(`pick photo error: ${error.code}, ${error.message}`);
    return undefined;
  }
}

async function pickDocumentUri(): Promise<string | undefined> {
  const options = new picker.DocumentSelectOptions();
  //options.fileSuffixFilters = [".pez", ".zip"];
  options.maxSelectNumber = 1;
  try {
    const result = await new picker.DocumentViewPicker().select(options);
    return result && result.length > 0 ? result[0] : undefined;
  } catch (err) {
    const error = err as BusinessError;
    console.error(`pick document error: ${error.code}, ${error.message}`);
    return undefined;
  }
}

export async function callFilePickerAndProcess(
  xComponentContext: ESObject,
  context: common.UIAbilityContext,
  isPhoto: boolean = false,
): Promise<void> {
  try {
    const uri = isPhoto ? await pickPhotoUri() : await pickDocumentUri();
    if (uri) {
      const localPath = await copyUriToTempFile(context, uri);
      xComponentContext!.setChosenFile(localPath);
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
      await closeQuietly(src, "exportCrashLog close src failed");
      await closeQuietly(saveResult.fd, "exportCrashLog close dst failed");
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
    const saveOptions = new picker.DocumentSaveOptions();
    saveOptions.newFileNames = [filename];
    const saveResult = await new picker.DocumentViewPicker().save(saveOptions);
    if (!saveResult || saveResult.length === 0) {
      return undefined;
    }
    const uri = saveResult[0];
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      return { uri, fd: file.fd };
    } catch (openErr) {
      console.error(
        `callFilePickerSaveFile failed to open file: ${(openErr as BusinessError).message}`,
      );
      return { uri, fd: -1 };
    }
  } catch (err) {
    const error = err as BusinessError;
    console.error(`callFilePickerSaveFile error: ${error.code}, ${error.message}`);
    return undefined;
  }
}
