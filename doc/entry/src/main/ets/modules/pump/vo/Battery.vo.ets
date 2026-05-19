/**
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: s_cur_realData
 */
export class BatteryVO {

  // 胰岛素泵剩余电量(%)
  private readonly _remain: number | null = null;
  private readonly _bleSignalStatus: number | null = null;
  private readonly _chargeStatus: number | null = null;

  constructor(e: Uint8Array | null) {
    if (e === null) {
      return;
    }
    // todo: 协议改了，新协议是 3 个字节，泵需要升级
    if (e.length < 2) {
      console.error('BatteryVO_error', '数据长度不足 2 字节，无法解析泵电量等信息');
      return;
    }
    this._remain = e[0];
    this._bleSignalStatus = e[1];
    // this._chargeStatus = e[2];
    this._log();
  }

  private _log(): void {
    console.log('泵报告的 s_cur_realData 为:');
    console.log(JSON.stringify({
      remainBattery: this._remain,
      bleSignalStatus: this._bleSignalStatus,
    }))
  }

}
