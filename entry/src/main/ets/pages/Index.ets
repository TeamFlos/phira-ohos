import { InputDialog } from "../components/InputDialog";
import {
  callFilePickerAndProcess,
  callFilePickerSaveFile,
  exportCrashLog,
  getSystemInfo,
  startBrowsableAbility,
} from "../utils/AbilityUtils";
import { common } from "@kit.AbilityKit";
import { InputBoxRequest, InputBoxResponse } from "libphira.so";
import { mediaquery, promptAction } from "@kit.ArkUI";
import { BusinessError } from "@kit.BasicServicesKit";

interface ShowInputWindowCommand {
  action: "show_input_window";
  isPassword: boolean;
}
interface OpenUrlCommand {
  action: "openurl";
  payload: string;
}
interface ShowMessageCommand {
  action: "show_message";
  message: string;
  title: string;
}
interface ChooseFileCommand {
  action: "chooseFile";
  isPhoto: boolean;
}

interface RequestExportCommand {
  action: "request_export";
  filename: string;
}
interface InterceptorStateCommand {
  action: "interceptor_state";
  state: boolean;
}

type ArkTSCommand =
  | ShowInputWindowCommand
  | OpenUrlCommand
  | ShowMessageCommand
  | ChooseFileCommand
  | RequestExportCommand
  | InterceptorStateCommand;

interface XComponentAttrs {
  id: string;
  type: number;
  libraryname: string;
}

@Entry
@Component
struct Index {
  xComponentContext: ESObject = undefined;
  xComponentAttrs: XComponentAttrs = {
    id: "xcomponentId",
    type: XComponentType.SURFACE,
    libraryname: "phira",
  };
  @State interceptorState: boolean = false;
  @State showInput: boolean = false;
  @State context: common.UIAbilityContext =
    this.getUIContext().getHostContext()! as common.UIAbilityContext;
  @StorageLink("pendingImportFile") @Watch("onPendingImportChange") pendingImportFile: string = "";
  @StorageLink("pendingCrashLog") @Watch("onCrashLogChange") pendingCrashLog: string = "";
  @State currentRequest: InputBoxRequest | null = null;
  private inputDialogController: CustomDialogController | null = null;
  @State isPhone: boolean = true;
  private listener = this.getUIContext().getMediaQuery().matchMediaSync("(max-width: 600vp)");

  aboutToAppear(): void {
    PersistentStorage.persistProp("isFirstLaunch", true);
    console.log("system info:" + getSystemInfo());
    this.listener.on("change", (mediaQueryResult: mediaquery.MediaQueryResult) => {
      this.isPhone = mediaQueryResult.matches;
    });
    if (this.pendingCrashLog && this.pendingCrashLog.length > 0) {
      this.showCrashDialog();
    }
  }

  onCrashLogChange(): void {
    if (this.pendingCrashLog && this.pendingCrashLog.length > 0) {
      this.showCrashDialog();
    }
  }

  private showCrashDialog(): void {
    const prompt = this.getUIContext().getPromptAction();
    const buttons: promptAction.Button[] = [
      { text: $r("app.string.crash_dialog_button_export"), color: "#0A59F7", primary: true },
      { text: $r("app.string.crash_dialog_button_close"), color: "#666666" },
    ];
    prompt
      .showDialog({
        title: $r("app.string.crash_dialog_title"),
        message: $r("app.string.crash_dialog_message"),
        buttons: buttons,
      })
      .then((result) => {
        const currentLog = this.pendingCrashLog;
        AppStorage.set("pendingCrashLog", "");
        if (result.index !== 0 || !currentLog) {
          return;
        }
        exportCrashLog(currentLog).then((ok) => {
          if (!ok) {
            prompt.showToast({
              message: $r("app.string.crash_toast_export_failed"),
              duration: 2000,
            });
          } else {
            prompt.showToast({
              message: $r("app.string.crash_toast_export_success"),
              duration: 1500,
            });
          }
        });
      })
      .catch((error: BusinessError) => {
        console.error("Failed to show crash dialog: " + JSON.stringify(error));
      });
  }

  aboutToDisappear(): void {
    this.listener.off("change");
  }

  onPendingImportChange(): void {
    if (this.xComponentContext && this.pendingImportFile) {
      this.processPendingImport();
    }
  }

  showInputDialog(request: InputBoxRequest): void {
    this.currentRequest = request;
    this.inputDialogController = new CustomDialogController({
      builder: InputDialog({
        title: request.title,
        prompt: request.prompt,
        defaultValue: request.defaultValue,
        mode: request.mode,
        okLabel: request.okLabel,
        cancelLabel: request.cancelLabel,
        onConfirm: (text: string) => {
          const response: InputBoxResponse = {
            callback: request.callback,
            text: text,
          };
          this.xComponentContext!.onInputboxResponse(response);
          this.inputDialogController = null;
        },
        onCancel: () => {
          const response: InputBoxResponse = {
            callback: request.callback,
            text: undefined,
          };
          this.xComponentContext!.onInputboxResponse(response);
          this.inputDialogController = null;
        },
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true,
    });

    this.inputDialogController.open();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent(this.xComponentAttrs)
        .onLoad((xComponentContext) => {
          this.xComponentContext = xComponentContext;
          this.xComponentContext!.registerInputboxCallback((request: InputBoxRequest) => {
            this.xComponentContext.setInterceptorState(false);
            this.showInputDialog(request);
          });
          this.xComponentContext!.registerArktsCallback((arg: string) => {
            try {
              const command = JSON.parse(arg) as ArkTSCommand;
              if (!command || typeof command.action !== "string") {
                return;
              }
              switch (command.action) {
                case "interceptor_state":
                  this.interceptorState = command.state;
                  break;
                case "openurl":
                  const url = command.payload;
                  if (typeof url === "string" && url) {
                    startBrowsableAbility(this.context, url);
                  }
                  break;
                case "chooseFile":
                  callFilePickerAndProcess(this.xComponentContext, this.context, command.isPhoto);
                  break;
                case "request_export":
                  const filename = command.filename;
                  if (typeof filename === "string" && filename) {
                    callFilePickerSaveFile(filename).then((result) => {
                      if (result) {
                        this.xComponentContext!.processExportFdOhos(result.fd);
                      } else {
                        console.log("request_export: user cancelled or error occurred");
                      }
                    });
                  }
                  break;
                default:
                  break;
              }
            } catch (error) {
              console.error(
                "Failed to parse argument as JSON. Raw argument: ",
                arg,
                "Error: ",
                error,
              );
            }
          });
          this.processPendingImport();
        })
        .focusable(true)
        .defaultFocus(true)
        .constraintSize({ maxWidth: "100%", maxHeight: "100%" })
    }.height("100%");
  }

  private processPendingImport(): void {
    const pendingFile = AppStorage.get<string>("pendingImportFile");
    if (pendingFile && this.xComponentContext) {
      console.info("Processing pending import file: " + pendingFile);
      this.xComponentContext.setChosenFile(pendingFile);
      this.xComponentContext.markAutoImport();
      AppStorage.set("pendingImportFile", "");
    }
  }
  onBackPress(): boolean {
    return this.interceptorState;
  }
}
