import { AppStorageV2 } from '@kit.ArkUI';
import { PumpVO } from '../vo/Pump.vo';

@ObservedV2
export class PumpStore {

  @Trace public vos: Array<PumpVO> = [];

  constructor() {
    this.vos = [];
  }

  public setPumpList(data: Array<PumpVO>): void {
    this.vos = data;
  }

  public addPump(data: PumpVO): void {
    this.vos.push(data);
  }

}

export const PUMP_STORE_KEY = 'pump_store';

// https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-appstoragev2
export const pumpStore = AppStorageV2.connect(PumpStore, PUMP_STORE_KEY, () => new PumpStore()) || new PumpStore();
