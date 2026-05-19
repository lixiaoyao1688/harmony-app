// 边距类型定义
interface PaddingType {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

// 吸附结果类型定义
interface SnapResult {
  x: number;      // 吸附后的 x 坐标
  index: number;  // 数据点索引（从0开始）
}

@Component
export struct MergeChart {
  // --- 时间范围切换 ---
  private readonly TIME_RANGES: number[] = [3, 6, 12, 24]; // 小时
  @State private currentRangeIndex: number = 3;   // 默认 24 小时

  // Canvas 上下文
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 图表边距（明确指定类型）
  private readonly PADDING: PaddingType = { top: 15, right: 30, bottom: 30, left: 20 };

  // Canvas 实际宽高（vp），由 onAreaChange 获取
  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;

  // 长按虚线状态
  @State private showLongPressLine: boolean = false;
  @State private longPressX: number = 0;
  @State private currentIndex: number = 0; // 当前吸附点的索引

  // 用于区分长按和点击，以及控制移动跟随
  private isLongPressTriggered: boolean = false;
  private isLongPressActive: boolean = false;

  // 存储背景元素参数（延迟1秒后赋值，后续所有重绘均使用）
  private backgroundLow: number | null = null;
  private backgroundHigh: number | null = null;
  private backgroundTarget: number | null = null;

