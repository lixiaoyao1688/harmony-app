# HarmonyMinuteChartDemo

HarmonyOS 6 / ArkTS 自绘实时图谱 Demo。

## 功能

- 1440 个 x 轴刻度，代表一天 1440 分钟。
- 顶部事件小图标。
- 中间平滑折线图。
- 中间散点图。
- 底部堆叠柱状图。
- 所有图层共享同一套 x/y 坐标换算。
- Canvas 触摸拾取最近分钟，绘制十字线，并用 ArkUI 浮层显示详情。
- `setInterval` 模拟实时数据流，每 500ms 局部更新一个分钟点并重绘。

## 使用

1. 用 DevEco Studio 打开本目录。
2. 使用 HarmonyOS 6 SDK，建议 API 20 或以上。
3. 运行 entry 模块。

## 生产化建议

当前 Demo 为单 Canvas 方案，适合 1440 点量级。真实业务建议：

- 静态层：网格、坐标轴、历史柱状图可缓存到离屏 Canvas。
- 动态层：最新折线/散点和 hover 十字线单独重绘。
- 数据模型使用 typed-array 或固定长度环形缓冲区，避免频繁创建对象。
- 触摸 Move 事件节流到 16ms 或 32ms。
- 如果图标很多，按分钟索引建立稀疏数组，避免每帧全量遍历。
