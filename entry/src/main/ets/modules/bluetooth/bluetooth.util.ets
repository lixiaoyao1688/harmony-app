import { BusinessError } from '@kit.BasicServicesKit';
import { access, ble, constant, connection } from '@kit.ConnectivityKit';
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import { PumpDTO } from '../pump/dto/pump.dto';
import { PumpVO } from '../pump/vo/Pump.vo';
import { pumpStore } from '../pump/store/pump.store';
import { DeviceVO } from '../device/vo/Device.vo';
import { RX_UUID, SERVICE_UUID } from './config/bluetooth.config';
import { getCharacteristic, getService } from './util/ble.util.ts';
import { printUint8Array2 } from '../../lib/log/util/log.util';
import { unpackToGetEncryptedData } from '../../lib/protocol/util/pack.util';
import { decrypt } from '../../lib/protocol/util/crypto.util';
import { CommandVO } from '../../lib/protocol/vo/Command.vo';
import { PARAM_ID_REPORT_DEVICE } from '../device/config/device.param.id';
import { PARAM_ID_CURRENT_DATA } from '../pump/config/battery.param.id';
import { BatteryVO } from '../pump/vo/Battery.vo';
import { BleStore } from '../ble/store/ble.store';
import { PARAM_ID_CURRENT_STATUS } from '../pump/config/status.param.id';
import { PARAM_ID_REPORT_HISTORY_RECORD } from '../record/config/record.param.id';
import { RecordVO } from '../record/vo/Record.vo';
import { RecordStatVO } from '../record/vo/RecordStat.vo.ts';


// https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/br-development-guide#%E5%AE%8C%E6%95%B4%E7%A4%BA%E4%BE%8B
export class AdapterManager {

  private _bleScanner: ble.BleScanner | null = null;
  private _gattClient: ble.GattClientDevice | null = null;
  private _service: ble.GattService | null = null;

