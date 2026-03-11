export interface PermissionGroupConfig {
  groupName: string;
  icon: ResourceStr;
  title: ResourceStr;
  readAndWrite?: ResourceStr;
  reason: ResourceStr;
  buttonList: ResourceStr[];
}

@Extend(Button)
function customizeButton() {
  .buttonStyle(ButtonStyleMode.TEXTUAL)
  .fontColor($r('sys.color.font_emphasize'))
  .height(40)
}

@Extend(Text)
function titleText() {
  .fontWeight(FontWeight.Bold)
  .fontColor($r('sys.color.font_primary'))
  .textAlign(TextAlign.Center)
  .textOverflow({ overflow: TextOverflow.Ellipsis })
  .maxLines(2)
}

@CustomDialog
export struct MockPermissionDialog {
  controller?: CustomDialogController;
  @Prop isPhone: boolean;
  @Prop grantGroups: PermissionGroupConfig[];
  @State curIndex: number = 0;
  onResult?: (actionIndex: number, groupName: string) => void;

  calculateButtonWidth(buttonList: ResourceStr[]): boolean {
    if (!buttonList || buttonList.length < 2) {
      return true;
    }
    let denyText = buttonList[0];
    let allowText = buttonList[1];

    let maxButtonTextLength = Math.max(
      this.getUIContext().getMeasureUtils().measureText({ textContent: denyText }),
      this.getUIContext().getMeasureUtils().measureText({ textContent: allowText })
    );

    if (px2vp(maxButtonTextLength) > 135) {
      return false;
    }
    return true;
  }

  processClick(actionIndex: number) {
    if (this.onResult) {
      this.onResult(actionIndex, this.grantGroups[this.curIndex].groupName);
    }
    if (this.curIndex < this.grantGroups.length - 1) {
      this.curIndex++;
    } else {
      this.controller?.close();
    }
  }

  @Builder
  DialogTitle() {
    Row() {
      Column() {
        Text(this.grantGroups[this.curIndex].title)
          .titleText()
          .minFontSize(16)
          .maxFontSize(20)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
      }
      .constraintSize({ minHeight: 56 })
      .justifyContent(FlexAlign.Center)
      .padding({
        top: 12,
        left: 24,
        right: 24
      })
    }
  }

  build() {
    Column() {
      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Column() {
          Image(this.grantGroups[this.curIndex].icon)
            .width(24)
            .height(24)
            .fillColor($r('sys.color.font_primary'))
            .margin({ top: 23 })
          if (this.grantGroups.length > 1) {
            Text(`${this.curIndex + 1} / ${this.grantGroups.length}`)
              .fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
              .lineHeight(14)
              .margin({ top: 2 })
          }
          Scroll() {
            Column() {
              this.DialogTitle()
              Row() {
                Flex({ justifyContent: FlexAlign.Center }) {
                  Text() {
                    if (this.grantGroups[this.curIndex].readAndWrite) {
                      Span(this.grantGroups[this.curIndex].readAndWrite)
                      Span(this.grantGroups[this.curIndex].reason ? '，' : '。')
                    }
                    Span(this.grantGroups[this.curIndex].reason)
                  }
                  .textAlign(TextAlign.Start)
                  .fontColor($r('sys.color.font_primary'))
                  .fontSize(16)
                  .maxFontScale(3.2)
                  .margin({
                    left: 24,
                    right: 24,
                    bottom: 8
                  })
                }
              }
            }
          }
          .constraintSize({ maxHeight: 500 })

          if (
            this.grantGroups[this.curIndex].buttonList.length <= 2 &&
              this.calculateButtonWidth(this.grantGroups[this.curIndex].buttonList)
          ) {
            Row() {
              Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                Button(this.grantGroups[this.curIndex].buttonList[0])
                  .customizeButton()
                  .fontColor($r('app.color.color_forbidden'))
                  .width('50%')
                  .onClick(() => this.processClick(0))
                Divider()
                  .color($r('sys.color.comp_divider'))
                  .vertical(true)
                  .strokeWidth('2px')
                  .height(24)
                  .margin({ left: 8, right: 8 })
                Button(this.grantGroups[this.curIndex].buttonList[1])
                  .customizeButton()
                  .width('50%')
                  .onClick(() => this.processClick(1))
              }
              .margin({ left: 16, right: 16, bottom: 8 })
            }
          } else {
            Column() {
              ForEach(this.grantGroups[this.curIndex].buttonList, (btnText: ResourceStr, idx: number) => {
                Button(btnText)
                  .customizeButton()
                  .fontColor(idx === 0 ? $r('app.color.color_forbidden') : $r('sys.color.font_emphasize'))
                  .width('100%')
                  .margin({
                    bottom: idx + 1 < this.grantGroups[this.curIndex].buttonList.length ? 4 : 0
                  })
                  .onClick(() => this.processClick(idx))
              })
            }
            .padding({ left: 16, right: 16 })
          }
        }
        .padding({ bottom: 8 })
        .clip(true)
      }
    }
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(32)
    .width(this.isPhone ? 'calc(100% - 32vp)' : '400vp')
    .margin({ bottom: this.isPhone ? 16 : 0 })
  }
}
