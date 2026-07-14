type XComponentAction = (context: ESObject) => void;

export class XComponentHolder {
  private static instance: ESObject = undefined;

  static set(context: ESObject): void {
    XComponentHolder.instance = context;
  }

  static clear(): void {
    XComponentHolder.instance = undefined;
  }

  static ifPresent(action: XComponentAction): void {
    if (XComponentHolder.instance !== undefined && XComponentHolder.instance !== null) {
      action(XComponentHolder.instance);
    }
  }
}