import { ble } from '@kit.ConnectivityKit';

export function getService(data: Array<ble.GattService>, uuid: string): ble.GattService | null {
  for (let i = data.length - 1; i > -1; i--) {
    if (data[i].serviceUuid == uuid) {
      return data[i];
    }
  }
  return null;
}

export function getCharacteristic(data: ble.GattService, uuid: string): ble.BLECharacteristic | null {
  for (let j = data.characteristics.length - 1; j > -1; j--) {
    if (data.characteristics[j].characteristicUuid === uuid) {
      return data.characteristics[j];
    }
  }
  return null;
}
