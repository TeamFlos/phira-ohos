@CustomDialog
export struct InputDialog {
  controller: CustomDialogController;
  onConfirm: (text: string) => void = () => {};
  onCancel: () => void = () => {};
  @State private inputText: string = '';
  build() {
    Column() {
      Text('请输入内容')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 15 })

      TextInput({ placeholder: 'input your word...' })
        .onChange((value: string) => {
          this.inputText = value;
        })

      Row() {
        Button('取消')
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
          .layoutWeight(1)
          .backgroundColor('#EFEFEF')
          .fontColor(Color.Black)

        Divider().vertical(true).strokeWidth(1).color('#CCCCCC').height(20)

        Button('确定')
          .onClick(() => {
            this.onConfirm(this.inputText);
            this.controller.close();
          })
          .layoutWeight(1)
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
      }
      .width('100%')
      .height(44)
    }
    .width('80%')
    .backgroundColor('#F8F8F8')
    .borderRadius(15)
    .shadow({ radius: 20, color: '#888888', offsetX: 0, offsetY: 5 })

  }
}
