import { ble } from '@kit.ConnectivityKit';
import { SERVICE_UUID, TX_UUID } from '../../bluetooth/config/bluetooth.config';

export function writeData(gattClient: ble.GattClientDevice, data: ArrayBuffer, tips: string): void {
  // 实测: 用 RX_UUID 也能写入成功，且不会断开连接。(on 2026/05/07 16点)
  const characteristic: ble.BLECharacteristic = {
    serviceUuid: SERVICE_UUID,
    characteristicUuid: TX_UUID,
    characteristicValue: data,
    descriptors: []
  };
  try {
    gattClient.writeCharacteristicValue(characteristic, ble.GattWriteType.WRITE, (err) => {
      if (err) {
        console.error(`${tips}_failed`, JSON.stringify(err));
        return;
      }
      console.log(`${tips}_success`);
    });
  } catch (e) {
    console.error(`${tips}_write_error`, JSON.stringify(e));
  }
}
