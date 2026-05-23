import { DEVICE_KIND } from "../config/device.kind";

export interface DeviceDTO {
  timeStamp: number;	// 时间
  deviceType: DEVICE_KIND;	// 类型
  version: number;	// 版本管理，若deviceType为手表，而且version为1(含)以上，则泵需要同步手表的时间；deviceType为0或6时，bit0~6为1时，为部分状态命令增加几个字段，具体前参考其他命令；bit7为1时，表示内部测试版本，为0时，表示正式出货版本。
  serial: number;	// 泵这边会产生随机的序列号，后期发送的数据都在这个serial+1发送命令
}
