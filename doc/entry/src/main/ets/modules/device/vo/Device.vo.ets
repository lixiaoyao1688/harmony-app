import { ble } from '@kit.ConnectivityKit';
import { DEVICE_KIND } from "../config/device.kind";
import { printStruct } from "../../../lib/log/util/log.util";
import { BASE_TIME_STAMP, formatTimestamp, getPassedTime } from '../../../lib/time/time.util';
import { PARAM_ID_REPORT_DEVICE, PARAM_ID_TIMESTAMP } from '../config/device.param.id';
import { getUint16, getUint32 } from '../../../lib/byte/util/byte.util';
import { getCommandToWriteToPump } from '../../../lib/protocol/util/command.util';
import { writeData } from '../../ble/util/ble.util';
import type { DeviceDTO } from '../dto/device.dto';


/**
 *
 * 设备 VO
 *
 * 参考
 * 胰岛素泵的蓝牙通信协议_loop: struct s_report_device
 */
export class DeviceVO {

  // 从 "当前时区的2021-01-01 00:00:00" 到 "当前时区的当前时间戳" 经过的时间 (s)
  private readonly _timeStamp: number | null = null;
  // 类型，见 src\main\ets\modules\device\config\device.kind.ets: DEVICE_KIND
  private readonly _deviceType: number | null = null;
  // 版本
  private readonly _version: number | null = null;
  // 序列号
  private readonly _serial: number | null = null;


  constructor(e?: Uint8Array | null) {
    if (!e) {
      return;
    }
    if (e.length < 8) {
      console.error('DeviceVO_error', '数据长度不足 8 字节，无法解析设备信息');
      return;
    }
    this._timeStamp = getUint32(e[0], e[1], e[2], e[3]);
    this._deviceType = e[4];
    this._version = e[5];
    this._serial = getUint16(e[6], e[7]);
    this._log();
  }

  // 是否内部测试版本
  // 注意: 与协议不同，以安卓代码为准。by zmt 2026-05-14 16:09:57
  // 安卓代码位于: app/src/main/java/com/aaruy/loopsystem/ble/ArService.kt:parseData UuidUtil.REPORT_DEVICE
  public get isTestVersion(): boolean {
    if (this._deviceType === DEVICE_KIND.CLOSED_LOOP_INSULIN_PUMP || this._deviceType === DEVICE_KIND.INSULIN_PUMP) {
      return this._version === 0xFF;
    }
    return false;
  }

  // 是否需要向泵设置日期和时间
  public get isPumpTimeSyncRequired(): boolean {
    return this._deviceType === DEVICE_KIND.CLOSED_LOOP_INSULIN_PUMP || this._deviceType === DEVICE_KIND.INSULIN_PUMP;
  }

  // 序列号
  public get serial(): number | null {
    return this._serial;
  }

  /**
   * 将对象转换为字节数组（小端序）
   * 字节布局：[settingTime(4字节)] [deviceType(1字节)] [version(1字节)] [serial(2字节)]
   * 总长度：8字节
   */
  public async getDTO(): Promise<ArrayBuffer> {
    try {
      // 申请一个通用的原始二进制数据缓冲区
      // 你不能直接操作 ArrayBuffer 中的内容, 而是要通过类型化数组对象或 DataView 对象来操作，它们会将缓冲区中的数据表示为特定的格式，并通过这些格式来读写缓冲区的内容。
      // https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer
      // 根据协议的 struct s_report_device, 需申请 4 + 1 + 1 + 2 = 8(字节)
      const buffer = new ArrayBuffer(8);
      // DataView 视图是一个可以从二进制 ArrayBuffer 对象中读写多种数值类型的底层接口
      // https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/DataView
      const dataView = new DataView(buffer);

      const timeStamp = await getPassedTime();
      const deviceType = DEVICE_KIND.CLOSED_LOOP_PUMP_PHONE;
      const version = 1;
      const serial = 0;
      printStruct<DeviceDTO>('s_report_device', { timeStamp, deviceType, version, serial });

      // 内存地址存储采用小端字节序
      // 如: 十六进制数字 12345678 存储为: 0x78 0x56 0x34 0x12
      // https://developer.mozilla.org/zh-CN/docs/Glossary/Endianness
      dataView.setUint32(0, timeStamp, true);
      dataView.setUint8(4, deviceType);
      dataView.setUint8(5, version);
      dataView.setUint16(6, serial, true);

      return await getCommandToWriteToPump(new Uint8Array(buffer), PARAM_ID_REPORT_DEVICE, 1, 's_report_device');
    }
    catch (e) {
      console.error('DeviceVO_getDTO_error', JSON.stringify(e));
      throw new Error(e);
    }
  }

  /**
   * 设置日期和时间，每次连接后需要同步泵端的时间
   * @param gattClient BLE客户端
   * @param serial 在泵回送的 serial 基础上 + 1;
   */
  public async sendTimeStamp(gattClient: ble.GattClientDevice, serial: number) {
    try {
      console.log('设置日期和时间');
      const buffer = new ArrayBuffer(4);
      const timeStamp = await getPassedTime();
      new DataView(buffer).setUint32(0, timeStamp, true);
      writeData(gattClient, await getCommandToWriteToPump(new Uint8Array(buffer), PARAM_ID_TIMESTAMP, serial, 'timestamp'), 'sendTimeStamp');
    }
    catch (e) {
      throw new Error('sendTimeStamp_error: ' + JSON.stringify(e));
    }
  }

  /**
   * 报告机器类型和时间, 注意控制设备连接蓝牙之后，需要立马发送该命令
   */
  public static async sendTypeAndTime(gattClient: ble.GattClientDevice) {
    console.log('报告机器类型和时间');
    // 报告机器类型和时间, 注意控制设备连接蓝牙之后，需要立马发送该命令，泵会回送该命令，以确定时间是否要更改
    // 见《胰岛素泵的蓝牙通信协议_loop》
    writeData(gattClient, await new DeviceVO().getDTO(), 'sendTypeAndTime');
  }

  private _log(): void {
    console.log('泵回送的 struct s_report_device 为:')
    // 值为 null 时会显示 "null", 不会报错。
    console.log(JSON.stringify({
      timeStamp: this._timeStamp,
      deviceType: this._deviceType,
      version: this._version,
      serial: this._serial
    }));
    if (this._timeStamp !== null) {
      console.log('timeStamp 格式化后是:', formatTimestamp(BASE_TIME_STAMP + this._timeStamp * 1000));
    }
  }

}
