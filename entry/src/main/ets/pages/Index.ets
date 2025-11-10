import { InputDialog } from '../components/InputDialog';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { JSON } from '@kit.ArkTS';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';

interface ShowMessagePayload {
  message: string;
  title?: string;
}
interface ShowInputWindowCommand {
  action: "show_input_window";
}
interface OpenUrlCommand {
  action: "openurl";
  payload: string;
}
interface ShowMessageCommand {
  action: "show_message";
  payload: ShowMessagePayload;
}
interface ChooseFileCommand {
  action: "chooseFile";
}
type ArkTSCommand = ShowInputWindowCommand | OpenUrlCommand | ShowMessageCommand | ChooseFileCommand;

interface XComponentAttrs {
  id: string;
  type: number;
  libraryname: string;
}

function startBrowsableAbility(context: common.UIAbilityContext,url:string): void {
  let want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url,
    parameters: {
      'ohos.ability.params.showDefaultPicker': true
    }
  };
  context.startAbility(want).catch((err: BusinessError) => {
      console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
    });
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
  @State uri: string = 'Hello World';
  @State showInput: boolean = false;

  async copyUriToTempFile(context: common.UIAbilityContext, sourceUri: string): Promise<string | undefined> {
    const tempDir = context.cacheDir;
    const tempFileName = `chart_${Date.now()}.zip`;
    const tempFilePath = `${tempDir}/${tempFileName}`;
    let sourceFd: number = -1;
    let destFd: number = -1;
    try {
      const sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);
      sourceFd = sourceFile.fd;
      const destFile = await fs.open(tempFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      destFd = destFile.fd;
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let bytesRead = 0;
      do {
        bytesRead = await fs.read(sourceFd, buffer);
        if (bytesRead > 0) {
          await fs.write(destFd, buffer, { length: bytesRead });
        }
      } while (bytesRead > 0);
      return tempFilePath;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`copy file error: ${error.code}, ${error.message}`);
      return undefined;
    } finally {
      if (sourceFd !== -1) {
        await fs.close(sourceFd);
      }
      if (destFd !== -1) {
        await fs.close(destFd);
      }
    }
  }


  async callFilePickerAndProcess() {
    try {
      let documentPicker = new picker.DocumentViewPicker();
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.fileSuffixFilters = ['.zip',];
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult && documentSelectResult.length > 0) {
        const uri = documentSelectResult[0];
        const context = getContext(this) as common.UIAbilityContext;
        const localPath = await this.copyUriToTempFile(context, uri);
        this.xComponentContext!.setChosenFile(localPath);
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`error: ${error.code}, ${error.message}`);
    }
  }

  dialogController: CustomDialogController = new CustomDialogController({
    builder: InputDialog({
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
                  this.xComponentContext!.setInterceptorState(false);
                  this.dialogController.open();
                  break;
                case "openurl":
                  const url = command.payload;
                  if (typeof url === 'string' && url) {
                    const context: common.UIAbilityContext = this.getUIContext().getHostContext()! as common.UIAbilityContext;
                    startBrowsableAbility(context, url);
                  }
                  break;
                case "chooseFile":
                  this.callFilePickerAndProcess();
                  break;
                case "show_message":
                  const msg = command.payload?.message;
                  if (typeof msg === 'string') {
                    this.xComponentContext!.setInterceptorState(false);
                    this.getUIContext().showAlertDialog({
                      title: 'phira',
                      message: msg,
                      autoCancel: false,
                      alignment: DialogAlignment.Center,
                      offset: { dx: 0, dy: -20 },
                      gridCount: 3,
                      buttons: [{
                        value: 'cancel',
                        action: () => {
                          this.xComponentContext!.setInterceptorState(true);
                        }
                      },
                        {
                          enabled: true,
                          defaultFocus: true,
                          style: DialogButtonStyle.HIGHLIGHT,
                          value: 'ok',
                          action: () => {
                            this.xComponentContext!.setInterceptorState(true);
                          }
                        }],
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
