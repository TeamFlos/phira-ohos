import { InputDialog } from "../components/InputDialog";
import {
  callFilePickerAndProcess,
  callFilePickerSaveFile,
  exportCrashLog,
  getSystemInfo,
  startBrowsableAbility,
} from "../utils/AbilityUtils";
import { XComponentHolder } from "../utils/XComponentHolder";
import { common } from "@kit.AbilityKit";
import { InputBoxRequest, InputBoxResponse } from "libphira.so";
import { mediaquery } from "@kit.ArkUI";
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
    this.showCrashDialog();
  }

  aboutToDisappear(): void {
    this.listener.off("change");
    XComponentHolder.clear();
  }

  onCrashLogChange(): void {
    this.showCrashDialog();
  }

  onPendingImportChange(): void {
    if (this.pendingImportFile) {
      this.processPendingImport();
    }
  }

  onBackPress(): boolean {
    return this.interceptorState;
  }

  private showCrashDialog(): void {
    if (!this.pendingCrashLog) {
      return;
    }
    const prompt = this.getUIContext().getPromptAction();
    prompt
      .showDialog({
        title: $r("app.string.crash_dialog_title"),
        message: $r("app.string.crash_dialog_message"),
        buttons: [
          { text: $r("app.string.crash_dialog_button_export"), color: "#0A59F7", primary: true },
          { text: $r("app.string.crash_dialog_button_close"), color: "#666666" },
        ],
      })
      .then((result) => {
        const currentLog = this.pendingCrashLog;
        AppStorage.set("pendingCrashLog", "");
        if (result.index !== 0 || !currentLog) {
          return;
        }
        exportCrashLog(currentLog).then((ok) => {
          try {
            prompt.showToast({
              message: ok
                ? $r("app.string.crash_toast_export_success")
                : $r("app.string.crash_toast_export_failed"),
              duration: ok ? 1500 : 2000,
            });
          } catch (err) {
            console.error("Failed to show toast: " + JSON.stringify(err));
          }
        });
      })
      .catch((error: BusinessError) => {
        console.error("Failed to show crash dialog: " + JSON.stringify(error));
      });
  }

  showInputDialog(request: InputBoxRequest): void {
    this.currentRequest = request;
    const respond = (text?: string): void => {
      const response: InputBoxResponse = {
        callback: request.callback,
        text: text,
      };
      XComponentHolder.ifPresent((context: ESObject): void => {
        context.onInputboxResponse(response);
      });
      this.inputDialogController = null;
    };
    this.inputDialogController = new CustomDialogController({
      builder: InputDialog({
        title: request.title,
        prompt: request.prompt,
        defaultValue: request.defaultValue,
        mode: request.mode,
        okLabel: request.okLabel,
        cancelLabel: request.cancelLabel,
        onConfirm: (text: string) => respond(text),
        onCancel: () => respond(),
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true,
    });
    this.inputDialogController.open();
  }

  private handleNativeCommand(context: ESObject, arg: string): void {
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
          if (command.payload) {
            startBrowsableAbility(this.context, command.payload);
          }
          break;
        case "chooseFile":
          callFilePickerAndProcess(context, this.context, command.isPhoto);
          break;
        case "request_export":
          if (command.filename) {
            callFilePickerSaveFile(command.filename).then((result) => {
              if (result) {
                context.processExportFdOhos(result.fd);
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
      console.error("Failed to parse argument as JSON. Raw argument: ", arg, "Error: ", error);
    }
  }

  private processPendingImport(): void {
    const pendingFile = AppStorage.get<string>("pendingImportFile");
    if (!pendingFile) {
      return;
    }
    XComponentHolder.ifPresent((context: ESObject): void => {
      console.info("Processing pending import file: " + pendingFile);
      context.setChosenFile(pendingFile);
      context.markAutoImport();
      AppStorage.set("pendingImportFile", "");
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent(this.xComponentAttrs)
        .onLoad((xComponentContext) => {
          const context: ESObject = xComponentContext;
          XComponentHolder.set(context);
          context.registerInputboxCallback((request: InputBoxRequest) => {
            context.setInterceptorState(false);
            this.showInputDialog(request);
          });
          context.registerArktsCallback((arg: string) => this.handleNativeCommand(context, arg));
          this.processPendingImport();
        })
        .focusable(true)
        .defaultFocus(true)
        .constraintSize({ maxWidth: "100%", maxHeight: "100%" })
    }.height("100%");
  }
}