  // 检查当前应用程序是否已经被授予"允许应用接入蓝牙并使用蓝牙功能"权限
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/request-user-authorization#%E5%BC%80%E5%8F%91%E6%AD%A5%E9%AA%A4
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/permissions-for-all-user#ohospermissionaccess_bluetooth
  public async isPermissionGrant(): Promise<boolean> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // 获取应用程序的accessTokenID。
    let tokenId: number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to get bundle info for self, code: ${err.code}, message: ${err.message}`);
    }

    // 校验应用是否被授予权限。
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.ACCESS_BLUETOOTH');
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to check access token, code: ${err.code}, message: ${err.message}`);
    }

    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  // 动态向用户申请蓝牙权限
  // Promise 返回 true 代表用户已授权, 返回 false 代表用户未授权
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/request-user-authorization (页内搜索: 动态向用户申请授权)
  public reqPermissionsFromUser(context: common.UIAbilityContext): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
      atManager.requestPermissionsFromUser(context, ['ohos.permission.ACCESS_BLUETOOTH']).then((data) => {
        if (data.authResults[0] === 0) {
          resolve(true);
        } else {
          resolve(false);
        }
      }).catch((err: BusinessError) => {
        console.error(`Failed to request permissions from user, code: ${err.code}, message: ${err.message}`);
      })
    });
  }

  // 蓝牙是否已开启
  public get isBluetoothEnabled(): boolean {
    try {
      return access.getState() === access.BluetoothState.STATE_ON;
    }
    catch (err) {
      console.error('获取蓝牙开关状态错误 err: ' + JSON.stringify(err));
      return false;
    }
  }

  public openBluetooth(): void {
    console.log('开启蓝牙');
    try {
      access.on('stateChange', (data) => {
        if (data === access.BluetoothState.STATE_ON) {
          console.log('蓝牙已开启（用户主动开启）');
          this.scan();
        }
      });
    } catch (err) {
      console.error('订阅蓝牙当前的开关状态 err: ' + JSON.stringify(err));
    }
    try {
      let state = access.getState();
      console.log('当前蓝牙开关状态:', this._getStateText(state));
      if (state === access.BluetoothState.STATE_ON) {
        console.log('蓝牙已开启');
        this.scan();
      }
      else if (state === access.BluetoothState.STATE_OFF) {
        console.log('蓝牙已关闭, 让用户主动开启蓝牙');
        access.enableBluetooth();
      }
    } catch (err) {
      console.error('主动获取蓝牙当前的开关状态 err: ' + JSON.stringify(err));
    }
  }

  public closeBluetooth() {
    console.log('关闭蓝牙');
    try {
      // 主动获取蓝牙当前的开关状态
      let state = access.getState();
      if (state == access.BluetoothState.STATE_ON) {
        // 若蓝牙是开启的，则主动关闭蓝牙
        access.disableBluetooth();
      }
    } catch (err) {
      console.error('关闭蓝牙 err: ' + JSON.stringify(err));
    }
  }

  // 扫描蓝牙设备 (低功耗蓝牙)
  public scan(): void {
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ble-development-guide
    console.log('扫描蓝牙设备');

    try {
      // 创建ble扫描实例，可以管理该实例下创建的扫描流程
      this._bleScanner = ble.createBleScanner();
      try {
        // 订阅扫描结果
        this._bleScanner.on('BLEDeviceFind', this._onDeviceFound);
      } catch (err) {
        console.error('扫描蓝牙设备' + JSON.stringify(err));
      }
      // 构造扫描BLE广播的过滤条件，目标BLE广播报文需符合该过滤条件
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble#scanfilter
      const scanFilter: ble.ScanFilter = {
        // todo: 和 hl 确认
        serviceUuid: "0000180A-0000-1000-8000-00805F9B34FB"
      };
      // 构造扫描配置参数
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble#scanoptions
      const scanOptions: ble.ScanOptions = {
        // interval: 0,
        // dutyMode: ble.ScanDuty.SCAN_MODE_LOW_POWER,
        // matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      }
      pumpStore.setPumpList([]);
      this._bleScanner.startScan([scanFilter], scanOptions);
    }
    catch(e) {
      console.error('扫描蓝牙设备' + JSON.stringify(e));
    }
  }

  // 停止扫描
  public stopScan(): void {
    console.log('停止扫描');
    if (this._bleScanner === null) {
      return;
    }
    try {
      this._bleScanner.off('BLEDeviceFind', this._onDeviceFound);
      this._bleScanner.stopScan();
    } catch (err) {
      console.error('errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }

  // 连接泵
  public async connect(vo: PumpVO): Promise<void> {
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/gatt-development-guide
    try {
      console.log(`正在连接 ${vo.nameText}`);
      await vo.copyPinToClipboard();
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble#blecreategattclientdevice
      this._gattClient = ble.createGattClientDevice(vo.deviceId);
      this._gattClient.on('BLEConnectionStateChange', (data) => {
        this._onConnectStateChanged(data, vo);
      });
      this._gattClient.connect();
    } catch (err) {
      console.error('[连接泵失败] ', JSON.stringify(err));
    }
  }

  // 断开连接
  public disconnect(vo: PumpVO): void {
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/gatt-development-guide#%E5%AE%A2%E6%88%B7%E7%AB%AF (搜索: 6. 断开连接)
    console.log(`断开泵 ${vo.nameText}}`);
    if (this._gattClient === null) {
      return;
    }
    try {
      this._gattClient.disconnect();
      // 如果应用不再使用此gattClient，则需要close，gattClient实例将不能再使用
      this._gattClient.close();
    } catch (err) {
      console.error('errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }

  // 连接状态变化时的处理
  private async _onConnectStateChanged(state: ble.BLEConnectionChangeState, vo: PumpVO): Promise<void> {
    const data = state.state;
    console.log('连接状态:', this._getConnectStateText(data));
    if (this._gattClient === null) {
      return;
    }
    if (data === constant.ProfileConnectionState.STATE_CONNECTED) {
      // 连接成功
      try {
        console.log('泵服务发现');
        const services = await this._gattClient.getServices();
        services.forEach(s => { console.log(JSON.stringify(s)); });
        this._service = getService(services, SERVICE_UUID);

        // 后续的读写特征值、读写描述符等操作都需要在"服务发现"操作完成后进行，否则会失败。
        // 见 https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/gatt-development-guide#%E5%AE%A2%E6%88%B7%E7%AB%AF
        const state = connection.getPairState(vo.deviceId);
        console.log('配对状态:', this._getPairedStateText(state));

        // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-connection#connectionpairdevice-1
        if (state === connection.BondState.BOND_STATE_BONDED) {
          if (this._service !== null) {
            await this._listenData(vo, this._service);
          }
          if (this._gattClient !== null) {
            DeviceVO.sendTypeAndTime(this._gattClient);
          }
        }
        else {
          console.log('监听配对状态');
          connection.on('bondStateChange', async (p: connection.BondStateParam) => {
            console.log('配对状态:', this._getPairedStateText(p.state));
            if (p.state === connection.BondState.BOND_STATE_BONDED) {
              console.log('配对成功');
              connection.off('bondStateChange');
              if (this._service !== null) {
                await this._listenData(vo, this._service);
              }
              if (this._gattClient !== null) {
                DeviceVO.sendTypeAndTime(this._gattClient);
              }
            }
          });
          if (state === connection.BondState.BOND_STATE_INVALID) {
            console.log('发起配对');
            await connection.pairDevice(vo.deviceId);
          }
        }
      }
      catch(e) {
        console.error('_onConnectStateChanged_error:', JSON.stringify(e));
      }
    }
  }

  private async _listenData(vo: PumpVO, service: ble.GattService) {
    if (this._gattClient === null) {
      return;
    }
    try {
      console.log('开始监听泵发来的数据');
      this._gattClient.on('BLECharacteristicChange', async (data) => {
        const name = vo.nameText;
        const pack = new Uint8Array(data.characteristicValue);
        printUint8Array2(`${name} report:`, pack);
        const encryptedData = unpackToGetEncryptedData(pack);
        if (encryptedData !== null) {
          printUint8Array2(`${name} report encrypted_data:`, encryptedData);
          const decryptedData = await decrypt(encryptedData);
          printUint8Array2(`${name} report decrypted_data:`, decryptedData);
          const vo = new CommandVO(decryptedData);

          const paramId = vo.paramId;
          const paramData = vo.paramData;

          if (paramId === PARAM_ID_REPORT_DEVICE) {
            const deviceVO = new DeviceVO(paramData);
            const serial = deviceVO.serial;
            if (deviceVO.isPumpTimeSyncRequired) {
              if (serial === null) {
                console.error('send_param_id_5_error: serial is null.');
              }
              else if (this._gattClient !== null) {
                BleStore.serial = serial + 1;
                await deviceVO.sendTimeStamp(this._gattClient, BleStore.serial);
              }
            }
          }
          else if (paramId === PARAM_ID_CURRENT_DATA) {
            const batteryVO = new BatteryVO(paramData);
          }
          else if (paramId === PARAM_ID_CURRENT_STATUS) {
            console.log('收到泵状态变化，向泵请求刷新历史记录')
            BleStore.serial = BleStore.serial + 1;
            await RecordVO.writeNewest(this._gattClient, BleStore.serial);
          }
          else if (paramId === PARAM_ID_REPORT_HISTORY_RECORD) {
            console.log('收到泵报告的历史记录');
            const vo = new RecordStatVO(paramData);
          }
        }
      });
      const characteristic = getCharacteristic(service, RX_UUID);
      console.log('用于接收通知的特征值:');
      console.log(JSON.stringify(characteristic));
      await this._gattClient.setCharacteristicChangeNotification(characteristic, true);
    }
    catch (e) {
      console.error('_listenData_error', JSON.stringify(e));
    }
  }

  /**
   * 处理扫描结果
   */
  private _onDeviceFound(data: ble.ScanReport): void {
    console.log(JSON.stringify(data));
    if (data.scanResult.length > 0) {
      const dtos = data.scanResult as Array<PumpDTO>;
      for (let i = 0, len = dtos.length; i < len; i++) {
        const d = dtos[i];
        if (d.deviceName.includes('ar300')) {
          pumpStore.addPump(new PumpVO(dtos[i]));
        }
      }
    }
  }

  // 蓝牙开关状态文本
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-access#bluetoothstate
  private _getStateText(data: access.BluetoothState): string {
    if (data === access.BluetoothState.STATE_OFF) {
      return '已关闭';
    }
    if (data === access.BluetoothState.STATE_TURNING_ON) {
      return '正在打开';
    }
    if (data === access.BluetoothState.STATE_ON) {
      return '已打开';
    }
    if (data === access.BluetoothState.STATE_TURNING_OFF) {
      return '正在关闭';
    }
    if (data === access.BluetoothState.STATE_BLE_TURNING_ON) {
      return '正在打开LE-only模式';
    }
    if (data === access.BluetoothState.STATE_BLE_ON) {
      return '正处于LE-only模式';
    }
    if (data === access.BluetoothState.STATE_BLE_TURNING_OFF) {
      return '正在关闭LE-only模式';
    }
    return '未知';
  }

  // 蓝牙设备连接状态文本
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-constant#profileconnectionstate
  private _getConnectStateText(data: constant.ProfileConnectionState): string {
    if (data === constant.ProfileConnectionState.STATE_DISCONNECTED) {
      return '已断开连接';
    }
    if (data === constant.ProfileConnectionState.STATE_CONNECTING) {
      return '正在连接';
    }
    if (data === constant.ProfileConnectionState.STATE_CONNECTED) {
      return '已连接';
    }
    if (data === constant.ProfileConnectionState.STATE_DISCONNECTING) {
      return '正在断开连接';
    }
    return '未知';
  }

  // 蓝牙设备配对状态文本
  // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-connection#bondstate
  private _getPairedStateText(data: connection.BondState): string {
    if (data === connection.BondState.BOND_STATE_INVALID) {
      return '未配对状态';
    }
    if (data === connection.BondState.BOND_STATE_BONDING) {
      return '配对中的状态';
    }
    if (data === connection.BondState.BOND_STATE_BONDED) {
      return '已配对状态';
    }
    return '未知';
  }

}

export const adapterManager = new AdapterManager();
