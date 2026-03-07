import { InputDialog } from '../components/InputDialog';
import { startBrowsableAbility, getSystemInfo, callFilePickerAndProcess } from '../utils/AbilityUtils';
import { common } from '@kit.AbilityKit';

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
type ArkTSCommand = ShowInputWindowCommand | OpenUrlCommand | ShowMessageCommand | ChooseFileCommand;

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

  aboutToAppear(): void {
    console.log("system info:" + getSystemInfo());
  }

  private isPasswordInput: boolean = false;

  onPendingImportChange(): void {
    if (this.xComponentContext && this.pendingImportFile) {
      this.processPendingImport();
    }
  }

  private processPendingImport(): void {
    const pendingFile = AppStorage.get<string>('pendingImportFile');
    if (pendingFile && this.xComponentContext) {
      console.info('Processing pending import file: ' + pendingFile);
      this.xComponentContext.setChosenFile(pendingFile);
      this.xComponentContext.markImport();
      AppStorage.set('pendingImportFile', '');
    }
  }

  dialogController: CustomDialogController = new CustomDialogController({
    builder: InputDialog({
      isPassword: this.isPasswordInput,
      onConfirm: (text: string) => {
        this.xComponentContext.setInterceptorState(true);
        this.xComponentContext.setInputText(text);
      },
      onCancel: () => {
        this.xComponentContext.setInterceptorState(true);
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent(this.xComponentAttrs)
        .onLoad((xComponentContext) => {
          this.xComponentContext = xComponentContext;
          this.xComponentContext!.registerArktsCallback((arg: string) => {
            try {
              const command = JSON.parse(arg) as ArkTSCommand;
              if (!command || typeof command.action !== 'string') {
                return;
              }
              switch (command.action) {
                case "show_input_window":
                  this.isPasswordInput = command.isPassword ?? false;
                  this.xComponentContext!.setInterceptorState(false);
                  this.dialogController.open();
                  break;
                case "openurl":
                  const url = command.payload;
                  if (typeof url === 'string' && url) {
                    startBrowsableAbility(this.context, url);
                  }
                  break;
                case "chooseFile":
                  callFilePickerAndProcess(this.xComponentContext, this.context, command.isPhoto);
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
  onBackPress(): boolean {
    return true;
  }
}
