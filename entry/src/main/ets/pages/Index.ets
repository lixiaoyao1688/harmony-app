const POINT_COUNT: number = 1440;
const MINUTE_MS: number = 60 * 1000;

interface BarStack {
  low: number;
  mid: number;
  high: number;
}

interface ChartData {
  icons: number[];
  line: number[];
  scatter: number[];
  bars: BarStack[];
}

interface PlotRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

interface VerticalPickInfo {
  show: boolean;
  minute: number;
  x: number;
  touchY: number;
  iconType: number;
  lineValue: number;
  scatterValue: number;
  barLow: number;
  barMid: number;
  barHigh: number;
  barTotal: number;
}

@Entry
@Component
struct Index {
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private timer: number = -1;
  private data: ChartData = this.createData();
  private plot: PlotRect = { left: 40, top: 52, width: 1, height: 1 };
  private canvasW: number = 0;
  private canvasH: number = 0;

  @State private hover: VerticalPickInfo = {
    show: false,
    minute: 0,
    x: 0,
    touchY: 0,
    iconType: 0,
    lineValue: 0,
    scatterValue: 0,
    barLow: 0,
    barMid: 0,
    barHigh: 0,
    barTotal: 0
  };
  @State private fpsText: string = 'Realtime Canvas Chart / 1440 points';

