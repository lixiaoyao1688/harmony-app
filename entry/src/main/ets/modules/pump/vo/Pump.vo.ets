import { pasteboard } from '@kit.BasicServicesKit';
import type { PumpDTO } from "../dto/pump.dto";


export class PumpVO {

  private readonly _entity: PumpDTO | null;

  constructor(e?: PumpDTO) {
    this._entity = e || null;
  }

  public get id(): string {
    if (this._entity === null) {
      return '';
    }
    return this._entity.deviceId;
  }

  // 设备地址，如: "E6:31:46:99:57:BA"
  public get deviceId(): string {
    if (this._entity === null) {
      return '';
    }
    return this._entity.deviceId;
  }

  // 泵的名称，如: "ar300_Q100017"
  public get nameText(): string {
    if (this._entity === null) {
      return '--';
    }
    return this._entity.deviceName;
  }

  // 复制配对码到剪贴板
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-pasteboard
  public async copyPinToClipboard(): Promise<void> {
    try {
      const pinCode = this._getPassword();
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, pinCode);
      await systemPasteboard.setData(pasteData);
      console.log(`配对码 ${pinCode} 已复制到剪贴板`);
    } catch (err) {
      throw new Error('[配对码复制失败] ' + JSON.stringify(err))
    }
  }

  private _getPassword(): string {
    if (this._entity === null) {
      return '';
    }
    const sn = this._entity.deviceName.split('_')[1];
    if (!sn) {
      return '';
    }
    // 仅使用下划线后前6个字符 by zmt 2026/04/16
    const data = sn.slice(0,6);
    let p = '';
    for (let i = 0, len = data.length; i < len; i++) {
      p += this._getPasswordCode(data[i]);
    }
    return p;
  }

  private _getPasswordCode(data: string): string {
    if (data === 'Q') {
      return '5';
    }
    if (data === 'T') {
      return '1';
    }
    if (data === 'W') {
      return '4';
    }
    if (data === 'Z') {
      return '7';
    }
    if (data === '2') {
      return '6';
    }
    if (data === '5') {
      return '8';
    }
    if (data === '8') {
      return '5';
    }
    if (data === 'R') {
      return '6';
    }
    if (data === 'U') {
      return '2';
    }
    if (data === 'X') {
      return '9';
    }
    if (data === '0') {
      return '3';
    }
    if (data === '3') {
      return '2';
    }
    if (data === '6') {
      return '9';
    }
    if (data === '9') {
      return '4';
    }
    if (data === 'S') {
      return '0';
    }
    if (data === 'V') {
      return '3';
    }
    if (data === 'Y') {
      return '8';
    }
    if (data === '1') {
      return '7';
    }
    if (data === '4') {
      return '1';
    }
    if (data === '7') {
      return '0';
    }
    return '';
  }

}