  aboutToAppear() {
    // 延迟 1 秒后设置背景元素参数并重绘
    setTimeout(() => {
      this.backgroundLow = 3.9;
      this.backgroundHigh = 10;
      this.backgroundTarget = 5.5;
      this.drawChart();
    }, 1000);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onAreaChange((_, newArea) => {
        this.canvasWidth = newArea.width as number;
        this.canvasHeight = newArea.height as number;
        this.drawChart();
      })
      .onReady(() => {
        if (this.canvasWidth > 0) {
          this.drawChart();
        }
      })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          TapGesture({ count: 1 })
            .onAction(() => {
              if (this.isLongPressTriggered) {
                this.isLongPressTriggered = false;
                return;
              }
              this.toggleTimeRange();
            }),
          LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
            .onAction((event: GestureEvent) => {
              if (event.fingerList && event.fingerList.length > 0) {
                this.isLongPressTriggered = true;
                this.isLongPressActive = true;
                const snapResult: SnapResult = this.snapToDataPoint(event.fingerList[0].localX);
                this.longPressX = snapResult.x;
                this.currentIndex = snapResult.index;
                this.showLongPressLine = true;
                this.drawChart();
              }
            })
            .onActionEnd(() => {
              this.isLongPressActive = false;
              this.showLongPressLine = false;
              this.drawChart();
            }),
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
            .onActionUpdate((event: GestureEvent) => {
              if (this.isLongPressActive && event.fingerList && event.fingerList.length > 0) {
                const snapResult: SnapResult = this.snapToDataPoint(event.fingerList[0].localX);
                this.longPressX = snapResult.x;
                this.currentIndex = snapResult.index;
                this.drawChart();
              }
            })
            .onActionEnd(() => {
              if (this.isLongPressActive) {
                this.isLongPressActive = false;
                this.showLongPressLine = false;
                this.drawChart();
              }
            })
        )
      )
  }

  // 将手指原始x坐标吸附到最近的离散点，返回吸附结果
  private snapToDataPoint(rawX: number): SnapResult {
    const rangeHours = this.TIME_RANGES[this.currentRangeIndex];
    const pointsCount = rangeHours * 60; // 每分钟一个点
    const plotLeft = this.PADDING.left;
    const plotRight = this.canvasWidth - this.PADDING.right;
    const plotWidth = plotRight - plotLeft;

    const clampedX = Math.max(plotLeft, Math.min(plotRight, rawX));
    let index = Math.round((clampedX - plotLeft) / plotWidth * (pointsCount - 1));
    index = Math.max(0, Math.min(pointsCount - 1, index));
    const x = plotLeft + (index / (pointsCount - 1)) * plotWidth;
    return { x, index };
  }

  // 格式化时间戳为 YYYY-MM-DD HH:mm
  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  // 切换时间范围
  toggleTimeRange() {
    this.currentRangeIndex = (this.currentRangeIndex + 1) % this.TIME_RANGES.length;
    this.drawChart();
  }

  // 主绘制函数
  drawChart() {
    if (this.canvasWidth === 0 || this.canvasHeight === 0) {
      return;
    }

    const plotLeft = this.PADDING.left;
    const plotTop = this.PADDING.top;
    const plotWidth = this.canvasWidth - this.PADDING.left - this.PADDING.right;
    const plotHeight = this.canvasHeight - this.PADDING.top - this.PADDING.bottom;

    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    const now = Date.now();
    const rangeHours = this.TIME_RANGES[this.currentRangeIndex];
    const startTime = now - rangeHours * 60 * 60 * 1000;

    this.drawGrid(plotLeft, plotTop, plotWidth, plotHeight, startTime, now);

    // 根据存储的参数决定是否绘制背景元素
    if (this.backgroundLow !== null && this.backgroundHigh !== null) {
      this.drawBackgroundRect(plotLeft, plotTop, plotWidth, plotHeight, this.backgroundLow, this.backgroundHigh);
    }
    if (this.backgroundTarget !== null) {
      this.drawHorizontalDashLine(plotLeft, plotTop, plotWidth, plotHeight, this.backgroundTarget);
    }

    // 绘制长按指示器（若存在）
    if (this.showLongPressLine) {
      this.ctx.save();

      const indicatorWidth = this.canvasWidth * 0.36;
      const indicatorHeight = this.canvasHeight * 0.30;
      const plotRight = this.canvasWidth - this.PADDING.right;

      let indicatorLeft = this.longPressX - indicatorWidth / 2;
      if (indicatorLeft < plotLeft) {
        indicatorLeft = plotLeft;
      } else if (indicatorLeft + indicatorWidth > plotRight) {
        indicatorLeft = plotRight - indicatorWidth;
      }
      const indicatorTop = plotTop;

      this.ctx.strokeStyle = 'rgb(228,232,228)';
      this.ctx.lineWidth = 1;
      this.ctx.setLineDash([5, 5]);
      this.ctx.beginPath();
      this.ctx.moveTo(this.longPressX, plotTop);
      this.ctx.lineTo(this.longPressX, plotTop + plotHeight);
      this.ctx.stroke();
      this.ctx.setLineDash([]);

      this.ctx.fillStyle = 'rgb(220,221,224)';
      this.drawRoundRect(this.ctx, indicatorLeft, indicatorTop, indicatorWidth, indicatorHeight, 4);

      const padding: PaddingType = { top: 8, right: 12, bottom: 12, left: 12 };
      const contentTop = indicatorTop + padding.top;

      const rangeMs = rangeHours * 3600 * 1000;
      const pointsCount = rangeHours * 60;
      const snappedTime = now - rangeMs + (this.currentIndex / (pointsCount - 1)) * rangeMs;
      const timeText = this.formatDateTime(snappedTime);

      this.ctx.fillStyle = 'rgb(80,86,86)';
      this.ctx.font = 'bold 12vp sans-serif';
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'top';
      const textX = indicatorLeft + indicatorWidth / 2;
      this.ctx.fillText(timeText, textX, contentTop);

      this.ctx.restore();
    }
  }

  // 绘制横向充满 X 轴、纵向从 low 到 high 的半透明矩形
  private drawBackgroundRect(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number, low: number, high: number) {
    const topY = plotTop + plotHeight - (high / 22) * plotHeight;
    const bottomY = plotTop + plotHeight - (low / 22) * plotHeight;
    this.ctx.save();
    this.ctx.fillStyle = 'rgba(0,197,228,0.24)';
    this.ctx.fillRect(plotLeft, topY, plotWidth, bottomY - topY);
    this.ctx.restore();
  }

  // 绘制 y = target 处的水平虚线
  private drawHorizontalDashLine(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number, target: number) {
    const dashY = plotTop + plotHeight - (target / 22) * plotHeight;
    this.ctx.save();
    this.ctx.strokeStyle = 'rgb(170,170,170)';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([5, 5]);
    this.ctx.beginPath();
    this.ctx.moveTo(plotLeft, dashY);
    this.ctx.lineTo(plotLeft + plotWidth, dashY);
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    this.ctx.restore();
  }

  // 绘制圆角矩形辅助函数
  private drawRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
    ctx.fill();
  }

  // --- 绘制网格与坐标轴 ---
  private drawGrid(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number,
    startTime: number, endTime: number) {
    this.ctx.strokeStyle = 'rgb(80,86,86)';
    this.ctx.lineWidth = 0.5;
    this.ctx.fillStyle = '#666';
    this.ctx.font = '12vp sans-serif';
    this.ctx.textAlign = 'left';

    for (let val = 2; val <= 22; val += 2) {
      const y = plotTop + plotHeight - (val / 22) * plotHeight;
      this.ctx.beginPath();
      this.ctx.moveTo(plotLeft, y);
      this.ctx.lineTo(plotLeft + plotWidth, y);
      this.ctx.stroke();
      this.ctx.fillText(val.toString(), plotLeft + plotWidth + 5, y + 4);
    }

    this.ctx.textAlign = 'center';
    const rangeMs = endTime - startTime;
    const rangeHours = Math.round(rangeMs / (60 * 60 * 1000));
    let stepMs: number;
    let thresholdMs: number;
    switch (rangeHours) {
      case 3:
        stepMs = 1 * 60 * 60 * 1000;
        thresholdMs = 15 * 60 * 1000;
        break;
      case 6:
        stepMs = 1 * 60 * 60 * 1000;
        thresholdMs = 40 * 60 * 1000;
        break;
      case 12:
        stepMs = 2 * 60 * 60 * 1000;
        thresholdMs = 60 * 60 * 1000;
        break;
      case 24:
        stepMs = 4 * 60 * 60 * 1000;
        thresholdMs = 60 * 60 * 1000;
        break;
      default:
        stepMs = 4 * 60 * 60 * 1000;
        thresholdMs = 60 * 60 * 1000;
    }

    const nowX = plotLeft + plotWidth;
    this.ctx.beginPath();
    this.ctx.moveTo(nowX, plotTop);
    this.ctx.lineTo(nowX, plotTop + plotHeight);
    this.ctx.stroke();
    this.ctx.fillText('现在', nowX, plotTop + plotHeight + 15);

    const baseDate = new Date(endTime);
    baseDate.setMinutes(0, 0, 0);
    const baseTime = baseDate.getTime();
    const diffFromBase = endTime - baseTime;
    const drawBaseTick = diffFromBase >= thresholdMs && baseTime >= startTime;

    if (drawBaseTick) {
      const x = plotLeft + ((baseTime - startTime) / rangeMs) * plotWidth;
      this.ctx.beginPath();
      this.ctx.moveTo(x, plotTop);
      this.ctx.lineTo(x, plotTop + plotHeight);
      this.ctx.stroke();
      const date = new Date(baseTime);
      let hour12 = date.getHours() % 12;
      if (hour12 === 0) hour12 = 12;
      const ampm = date.getHours() < 12 ? 'am' : 'pm';
      const label = `${hour12.toString().padStart(2, '0')}${ampm}`;
      this.ctx.fillText(label, x, plotTop + plotHeight + 15);
    }

    let tickTime = baseTime - stepMs;
    while (tickTime >= startTime) {
      const x = plotLeft + ((tickTime - startTime) / rangeMs) * plotWidth;
      this.ctx.beginPath();
      this.ctx.moveTo(x, plotTop);
      this.ctx.lineTo(x, plotTop + plotHeight);
      this.ctx.stroke();
      const date = new Date(tickTime);
      let hour12 = date.getHours() % 12;
      if (hour12 === 0) hour12 = 12;
      const ampm = date.getHours() < 12 ? 'am' : 'pm';
      const label = `${hour12.toString().padStart(2, '0')}${ampm}`;
      this.ctx.fillText(label, x, plotTop + plotHeight + 15);
      tickTime -= stepMs;
    }

    this.ctx.strokeStyle = '#333';
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(plotLeft, plotTop);
    this.ctx.lineTo(plotLeft, plotTop + plotHeight);
    this.ctx.lineTo(plotLeft + plotWidth, plotTop + plotHeight);
    this.ctx.stroke();
  }
}