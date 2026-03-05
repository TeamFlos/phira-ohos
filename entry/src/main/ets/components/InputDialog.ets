@CustomDialog
export struct InputDialog {
  controller: CustomDialogController;
  onConfirm: (text: string) => void = () => {};
  onCancel: () => void = () => {};
  isPassword: boolean = false;
  @State private inputText: string = '';

  build() {
    Column() {
      Text(this.isPassword ? $r('app.string.input_dialog_title_password') : $r('app.string.input_dialog_title_content'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 15 })
        .fontColor($r('app.color.font_color_primary'))

      TextInput({ placeholder: this.isPassword ? $r('app.string.input_dialog_placeholder_password') : $r('app.string.input_dialog_placeholder_content') })
        .type(this.isPassword ? InputType.Password : InputType.Normal)
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

      Row() {
        Button($r('app.string.button_cancel'))
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
          .layoutWeight(1)
          .backgroundColor($r('app.color.dialog_background'))
          .fontColor($r('app.color.font_color_primary'))
          .height('100%')


        Button($r('app.string.button_confirm'))
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
    .width('80%')
    .backgroundColor($r('app.color.dialog_background'))
    .borderRadius(15)
    .shadow({ radius: 20, color: $r('app.color.dialog_shadow'), offsetX: 0, offsetY: 5 })
  }
}