  aboutToAppear(): void {
    // Demo: 每 500ms 更新一个分钟点；实际业务中可替换为 BLE / 网络 / 传感器流。
    this.timer = setInterval(() => {
      this.pushOnePoint();
      this.draw();
    }, 500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  build() {
    Stack() {
      Column() {
        Text(this.fpsText)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })
          .width('100%')

        Canvas(this.ctx)
          .width('100%')
          .height('78%')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .onReady(() => {
            this.canvasW = this.ctx.width;
            this.canvasH = this.ctx.height;
            this.draw();
          })
          .onTouch((event?: TouchEvent) => {
            if (!event || event.touches.length === 0) {
              return;
            }
            const x = event.touches[0].x;
            const y = event.touches[0].y;
            if (event.type === TouchType.Down || event.type === TouchType.Move) {
              this.updateHover(x, y);
              this.draw();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.hover = { ...this.hover, show: false };
              this.draw();
            }
          })
          .margin({ left: 12, right: 12, bottom: 12 })

        Text('触摸/拖动图谱：按 x 坐标吸附到最近分钟，竖线经过的图标、折线、散点和堆叠柱数据都会汇总到浮层。')
          .fontSize(13)
          .fontColor('#666666')
          .padding({ left: 16, right: 16, bottom: 12 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FA')

      if (this.hover.show) {
        Column() {
          Text(this.formatMinute(this.hover.minute))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')
          Text(`icon: ${this.iconName(this.hover.iconType)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`line: ${this.hover.lineValue.toFixed(1)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`scatter: ${this.hover.scatterValue.toFixed(1)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`bar.low: ${this.hover.barLow.toFixed(0)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`bar.mid: ${this.hover.barMid.toFixed(0)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`bar.high: ${this.hover.barHigh.toFixed(0)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`bar.total: ${this.hover.barTotal.toFixed(0)}`)
            .fontSize(12)
            .fontColor('#333333')
        }
        .alignItems(HorizontalAlign.Start)
        .padding(10)
        .backgroundColor('#FDFDFD')
        .border({ width: 1, color: '#DDDDDD' })
        .borderRadius(10)
        .shadow({ radius: 12, color: '#26000000', offsetX: 0, offsetY: 4 })
        .position({ x: this.tooltipX(), y: this.tooltipY() })
      }
    }
    .width('100%')
    .height('100%')
  }

  private createData(): ChartData {
    const icons: number[] = [];
    const line: number[] = [];
    const scatter: number[] = [];
    const bars: BarStack[] = [];
    for (let i = 0; i < POINT_COUNT; i++) {
      const wave = 50 + Math.sin(i / 55) * 22 + Math.sin(i / 13) * 4;
      line.push(wave);
      scatter.push(50 + Math.sin(i / 31) * 28 + (Math.random() - 0.5) * 14);
      icons.push((i % 90 === 0 || Math.random() > 0.985) ? Math.floor(Math.random() * 4) + 1 : 0);
      bars.push({
        low: 8 + Math.random() * 12,
        mid: 6 + Math.random() * 10,
        high: 4 + Math.random() * 10
      });
    }
    return { icons, line, scatter, bars };
  }

  private pushOnePoint(): void {
    const now = new Date();
    const idx = now.getHours() * 60 + now.getMinutes();
    const prev = this.data.line[(idx + POINT_COUNT - 1) % POINT_COUNT];
    this.data.line[idx] = Math.max(0, Math.min(100, prev + (Math.random() - 0.48) * 8));
    this.data.scatter[idx] = Math.max(0, Math.min(100, 50 + Math.sin(Date.now() / 180000) * 30 + (Math.random() - 0.5) * 18));
    this.data.icons[idx] = Math.random() > 0.82 ? Math.floor(Math.random() * 4) + 1 : 0;
    this.data.bars[idx] = {
      low: 8 + Math.random() * 12,
      mid: 6 + Math.random() * 12,
      high: 4 + Math.random() * 10
    };
    this.fpsText = `Realtime Canvas Chart / updated ${this.formatMinute(idx)}`;
  }

  private draw(): void {
    const ctx = this.ctx;
    this.canvasW = ctx.width;
    this.canvasH = ctx.height;
    const w = this.canvasW;
    const h = this.canvasH;
    this.plot = { left: 44, top: 46, width: Math.max(1, w - 64), height: Math.max(1, h - 82) };

    ctx.clearRect(0, 0, w, h);
    this.drawBackground(ctx, w, h);
    this.drawAxes(ctx);
    this.drawIcons(ctx);
    this.drawStackBars(ctx);
    this.drawSmoothLine(ctx);
    this.drawScatter(ctx);
    this.drawHover(ctx);
  }

  private drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#F8FAFF';
    ctx.fillRect(this.plot.left, this.plot.top, this.plot.width, this.plot.height);
  }

  private drawAxes(ctx: CanvasRenderingContext2D): void {
    const p = this.plot;
    ctx.strokeStyle = '#E6EAF0';
    ctx.lineWidth = 1;
    ctx.font = '11px sans-serif';
    ctx.fillStyle = '#8A94A6';
    for (let i = 0; i <= 6; i++) {
      const y = p.top + p.height * i / 6;
      ctx.beginPath();
      ctx.moveTo(p.left, y);
      ctx.lineTo(p.left + p.width, y);
      ctx.stroke();
      ctx.fillText(`${Math.round(100 - i * 100 / 6)}`, 8, y + 4);
    }
    for (let hour = 0; hour <= 24; hour += 3) {
      const minute = hour * 60;
      const x = this.xOf(Math.min(minute, POINT_COUNT - 1));
      ctx.beginPath();
      ctx.moveTo(x, p.top);
      ctx.lineTo(x, p.top + p.height);
      ctx.stroke();
      ctx.fillText(`${hour}:00`, x - 12, p.top + p.height + 18);
    }
  }

  private drawIcons(ctx: CanvasRenderingContext2D): void {
    const top = 14;
    for (let i = 0; i < POINT_COUNT; i++) {
      const type = this.data.icons[i];
      if (type === 0) {
        continue;
      }
      const x = this.xOf(i);
      ctx.beginPath();
      if (type === 1) {
        ctx.fillStyle = '#34C759';
        ctx.arc(x, top + 7, 4, 0, Math.PI * 2);
      } else if (type === 2) {
        ctx.fillStyle = '#FF9500';
        ctx.rect(x - 4, top + 3, 8, 8);
      } else if (type === 3) {
        ctx.fillStyle = '#AF52DE';
        ctx.moveTo(x, top + 2);
        ctx.lineTo(x + 5, top + 12);
        ctx.lineTo(x - 5, top + 12);
      } else {
        ctx.fillStyle = '#FF3B30';
        ctx.arc(x, top + 7, 5, 0, Math.PI * 2);
      }
      ctx.fill();
    }
  }

  private drawSmoothLine(ctx: CanvasRenderingContext2D): void {
    ctx.strokeStyle = '#1677FF';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(this.xOf(0), this.yOf(this.data.line[0]));
    for (let i = 1; i < POINT_COUNT - 2; i += 2) {
      const xc = (this.xOf(i) + this.xOf(i + 1)) / 2;
      const yc = (this.yOf(this.data.line[i]) + this.yOf(this.data.line[i + 1])) / 2;
      ctx.quadraticCurveTo(this.xOf(i), this.yOf(this.data.line[i]), xc, yc);
    }
    ctx.stroke();
  }

  private drawScatter(ctx: CanvasRenderingContext2D): void {
    ctx.fillStyle = '#111111';
    for (let i = 0; i < POINT_COUNT; i += 4) {
      ctx.beginPath();
      ctx.arc(this.xOf(i), this.yOf(this.data.scatter[i]), 1.4, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  private drawStackBars(ctx: CanvasRenderingContext2D): void {
    const maxTotal = 40;
    const barW = Math.max(1, this.plot.width / POINT_COUNT * 0.9);
    for (let i = 0; i < POINT_COUNT; i += 3) {
      const b = this.data.bars[i];
      const x = this.xOf(i) - barW / 2;
      let base = this.plot.top + this.plot.height;
      const h1 = b.low / maxTotal * this.plot.height * 0.34;
      const h2 = b.mid / maxTotal * this.plot.height * 0.34;
      const h3 = b.high / maxTotal * this.plot.height * 0.34;
      ctx.fillStyle = '#91D5FF';
      ctx.fillRect(x, base - h1, barW, h1);
      base -= h1;
      ctx.fillStyle = '#69C0FF';
      ctx.fillRect(x, base - h2, barW, h2);
      base -= h2;
      ctx.fillStyle = '#40A9FF';
      ctx.fillRect(x, base - h3, barW, h3);
    }
  }

  private drawHover(ctx: CanvasRenderingContext2D): void {
    if (!this.hover.show) {
      return;
    }

    const x = this.xOf(this.hover.minute);
    const lineY = this.yOf(this.hover.lineValue);
    const scatterY = this.yOf(this.hover.scatterValue);

    // 1. 证券 App 风格的竖直参考线：按 x 轴分钟切片读取所有图层数据。
    ctx.strokeStyle = '#333333';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, this.plot.top);
    ctx.lineTo(x, this.plot.top + this.plot.height);
    ctx.stroke();

    // 2. 高亮折线点。
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(x, lineY, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#1677FF';
    ctx.lineWidth = 2;
    ctx.stroke();

    // 3. 高亮散点。
    ctx.fillStyle = '#111111';
    ctx.beginPath();
    ctx.arc(x, scatterY, 4, 0, Math.PI * 2);
    ctx.fill();

    // 4. 如果当前分钟顶部有图标，圈出图标。
    if (this.hover.iconType > 0) {
      ctx.strokeStyle = '#FF3B30';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(x, 21, 9, 0, Math.PI * 2);
      ctx.stroke();
    }

    // 5. 底部堆叠柱当前列高亮。
    const barW = Math.max(2, this.plot.width / POINT_COUNT * 2.4);
    ctx.strokeStyle = '#555555';
    ctx.lineWidth = 1;
    ctx.strokeRect(x - barW / 2, this.plot.top, barW, this.plot.height);
  }

  private updateHover(x: number, y: number): void {
    const minute = this.minuteOfX(x);
    this.hover = this.collectVerticalPick(minute, y);
  }

  private minuteOfX(x: number): number {
    const clampedX = Math.min(Math.max(x, this.plot.left), this.plot.left + this.plot.width);
    return Math.min(
      POINT_COUNT - 1,
      Math.max(0, Math.round((clampedX - this.plot.left) / this.plot.width * (POINT_COUNT - 1)))
    );
  }

  private collectVerticalPick(minute: number, touchY: number): VerticalPickInfo {
    const bar = this.data.bars[minute];
    return {
      show: true,
      minute,
      x: this.xOf(minute),
      touchY,
      iconType: this.data.icons[minute],
      lineValue: this.data.line[minute],
      scatterValue: this.data.scatter[minute],
      barLow: bar.low,
      barMid: bar.mid,
      barHigh: bar.high,
      barTotal: bar.low + bar.mid + bar.high
    };
  }

  private xOf(minute: number): number {
    return this.plot.left + minute / (POINT_COUNT - 1) * this.plot.width;
  }

  private yOf(value: number): number {
    const v = Math.max(0, Math.min(100, value));
    return this.plot.top + (100 - v) / 100 * this.plot.height;
  }

  private formatMinute(minute: number): string {
    const h = Math.floor(minute / 60).toString().padStart(2, '0');
    const m = (minute % 60).toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private iconName(type: number): string {
    if (type === 1) {
      return 'green dot';
    }
    if (type === 2) {
      return 'orange square';
    }
    if (type === 3) {
      return 'purple triangle';
    }
    if (type === 4) {
      return 'red dot';
    }
    return 'none';
  }

  private tooltipX(): number {
    const tooltipWidth = 185;
    const padding = 12;
    if (this.hover.x + tooltipWidth + 24 > this.canvasW) {
      return Math.max(padding, this.hover.x - tooltipWidth - 12);
    }
    return this.hover.x + 12;
  }

  private tooltipY(): number {
    const tooltipHeight = 176;
    const raw = 58 + this.hover.touchY - 88;
    return Math.max(56, Math.min(raw, this.canvasH - tooltipHeight));
  }
}
