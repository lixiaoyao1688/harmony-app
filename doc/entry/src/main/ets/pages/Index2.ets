import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { PumpVO } from '../modules/pump/vo/Pump.vo';
import { pumpStore } from '../modules/pump/store/pump.store';
import { adapterManager } from '../modules/bluetooth/bluetooth.util';
import { encrypt, decrypt } from '../lib/protocol/util/crypto.util';
import { printUint8Array } from '../lib/log/util/log.util';
import { getPassedTime } from '../lib/time/time.util';
import { DeviceVO } from '../modules/device/vo/Device.vo';


@Entry
@Component
struct Index {

  @StorageProp('topAvoidHeight') topHeight: number = 0;  // vp
  @StorageProp('bottomAvoidHeight') bottomHeight: number = 0;  // vp

  build() {
    Column() {
      // 电量/药量栏
      Row() {}.backgroundColor($r('app.color.bg_1')).width('100%').height('5%')  // 44
      // 内容栏
      Column() {
        // 总览
        Row() {
          Column() {
            // LOGO
            Row() {
              Image($r('app.media.aaruy')).width('27.10%').height('100%').onClick(() => adapterManager.stopScan())
            }
            .width('100%')
            .height('7.53%')
            .justifyContent(FlexAlign.Center)

            Text($r('app.string.pump_list'))
              .fontSize(20)
              .fontColor($r('app.color.color_0'))
              .margin({ top: 10 })

            List() {
              ForEach(pumpStore.vos, (vo: PumpVO) => {
                ListItem() {
                  Row() {
                    Text(vo.nameText).fontSize(20)
                  }
                  .width('100%')
                  .padding({ top: 16, bottom: 16 })
                  .justifyContent(FlexAlign.Start)
                  .onClick(() => {
                    adapterManager.stopScan();
                    adapterManager.connect(vo);
                  })
                }
              }, (vo: PumpVO) => vo.id)
            }
            .width('100%')
            .height('90%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')  // todo: 恢复
        // .height('50.41%')  // 372
        .alignItems(VerticalAlign.Top)
        .padding({ top: 10 })

        // todo: 恢复
        // 图谱
        // Row() {
        // }
        // .width('100%')
        // .height('49.59%')  // 366
        // .backgroundColor('#FF00FF')
        // .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .height('83%')  // 732
      .backgroundColor($r('app.color.bg_2'))

      // 菜单栏
      Stack() {
        Row() {
          Column() {}.width('21.49%').height('100%').backgroundColor($r('app.color.bg_3'))
          Column() {}.width('27.57%').height('100%').backgroundColor($r('app.color.bg_3'))
          Column() {}.width('27.57%').height('100%').backgroundColor($r('app.color.bg_3'))
          Column() {}.width('21.49%').height('100%').backgroundColor($r('app.color.bg_3'))
        }
        .width('100%')
        .height('84%')
        .backgroundColor($r('app.color.bg_2'))
        .alignItems(VerticalAlign.Bottom)
        .justifyContent(FlexAlign.SpaceBetween)
        .align(Alignment.Bottom)

        // todo: 边框
        Image($r('app.media.bolus'))
          .width('16.35%')
          .height('70%')
          .position({ x: '50%', y: 0 })  // 左上角位于父容器水平50%，顶部0
          .translate({ x: '-50%' })      // 向左平移自身宽度的一半，实现水平居中
          .onClick(async () => {

            // 扫描泵
            const isPermissionGrant = await adapterManager.isPermissionGrant();
            if (isPermissionGrant) {
              console.log('蓝牙权限已得到');
              if (adapterManager.isBluetoothEnabled) {
                console.log('蓝牙已开启');
                adapterManager.scan();
              }
              else {
                adapterManager.openBluetooth();
              }
            }
            else {
              console.log('未得到蓝牙权限, 向用户申请授权');
              adapterManager.reqPermissionsFromUser(this.getUIContext().getHostContext() as common.UIAbilityContext)
                .then(isAllowed => {
                  if (isAllowed) {
                    console.log('用户授权"允许应用接入蓝牙并使用蓝牙功能"权限');
                    adapterManager.openBluetooth();
                  }
                  else {
                    console.error('用户拒绝授权"允许应用接入蓝牙并使用蓝牙功能"权限，提示用户必须授权才能继续使用功能，并引导用户到系统设置中打开相应的权限');
                  }
                })
            }

            // 测试多语言和深浅色
            // toggleLanguage(globalState);
            // ThemeUtil.toggleTheme(globalState);

            // 测试加解密方法
            // const data0 = new Uint8Array([0x0D,0x00,0x01,0x11,0x00,0x01,0x00,0xA1,0xD2,0xF2,0x09,0x08,0x01,0x00,0x00]);
            // await encrypt(data0);
            // const data1 = new Uint8Array([0x05,0xAE,0xDF,0x88,0x03,0xB8,0x77,0x61,0x4F,0x2E,0x66,0x0E,0x30,0xBA,0xFB,0xFA]);
            // await decrypt(data1);
          })
      }
      .width('100%')
      .height('12%')  // 105 (100:原尺寸, +5:预留给导航栏)
      .backgroundColor($r('app.color.bg_2'))
    }
    .width('100%')
    .height('100%')  // 882px
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .background($r('app.color.bg_0'))
    .padding({
      top: this.topHeight,    // 避让状态栏
      bottom: 0               // 底部不避让，让背景延伸到导航栏
    })
  }
}
