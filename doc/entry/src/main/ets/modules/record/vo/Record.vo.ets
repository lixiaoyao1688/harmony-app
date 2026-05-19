import { systemDateTime } from '@kit.BasicServicesKit';
import { ble } from '@kit.ConnectivityKit';
import { writeData } from '../../ble/util/ble.util';
import { RECORD_TYPE } from '../config/record.type';
import { HISTORY_TYPE } from '../config/history.type';
import { RECORD_REQUEST_ORIGIN } from '../config/origin';
import { getTimeText } from '../../../lib/time/time.util';
import { PARAM_ID_NEWEST_REPORT_SET } from '../config/record.param.id';
import { getUint16, getUint32 } from '../../../lib/byte/util/byte.util';
import { getCommandToWriteToPump } from '../../../lib/protocol/util/command.util';


/**
 * 历史记录 VO
 *
 * 参考
 * 协议搜索 s_history_unit
 */
export class RecordVO {

  // s_history_unit 的字节数
  public static SIZE = 12;

  constructor(e?: Uint8Array | null) {
    if (!e) {
      return;
    }
    if (e.length < RecordVO.SIZE) {
      console.error('RecordVO_constructor_error', `数据长度不足 ${RecordVO.SIZE} 字节，无法解析历史记录`);
      return;
    }
    // 时间戳(s)
    const time = getUint32(e[0], e[1], e[2], e[3]);
    // 类型，见 src\main\ets\modules\record\config\record.type.ets: RECORD_TYPE
    const type = e[4];
    // 值
    // 当type为0时，该值是基础率值(U/小时)
    // 当type为1时，该值是临时基础率值(U/小时)
    const data = getUint16(e[5], e[6]);

    // bit0~13: 注射时长，当为大剂量(即type==2)时，当data不为0时，该值为立即量的输注时长，单位为秒；
    // 当data为0时，该值为延长量的输注时长，单位为分钟。
    const injectTime = getUint16(e[7], e[8]);

    if (type === RECORD_TYPE.BOLUS) {
      // 当type为2时，该值是大剂量立即量值(U)，与injectTime的bit15位组成立即量;
      // 如: injectTime=0x8000 data=0x3880，则立即量的数值为0x13880，80U;
      // 解析:
      // (injectTime >> 15) & 1): 提取 injectTime 的 bit15 位 (>> 15: 将目标的 b15 移动到 b0; & 1: 和二进制 0000_0000_0000_0001 按位与，只保留 b0，其余位清零; 结果即是目标 b15 的值)
      // << 16: 将该位放到 32 位数的 bit16 位置
      // (data & 0xFFFF): 取 data 的低 16 位（其实 b 本身就是 16 位，但显式掩码更安全）
      // |: 将两部分按位合并
      const bolusValue = ((injectTime >> 15) & 1) << 16 | (data & 0xFFFF);
      // 用的时候需要缩小1000倍且对 0.025 进行四舍五入。by 黄伦 2026-05-18 19:18:11 至 黄伦 2026-05-18 19:21:59
    }

    // todo: 先把基础率/临时基础率绘制出来
    const delayBolus = getUint16(e[9], e[10]);
    const reserved = e[11];

    this._log(time, type, data, injectTime, delayBolus, reserved);
  }

  private _log(time: number, type: number, data: number, injectTime: number, delayBolus: number, reserved: number): void {
    console.log(JSON.stringify({
      time, type, data, injectTime, delayBolus, reserved
    }));

    console.log('time: ', getTimeText(time * 1000));
  }

  /**
   * 向泵回报最新的历史记录
   *
   * 参考
   * 协议搜索: s_report_newest_history
   *
   * @param gattClient BLE客户端
   */
  public static async writeNewest(gattClient: ble.GattClientDevice | null, serial: number) {
    try {
      console.log('回报最新的历史记录');
      if (gattClient === null) {
        console.error('RecordVO_writeNewest_error:', 'BLE客户端为空');
        return;
      }
      // 历史记录类型，默认发注射类型
      const historyType = HISTORY_TYPE.INFUSION;
      // historyType为1时，表示最近一次每日总量的日期(以天为单位); historyType为其他值时，表示最近一次历史记录的时间戳.
      // 当前时间戳(s)(ms => s, 泵程序的惯例: 末尾截断)
      const time = Math.floor(systemDateTime.getTime() / 1000);
      // 最大255，已经没有用了
      const count = 0;
      // 申请的来源
      const fromServer = RECORD_REQUEST_ORIGIN.FROM_CONTROLLER;
      // 当historyType为0时, bit2-5表示序号(用于区别历史记录时间戳一样的情况下进行二次区别)
      const reserved = 0;
      // 开始写入
      const buffer = new ArrayBuffer(8);
      const dataView = new DataView(buffer);
      dataView.setUint32(0, time, true);
      dataView.setUint8(4, count);
      dataView.setUint8(5, historyType);
      dataView.setUint8(6, fromServer);
      dataView.setUint8(7, reserved);
      writeData(gattClient, await getCommandToWriteToPump(new Uint8Array(buffer), PARAM_ID_NEWEST_REPORT_SET, serial, 's_report_newest_history'), 'RecordVO_writeNewest');
    }
    catch (e) {
      throw new Error('RecordVO_writeNewest_error: ' + JSON.stringify(e));
    }
  }

}
