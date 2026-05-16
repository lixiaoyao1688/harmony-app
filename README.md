# HarmonyMinuteChartDemo_HOS5_VerticalPick

HarmonyOS 5 兼容版 ArkTS Demo：使用 ArkUI Canvas 自绘一个 1440 分钟刻度的实时多图层图谱。

## 功能

- x 轴 1440 个刻度，代表一天的分钟数。
- 顶部图标层。
- 平滑折线层。
- 散点层。
- 底部堆叠柱状图层。
- 所有图层共享同一套 x/y 坐标映射。
- 每 500ms 模拟一次实时数据刷新。
- 手指触摸 / 拖动时，按 x 坐标吸附到最近 minute。
- 沿当前 minute 绘制竖直参考线。
- 读取竖线经过的所有图层数据：icon、line、scatter、bar.low、bar.mid、bar.high、bar.total。
- 使用 ArkUI Stack 叠加 tooltip 悬浮窗显示详情。
- tooltip 支持左右避让，避免超出画布。

## 关键代码

入口文件：

```text
entry/src/main/ets/pages/Index.ets
```

重点方法：

```ts
private minuteOfX(x: number): number
private collectVerticalPick(minute: number, touchY: number): VerticalPickInfo
private updateHover(x: number, y: number): void
private drawHover(ctx: CanvasRenderingContext2D): void
```

## 兼容性

当前工程配置面向 HarmonyOS 5，`compatibleSdkVersion` 使用 `5.0.0(12)`。

如果你的 DevEco Studio 本地安装的是 HarmonyOS 5.0.5 / API 17 SDK，也可以导入后按本地 SDK 配置微调。
