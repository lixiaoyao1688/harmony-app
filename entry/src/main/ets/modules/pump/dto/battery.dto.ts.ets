export interface BatteryDTO {
  remainBattery: number;	// 胰岛素泵剩余电量(%)
  bleSignalStatus: number;	// 蓝牙信号强度
  chargeStatus?: number;		// 0:未充电 1:快充 2:慢充 3:充满 4:充电异常
}