import { display } from '@kit.ArkUI';
import { MergeChart } from '../modules/merge/page/MergeChart';

/**
 *
 * 总高度          882px
 *
 * 电量/药量栏      44px      4.98%
 * 概览栏           xx       28.83%
 * 实时状态栏       100px     11.34%
 * 图谱            xx        37.16%
 * CGM信息、泵信息  56px       6.34%
 * 底部工具栏       100px     11.34%
 *
 */
@Entry
@Component
struct Index {

  @StorageProp('topAvoidHeight') topHeight: number = 0;  // vp
  @StorageProp('bottomAvoidHeight') bottomHeight: number = 0;  // vp

  // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-custom-component-lifecycle#abouttoappear
  aboutToAppear(): void {
    // 获取屏幕密度比(DPI)，即 1vp 对应的 px 值。例如，我的手机输出: 4, 那么 1vp 就是 4px;
    try {
      console.info(`当前设备的屏幕密度比为: ${display.getDefaultDisplaySync().densityPixels}`);
    } catch (e) {
      console.log('aboutToAppear_error', JSON.stringify(e));
    }
  }

  build() {
    Column() {
      // 电量/药量栏
      Row() {}.backgroundColor($r('app.color.bg_1')).width('100%').height('4.98%')
      // 概览栏
      Row() {}.backgroundColor($r('app.color.bg_0')).width('100%').height('28.83%')
      // 实时状态栏
      Row() {}.backgroundColor($r('app.color.bg_1')).width('100%').height('11.34%')
      // 图谱
      Row() {
        MergeChart()
      }.backgroundColor($r('app.color.bg_0')).width('100%').height('37.16%')
      // CGM信息、泵信息
      Row() {}.backgroundColor($r('app.color.bg_1')).width('100%').height('6.34%')
      // 底部工具栏
      Row() {}.backgroundColor($r('app.color.bg_0')).width('100%').height('11.34%')
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .background($r('app.color.bg_0'))
    .padding({
      top: this.topHeight,    // 避让状态栏
      bottom: 0               // 底部不避让，让背景延伸到导航栏
    })
  }

}
