# HarmonyMinuteChartDemo_HOS5_DarkStyle

HarmonyOS 5 / ArkTS Canvas 自绘图谱 Demo。

## 这版样式

按照用户提供的参考图重做了视觉风格：

- 深色背景
- 灰绿色网格线
- 右侧 Y 轴刻度 2 ~ 22
- 底部 X 轴显示 0、2、4、6、8、10、现在
- 中部青绿色目标区间背景
- 白色粗平滑折线
- 灰色虚线参考线
- 红色事件标记
- 顶部圆形事件图标
- 底部紫色 / 青色堆叠柱
- 触摸时绘制竖直选中线
- 竖线穿过的图标、折线、散点、柱状数据汇总到浮窗
- 浮窗样式接近截图中的浅灰气泡

## 入口文件

```text
entry/src/main/ets/pages/Index.ets
```

## 运行

使用 DevEco Studio 打开项目目录，选择 HarmonyOS 5 SDK / API 12 或更高版本运行。

## 关键方法

```ts
private drawGridAndAxes(ctx: CanvasRenderingContext2D): void
private drawTargetBand(ctx: CanvasRenderingContext2D): void
private drawSmoothLine(ctx: CanvasRenderingContext2D): void
private drawStackBars(ctx: CanvasRenderingContext2D): void
private drawHover(ctx: CanvasRenderingContext2D): void
private collectVerticalPick(minute: number, touchY: number): VerticalPickInfo
```
