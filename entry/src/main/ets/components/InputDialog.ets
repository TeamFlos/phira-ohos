@CustomDialog
export struct InputDialog {
  controller: CustomDialogController;
  onConfirm: (text: string) => void = () => {};
  onCancel: () => void = () => {};
  title: string = '输入';
  prompt?: string;
  defaultValue: string = '';
  mode: string = 'text';
  okLabel: string = '确定';
  cancelLabel: string = '取消';
  @State private inputText: string = '';

  aboutToAppear(): void {
    this.inputText = this.defaultValue;
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })
        .fontColor($r('app.color.font_color_primary'))
      if (this.prompt) {
        Text(this.prompt)
          .fontSize(14)
          .margin({ bottom: 10, left: 16, right: 16 })
          .fontColor($r('app.color.font_color_placeholder'))
      }
      if (this.mode === 'multiline') {
        TextArea({ text: this.inputText, placeholder: this.prompt })
          .backgroundColor($r('app.color.input_background'))
          .placeholderColor($r('app.color.font_color_placeholder'))
          .fontColor($r('app.color.font_color_primary'))
          .height(120)
          .padding({
            left: 12,
            right: 12,
            top: 8,
            bottom: 8
          })
          .borderRadius(8)
          .margin({ bottom: 20, left: 16, right: 16 })
          .onChange((value: string) => {
            this.inputText = value;
          })
      } else {
        TextInput({ text: this.inputText, placeholder: this.prompt })
          .type(this.mode === 'password' ? InputType.Password : InputType.Normal)
          .backgroundColor($r('app.color.input_background'))
          .placeholderColor($r('app.color.font_color_placeholder'))
          .fontColor($r('app.color.font_color_primary'))
          .height(48)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .margin({ bottom: 20, left: 16, right: 16 })
          .onChange((value: string) => {
            this.inputText = value;
          })
      }
      Row() {
        Button(this.cancelLabel)
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
          .layoutWeight(1)
          .backgroundColor($r('app.color.dialog_background'))
          .fontColor($r('app.color.font_color_primary'))
          .height('100%')
        Button(this.okLabel)
          .onClick(() => {
            this.onConfirm(this.inputText);
            this.controller.close();
          })
          .layoutWeight(1)
          .backgroundColor($r('app.color.dialog_background'))
          .fontColor($r('app.color.button_background_primary'))
          .fontWeight(FontWeight.Bold)
          .height('100%')
      }
      .width('100%')
      .height(44)
    }
    .width('50%')
    .backgroundColor($r('app.color.dialog_background'))
    .borderRadius(15)
    .shadow({ radius: 20, color: $r('app.color.dialog_shadow'), offsetX: 0, offsetY: 5 })
  }
}
