const POINT_COUNT: number = 1440;
const MAX_Y: number = 22;
const MIN_Y: number = 0;

interface BarStack {
  sleep: number;
  aid: number;
  active: number;
}

interface EventIcon {
  minute: number;
  type: number;
  label: string;
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
  barSleep: number;
  barAid: number;
  barActive: number;
  barTotal: number;
}

@Entry
@Component
struct Index {
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private timer: number = -1;
  private data: ChartData = this.createData();
  private plot: PlotRect = { left: 30, top: 32, width: 1, height: 1 };
  private canvasW: number = 0;
  private canvasH: number = 0;
  private currentMinute: number = 720;
  private selectedMinute: number = 556;

  @State private hover: VerticalPickInfo = {
    show: true,
    minute: 556,
    x: 0,
    touchY: 120,
    iconType: 2,
    lineValue: 6.4,
    scatterValue: 7.8,
    barSleep: 0.6,
    barAid: 0.4,
    barActive: 0.7,
    barTotal: 1.7
  };

  @State private titleText: string = '硅基 GS1 Pro   (...)';
  @State private subText: string = 'AR-B330A/180\nQ100001  (120)';

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.pushOnePoint();
      this.draw();
    }, 800);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  build() {
    Stack() {
      Column() {
        Canvas(this.ctx)
          .width('100%')
          .height('78%')
          .backgroundColor('#071311')
          .onReady(() => {
            this.canvasW = this.ctx.width;
            this.canvasH = this.ctx.height;
            this.hover = this.collectVerticalPick(this.selectedMinute, 108);
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
              // 证券 App 风格：松手后保留最后一次选中的竖线和浮窗。
              this.draw();
            }
          })

        Row() {
          Text(this.titleText)
            .fontSize(18)
            .fontColor('#AAB0AF')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .padding({ left: 18, top: 12 })

          Text(this.subText)
            .fontSize(18)
            .fontColor('#B4B7B6')
            .textAlign(TextAlign.End)
            .lineHeight(30)
            .padding({ right: 28, top: 8 })
        }
        .width('100%')
        .height('22%')
        .backgroundColor('#071311')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#071311')

      if (this.hover.show) {
        Column() {
          Text(`2024-07-09   ${this.formatMinute(this.hover.minute)}`)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#545C5F')
            .maxLines(1)

          Text(`${this.iconName(this.hover.iconType)}`)
            .fontSize(27)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C383B')
            .margin({ top: 16 })

          Text(`趋势 ${this.hover.lineValue.toFixed(1)}  ·  事件 ${this.hover.scatterValue.toFixed(1)}  ·  柱 ${this.hover.barTotal.toFixed(1)}`)
            .fontSize(13)
            .fontColor('#667073')
            .margin({ top: 10 })
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, top: 18, bottom: 16 })
        .width(312)
        .height(130)
        .backgroundColor('#D8D9DD')
        .borderRadius(7)
        .position({ x: this.tooltipX(), y: this.tooltipY() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#071311')
  }

  private createData(): ChartData {
    const icons: number[] = [];
    const line: number[] = [];
    const scatter: number[] = [];
    const bars: BarStack[] = [];

    for (let i = 0; i < POINT_COUNT; i++) {
      icons.push(0);
      const hour = i / 60;
      const base = 5.8 + Math.sin(i / 70) * 0.35 + Math.sin(i / 29) * 0.18;
      const morningBump = 4.6 * Math.exp(-Math.pow((hour - 9.45) / 0.78, 2));
      const aidBump = 1.3 * Math.exp(-Math.pow((hour - 5.7) / 0.45, 2));
      const earlyBump = 1.4 * Math.exp(-Math.pow((hour - 0.55) / 0.32, 2));
      line.push(this.clamp(base + morningBump + aidBump + earlyBump, 4.4, 12.4));
      scatter.push(0);
      bars.push({ sleep: 0, aid: 0, active: 0 });
    }

    this.markRange(bars, 0, 70, 1.3, 0, 0.1);
    this.markRange(bars, 72, 190, 0.8, 0, 0.0);
    this.markRange(bars, 220, 340, 0.0, 0.0, 0.0);
    this.markRange(bars, 360, 500, 1.5, 0, 0.0);
    this.markRange(bars, 560, 830, 1.5, 0, 0.0);
    this.markRange(bars, 875, 930, 0.0, 1.4, 0.5);
    this.markRange(bars, 955, 1000, 1.3, 0.0, 0.2);
    this.markRange(bars, 1010, 1030, 0.9, 0.0, 0.0);
    this.markRange(bars, 1030, 1100, 1.2, 0.0, 0.0);
    this.markRange(bars, 1110, 1170, 1.6, 0.0, 0.0);
    this.markRange(bars, 1170, 1210, 1.3, 0.0, 0.0);

    // 顶部圆形事件图标，位置和截图类似。
    icons[150] = 1;
    icons[365] = 2;
    icons[545] = 2;
    icons[670] = 3;
    icons[735] = 4;
    icons[820] = 5;
    icons[1345] = 5;

    // 红色事件点。
    scatter[710] = 7.5;
    scatter[925] = 7.9;

    return { icons, line, scatter, bars };
  }

  private markRange(bars: BarStack[], start: number, end: number, sleep: number, aid: number, active: number): void {
    for (let i = start; i <= end && i < bars.length; i++) {
      bars[i] = { sleep, aid, active };
    }
  }

  private pushOnePoint(): void {
    const idx = this.currentMinute;
    const prevIdx = idx <= 0 ? 0 : idx - 1;
    const prev = this.data.line[prevIdx];
    this.data.line[idx] = this.clamp(prev + (Math.random() - 0.45) * 0.2, 4.5, 11.5);
    this.data.bars[idx] = {
      sleep: Math.random() > 0.45 ? 1.0 + Math.random() * 0.5 : 0,
      aid: Math.random() > 0.75 ? 1.2 + Math.random() * 0.5 : 0,
      active: Math.random() > 0.7 ? 0.4 + Math.random() * 0.5 : 0
    };
    this.currentMinute = Math.min(1439, this.currentMinute + 1);
    if (this.hover.show) {
      this.hover = this.collectVerticalPick(this.hover.minute, this.hover.touchY);
    }
  }

  private draw(): void {
    const ctx = this.ctx;
    this.canvasW = ctx.width;
    this.canvasH = ctx.height;
    const w = this.canvasW;
    const h = this.canvasH;
    this.plot = { left: 30, top: 32, width: Math.max(1, w - 72), height: Math.max(1, h - 76) };

    ctx.clearRect(0, 0, w, h);
    this.drawBackground(ctx, w, h);
    this.drawGridAndAxes(ctx);
    this.drawTargetBand(ctx);
    this.drawBaseline(ctx);
    this.drawStackBars(ctx);
    this.drawSmoothLine(ctx);
    this.drawScatter(ctx);
    this.drawIcons(ctx);
    this.drawHover(ctx);
  }

  private drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    ctx.fillStyle = '#071311';
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = '#52605F';
    ctx.lineWidth = 2;
    ctx.strokeRect(this.plot.left, this.plot.top, this.plot.width, this.plot.height);
  }

  private drawGridAndAxes(ctx: CanvasRenderingContext2D): void {
    const p = this.plot;
    ctx.font = '26px sans-serif';
    ctx.fillStyle = '#B8BBBB';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';

    for (let value = 2; value <= 22; value += 2) {
      const y = this.yOf(value);
      ctx.strokeStyle = value % 4 === 0 ? '#52605F' : '#243532';
      ctx.lineWidth = value % 4 === 0 ? 1.4 : 1;
      ctx.beginPath();
      ctx.moveTo(p.left, y);
      ctx.lineTo(p.left + p.width, y);
      ctx.stroke();
      ctx.fillText(`${value}`, p.left + p.width + 8, y);
    }

    for (let hour = 0; hour <= 12; hour += 2) {
      const minute = hour >= 12 ? POINT_COUNT - 1 : hour * 60;
      const x = this.xOf(minute);
      ctx.strokeStyle = hour % 4 === 0 ? '#52605F' : '#1A2A27';
      ctx.lineWidth = hour % 4 === 0 ? 1.4 : 1;
      ctx.beginPath();
      ctx.moveTo(x, p.top);
      ctx.lineTo(x, p.top + p.height);
      ctx.stroke();

      ctx.fillStyle = '#B8BBBB';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      if (hour === 12) {
        ctx.fillText('现在', x + 6, p.top + p.height + 8);
      } else {
        ctx.fillText(`${hour}`, x, p.top + p.height + 8);
      }
    }
  }

  private drawTargetBand(ctx: CanvasRenderingContext2D): void {
    const x = this.plot.left;
    const yTop = this.yOf(10);
    const yBottom = this.yOf(4.3);
    ctx.fillStyle = '#07535B';
    ctx.globalAlpha = 0.86;
    ctx.fillRect(x, yTop, this.plot.width, yBottom - yTop);
    ctx.globalAlpha = 1;

    ctx.strokeStyle = '#1A8791';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, yTop, this.plot.width, yBottom - yTop);
  }

  private drawBaseline(ctx: CanvasRenderingContext2D): void {
    const y = this.yOf(5.1);
    ctx.strokeStyle = '#B8B8B8';
    ctx.lineWidth = 4;
    ctx.setLineDash([12, 14]);
    ctx.beginPath();
    ctx.moveTo(this.plot.left + 26, y);
    ctx.lineTo(this.plot.left + this.plot.width - 140, y);
    ctx.stroke();
    ctx.setLineDash([]);
  }

  private drawIcons(ctx: CanvasRenderingContext2D): void {
    const y = this.plot.top + 24;
    for (let i = 0; i < POINT_COUNT; i++) {
      const type = this.data.icons[i];
      if (type === 0) {
        continue;
      }
      const x = this.xOf(i);
      ctx.fillStyle = '#55605F';
      ctx.beginPath();
      ctx.arc(x, y, 20, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.font = '25px sans-serif';
      ctx.fillText(this.iconEmoji(type), x, y + 1);
    }
  }

  private drawSmoothLine(ctx: CanvasRenderingContext2D): void {
    ctx.strokeStyle = '#F4F5F5';
    ctx.lineWidth = 8;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(this.xOf(0), this.yOf(this.data.line[0]));
    for (let i = 2; i < 780; i += 4) {
      const xc = (this.xOf(i) + this.xOf(i + 2)) / 2;
      const yc = (this.yOf(this.data.line[i]) + this.yOf(this.data.line[i + 2])) / 2;
      ctx.quadraticCurveTo(this.xOf(i), this.yOf(this.data.line[i]), xc, yc);
    }
    for (let i = 780; i < 1220; i += 4) {
      const xc = (this.xOf(i) + this.xOf(i + 2)) / 2;
      const yc = (this.yOf(this.data.line[i]) + this.yOf(this.data.line[i + 2])) / 2;
      ctx.quadraticCurveTo(this.xOf(i), this.yOf(this.data.line[i]), xc, yc);
    }
    ctx.stroke();
  }

  private drawScatter(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < POINT_COUNT; i++) {
      const value = this.data.scatter[i];
      if (value <= 0) {
        continue;
      }
      const x = this.xOf(i);
      const y = this.yOf(value);
      ctx.strokeStyle = '#FF454C';
      ctx.fillStyle = '#FF454C';
      ctx.lineWidth = 4;
      ctx.beginPath();
      if (i === 710) {
        ctx.moveTo(x, y - 12);
        ctx.quadraticCurveTo(x + 11, y, x, y + 9);
        ctx.quadraticCurveTo(x - 11, y, x, y - 12);
        ctx.stroke();
      } else {
        ctx.arc(x, y, 11, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  private drawStackBars(ctx: CanvasRenderingContext2D): void {
    const p = this.plot;
    const barW = Math.max(2, p.width / 1440 * 2.1);
    for (let i = 0; i < POINT_COUNT; i += 2) {
      const b = this.data.bars[i];
      if (b.sleep + b.aid + b.active <= 0) {
        continue;
      }
      let base = p.top + p.height;
      const x = this.xOf(i) - barW / 2;
      const h1 = b.sleep / MAX_Y * p.height;
      const h2 = b.aid / MAX_Y * p.height;
      const h3 = b.active / MAX_Y * p.height;

      if (h1 > 0) {
        ctx.fillStyle = '#613050';
        ctx.fillRect(x, base - h1, barW, h1);
        ctx.strokeStyle = '#F46CE9';
        ctx.lineWidth = 2;
        ctx.strokeRect(x, base - h1, barW, h1);
        base -= h1;
      }
      if (h2 > 0) {
        ctx.fillStyle = '#67DAE8';
        ctx.fillRect(x, base - h2, barW, h2);
        base -= h2;
      }
      if (h3 > 0) {
        ctx.fillStyle = '#0CA2AE';
        ctx.fillRect(x, base - h3, barW, h3);
      }
    }

    // 底部青色“当前”时间条。
    ctx.fillStyle = '#039EAA';
    ctx.fillRect(p.left, p.top + p.height - 7, p.width, 7);
  }

  private drawHover(ctx: CanvasRenderingContext2D): void {
    if (!this.hover.show) {
      return;
    }
    const x = this.xOf(this.hover.minute);

    // 竖直选中线：从顶部图标层贯穿到柱状图层。
    ctx.strokeStyle = '#727B7A';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(x, this.plot.top);
    ctx.lineTo(x, this.plot.top + this.plot.height);
    ctx.stroke();

    // tooltip 顶部小三角，模拟截图里的气泡指向选中点。
    const tx = this.tooltipX();
    const ty = this.tooltipY();
    const tipX = this.clamp(x, tx + 24, tx + 288);
    ctx.fillStyle = '#D8D9DD';
    ctx.beginPath();
    ctx.moveTo(tipX, ty - 8);
    ctx.lineTo(tipX - 12, ty + 4);
    ctx.lineTo(tipX + 12, ty + 4);
    ctx.closePath();
    ctx.fill();

    // 选中点高亮。
    const lineY = this.yOf(this.hover.lineValue);
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(x, lineY, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#071311';
    ctx.lineWidth = 3;
    ctx.stroke();

    // 底部事件按钮样式。
    if (this.hover.barTotal > 0.1) {
      ctx.fillStyle = '#08A8B7';
      ctx.beginPath();
      ctx.arc(x, this.plot.top + this.plot.height - 24, 18, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#FFFFFF';
      ctx.font = '22px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('▣', x, this.plot.top + this.plot.height - 25);
    }
  }

  private updateHover(x: number, y: number): void {
    const minute = this.minuteOfX(x);
    this.selectedMinute = minute;
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
      barSleep: bar.sleep,
      barAid: bar.aid,
      barActive: bar.active,
      barTotal: bar.sleep + bar.aid + bar.active
    };
  }

  private xOf(minute: number): number {
    return this.plot.left + minute / (POINT_COUNT - 1) * this.plot.width;
  }

  private yOf(value: number): number {
    const v = this.clamp(value, MIN_Y, MAX_Y);
    return this.plot.top + (MAX_Y - v) / (MAX_Y - MIN_Y) * this.plot.height;
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private formatMinute(minute: number): string {
    const h = Math.floor(minute / 60).toString().padStart(2, '0');
    const m = (minute % 60).toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private iconName(type: number): string {
    if (type === 1) {
      return 'Ruy_睡眠';
    }
    if (type === 2) {
      return 'Ruy_AID运动';
    }
    if (type === 3) {
      return 'Ruy_心率';
    }
    if (type === 4) {
      return 'Ruy_饮食';
    }
    if (type === 5) {
      return 'Ruy_夜间';
    }
    return 'Ruy_普通记录';
  }

  private iconEmoji(type: number): string {
    if (type === 1) {
      return '☂';
    }
    if (type === 2) {
      return '🏃';
    }
    if (type === 3) {
      return '❤';
    }
    if (type === 4) {
      return '🍔';
    }
    if (type === 5) {
      return '☾';
    }
    return '•';
  }

  private tooltipX(): number {
    const tooltipWidth = 312;
    const raw = this.hover.x - tooltipWidth / 2;
    return Math.max(24, Math.min(raw, this.canvasW - tooltipWidth - 48));
  }

  private tooltipY(): number {
    return this.plot.top + 58;
  }
}
