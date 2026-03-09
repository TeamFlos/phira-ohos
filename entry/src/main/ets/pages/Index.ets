import { InputDialog } from '../components/InputDialog';
import {
  callFilePickerAndProcess,
  callFilePickerSaveFile,
  getSystemInfo,
  startBrowsableAbility
} from '../utils/AbilityUtils';
import { common } from '@kit.AbilityKit';
import { InputBoxRequest, InputBoxResponse } from 'libphira.so';
ce ShowInputWindowCommand {
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

type ArkTSCommand = ShowInputWindowCommand | OpenUrlCommand | ShowMessageCommand | ChooseFileCommand
  | RequestExportCommand;

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
    id: 'xcomponentId',
    type: XComponentType.SURFACE,
    libraryname: 'phira'
  }
  @State showInput: boolean = false;
  @State context: common.UIAbilityContext = this.getUIContext().getHostContext()! as common.UIAbilityContext;
  @StorageLink('pendingImportFile') @Watch('onPendingImportChange') pendingImportFile: string = '';
  @State currentRequest: InputBoxRequest | null = null;
  private inputDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    console.log("system info:" + getSystemInfo());
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
            text: text
          };
          this.xComponentContext.setInterceptorState(true);
          this.xComponentContext!.onInputboxResponse(response);
          this.inputDialogController = null;
        },
        onCancel: () => {
          const response: InputBoxResponse = {
            callback: request.callback,
            text: undefined
          };
          this.xComponentContext.setInterceptorState(true);
          this.xComponentContext!.onInputboxResponse(response);
          this.inputDialogController = null;
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true
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
              if (!command || typeof command.action !== 'string') {
                return;
              }
              switch (command.action) {
                case "openurl":
                  const url = command.payload;
                  if (typeof url === 'string' && url) {
                    startBrowsableAbility(this.context, url);
                  }
                  break;
                case "chooseFile":
                  callFilePickerAndProcess(this.xComponentContext, this.context, command.isPhoto);
                  break;
                case "request_export":
                  const filename = command.filename;
                  if (typeof filename === 'string' && filename) {
                    callFilePickerSaveFile(filename).then((result) => {
                      if (result) {
                        this.xComponentContext!.processExportFdOhos(result.fd);
                      } else {
                        console.log('request_export: user cancelled or error occurred');
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
          });
          this.processPendingImport();
        })
        .focusable(true)
        .defaultFocus(true)
        .constraintSize({ maxWidth: '100%', maxHeight: '100%' })
    }
    .height('100%')
  }

  private processPendingImport(): void {
    const pendingFile = AppStorage.get<string>('pendingImportFile');
    if (pendingFile && this.xComponentContext) {
      console.info('Processing pending import file: ' + pendingFile);
      this.xComponentContext.setChosenFile(pendingFile);
      this.xComponentContext.markAutoImport();
      AppStorage.set('pendingImportFile', '');
    }
  }
  onBackPress(): boolean {
    return true;
  }
}
