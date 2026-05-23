// ===============================
// 边距类型定义
// ===============================
// 用来描述图表绘图区四周的留白。
// 这里的 top/right/bottom/left 都是 Canvas 内部坐标里的数值，单位可以理解为 vp。
interface PaddingType {
  top: number;     // 图表内容距离 Canvas 顶部的距离
  right: number;   // 图表内容距离 Canvas 右侧的距离，右侧还要预留 y 轴文字空间
  bottom: number;  // 图表内容距离 Canvas 底部的距离，底部还要预留 x 轴文字空间
  left: number;    // 图表内容距离 Canvas 左侧的距离
}

// ===============================
// 吸附结果类型定义
// ===============================
// 手指长按 / 拖动时，用户触摸的是连续坐标 rawX。
// 但图表数据点是离散的，例如 24 小时就是 24 * 60 = 1440 个点。
// 所以需要把手指位置吸附到最近的数据点。
// SnapResult 就是吸附之后的结果。
interface SnapResult {
  x: number;      // 吸附后的 x 坐标，也就是竖线真正应该绘制的位置
  index: number;  // 数据点索引，从 0 开始。例如 24 小时范围下，范围是 0 ~ 1439
}

@Component
export struct MergeChart {
  // ===============================
  // 时间范围切换
  // ===============================

  // 可切换的时间范围，单位是小时。
  // 当前支持 3 小时、6 小时、12 小时、24 小时。
  // 每个小时有 60 个数据点，所以：
  // 3 小时 = 180 个点
  // 6 小时 = 360 个点
  // 12 小时 = 720 个点
  // 24 小时 = 1440 个点
  private readonly TIME_RANGES: number[] = [3, 6, 12, 24]; // 小时

  // 当前时间范围在 TIME_RANGES 数组中的索引。
  // 默认值是 3，对应 TIME_RANGES[3]，也就是 24 小时。
  // 使用 @State 修饰后，状态变化时会触发 ArkUI 组件刷新。
  @State private currentRangeIndex: number = 3;   // 默认 24 小时

  // ===============================
  // Canvas 上下文
  // ===============================

  // RenderingContextSettings 用来创建 Canvas 绘制上下文。
  // new RenderingContextSettings(true) 中的 true 一般表示开启抗锯齿。
  // 抗锯齿可以让线条、圆角等图形看起来更平滑。
  private settings: RenderingContextSettings = new RenderingContextSettings(true);

  // CanvasRenderingContext2D 是 2D 绘图上下文。
  // 后续所有绘制行为，例如 clearRect、fillRect、stroke、fillText 等，
  // 都通过 this.ctx 来完成。
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // ===============================
  // 图表边距
  // ===============================

  // 图表绘图区的四周留白。
  // 注意：Canvas 本身是整个组件区域，但真正绘制网格、曲线、坐标轴的区域
  // 通常不会贴边，所以需要 padding。
  //
  // top: 15    顶部留一点空间
  // right: 30  右侧留给 y 轴刻度文字
  // bottom: 30 底部留给 x 轴刻度文字
  // left: 20   左侧留一点空间
  private readonly PADDING: PaddingType = { top: 15, right: 30, bottom: 30, left: 20 };

  // ===============================
  // Canvas 实际宽高
  // ===============================

  // Canvas 实际宽度，单位是 vp。
  // 初始为 0，等 onAreaChange 回调后才能拿到真实尺寸。
  @State private canvasWidth: number = 0;

  // Canvas 实际高度，单位是 vp。
  // 初始为 0，等 onAreaChange 回调后才能拿到真实尺寸。
  @State private canvasHeight: number = 0;

  // ===============================
  // 长按虚线状态
  // ===============================

  // 是否显示长按时的竖直虚线和顶部提示气泡。
  // true：显示
  // false：隐藏
  @State private showLongPressLine: boolean = false;

  // 当前长按竖线的 x 坐标。
  // 注意：这个 x 不是手指原始 x，而是经过 snapToDataPoint 吸附后的 x。
  @State private longPressX: number = 0;

  // 当前吸附点的数据索引。
  // 例如在 24 小时模式下，范围是 0 ~ 1439。
  // 这个索引可以用于后续读取对应分钟的数据。
  @State private currentIndex: number = 0; // 当前吸附点的索引

  // ===============================
  // 长按 / 点击 / 拖动控制变量
  // ===============================

  // 用于区分长按和点击。
  //
  // 因为 GestureGroup(GestureMode.Parallel) 中 TapGesture 和 LongPressGesture 是并行的，
  // 有些情况下长按结束后也可能触发点击逻辑。
  //
  // 所以这里设置一个标记：
  // 当长按触发后，isLongPressTriggered = true；
  // 后续 TapGesture 如果检测到这个值为 true，就不执行点击切换时间范围。
  private isLongPressTriggered: boolean = false;

  // 表示当前是否处于长按激活状态。
  //
  // true：用户已经长按成功，并且手指还在屏幕上，可以拖动竖线跟随手指移动
  // false：没有处于长按状态
  private isLongPressActive: boolean = false;

  // ===============================
  // 背景元素参数
  // ===============================

  // 背景低值。
  // 用于绘制一个半透明的目标范围背景区域。
  // 这里用 null 表示还没有数据。
  private backgroundLow: number | null = null;

  // 背景高值。
  // 和 backgroundLow 一起决定背景矩形的上下边界。
  private backgroundHigh: number | null = null;

  // 目标值。
  // 用于绘制一条横向虚线，例如血糖目标线、阈值线等。
  private backgroundTarget: number | null = null;

  // ===============================
  // 组件即将出现时执行
  // ===============================
  aboutToAppear() {
    // 模拟异步数据加载。
    //
    // 这里延迟 1 秒后设置背景元素参数，然后重新绘制图表。
    // 实际项目中，这里可能来自接口请求、数据库读取、蓝牙设备数据等。
    setTimeout(() => {
      // 设置背景区域的下边界数值。
      this.backgroundLow = 3.9;

      // 设置背景区域的上边界数值。
      this.backgroundHigh = 10;

      // 设置目标虚线数值。
      this.backgroundTarget = 5.5;

      // 数据准备好后，重新绘制图表。
      this.drawChart();
    }, 1000);
  }

  // ===============================
  // ArkUI 组件构建函数
  // ===============================
  build() {
    // 创建一个 Canvas 组件，并绑定前面创建的 2D 绘图上下文 this.ctx。
    Canvas(this.ctx)
      // Canvas 宽度占满父容器。
      .width('100%')

      // Canvas 高度占满父容器。
      .height('100%')

      // 当 Canvas 区域大小发生变化时触发。
      // 例如首次布局完成、屏幕旋转、父容器大小变化等。
      .onAreaChange((_, newArea) => {
        // 记录 Canvas 的实际宽度。
        // newArea.width 的类型可能不是严格 number，所以这里使用 as number。
        this.canvasWidth = newArea.width as number;

        // 记录 Canvas 的实际高度。
        this.canvasHeight = newArea.height as number;

        // 尺寸变化后，需要重新绘制图表。
        this.drawChart();
      })

      // Canvas 准备完成时触发。
      .onReady(() => {
        // 如果此时已经拿到了 Canvas 宽度，就绘制图表。
        // 防止 onReady 早于 onAreaChange 导致宽高还是 0。
        if (this.canvasWidth > 0) {
          this.drawChart();
        }
      })

      // 给 Canvas 添加手势。
      .gesture(
        // 使用并行手势组。
        // 这里同时监听：
        // 1. 单击 TapGesture
        // 2. 长按 LongPressGesture
        // 3. 拖动 PanGesture
        GestureGroup(GestureMode.Parallel,

          // ===============================
          // 单击手势
          // ===============================
          TapGesture({ count: 1 })
            .onAction(() => {
              // 如果刚刚触发过长按，那么本次点击事件不应该执行。
              //
              // 这是为了避免长按结束后误触发单击逻辑。
              // 例如用户长按查看详情，松手时如果系统也识别成 tap，
              // 就可能错误地切换时间范围。
              if (this.isLongPressTriggered) {
                // 消费掉这次 tap，并重置长按触发标记。
                this.isLongPressTriggered = false;
                return;
              }

              // 正常单击时，切换时间范围。
              this.toggleTimeRange();
            }),

          // ===============================
          // 长按手势
          // ===============================
          LongPressGesture({ fingers: 1, repeat: false, duration: 500 })

            // 长按达到 duration 后触发。
            // duration: 500 表示按住 500ms 后认为长按成功。
            .onAction((event: GestureEvent) => {
              // fingerList 保存当前手指信息。
              // 需要判断是否存在至少一个手指。
              if (event.fingerList && event.fingerList.length > 0) {
                // 标记：长按已经触发。
                // 用于后续阻止 tap 逻辑。
                this.isLongPressTriggered = true;

                // 标记：当前处于长按激活状态。
                // 后续 PanGesture 只有在这个状态下才会让竖线跟随移动。
                this.isLongPressActive = true;

                // 把手指当前的 localX 坐标吸附到最近的数据点。
                // event.fingerList[0].localX 是手指在当前组件坐标系里的 x 坐标。
                const snapResult: SnapResult = this.snapToDataPoint(event.fingerList[0].localX);

                // 保存吸附后的 x 坐标，用来绘制竖线。
                this.longPressX = snapResult.x;

                // 保存吸附到的数据点索引。
                this.currentIndex = snapResult.index;

                // 显示长按竖线和提示气泡。
                this.showLongPressLine = true;

                // 状态变化后重新绘制图表。
                this.drawChart();
              }
            })

            // 长按手势结束时触发。
            .onActionEnd(() => {
              // 退出长按激活状态。
              this.isLongPressActive = false;

              // 隐藏长按竖线和提示气泡。
              this.showLongPressLine = false;

              // 重新绘制图表，清除竖线和气泡。
              this.drawChart();
            }),

          // ===============================
          // 拖动手势
          // ===============================
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })

            // 拖动过程中持续触发。
            .onActionUpdate((event: GestureEvent) => {
              // 只有在长按激活状态下，拖动才更新竖线位置。
              //
              // 这样可以实现类似证券 App 的交互：
              // 先长按进入查看模式，然后左右拖动查看不同时间点的数据。
              if (this.isLongPressActive && event.fingerList && event.fingerList.length > 0) {
                // 将当前手指 x 坐标吸附到最近的数据点。
                const snapResult: SnapResult = this.snapToDataPoint(event.fingerList[0].localX);

                // 更新竖线 x 坐标。
                this.longPressX = snapResult.x;

                // 更新当前数据索引。
                this.currentIndex = snapResult.index;

                // 重新绘制图表，让竖线跟随手指移动。
                this.drawChart();
              }
            })

            // 拖动结束时触发。
            .onActionEnd(() => {
              // 如果当前还处于长按激活状态，说明这是一次长按后的拖动结束。
              if (this.isLongPressActive) {
                // 退出长按激活状态。
                this.isLongPressActive = false;

                // 隐藏长按竖线和提示气泡。
                this.showLongPressLine = false;

                // 重新绘制，清除交互层。
                this.drawChart();
              }
            })
        )
      )
  }

  // ===============================
  // 将手指原始 x 坐标吸附到最近的离散数据点
  // ===============================
  //
  // rawX:
  //   手指在 Canvas 上的原始 x 坐标。
  //
  // 返回值：
  //   {
  //     x: 吸附后的真实绘制 x 坐标,
  //     index: 吸附到的数据点索引
  //   }
  //
  // 举例：
  // 当前是 24 小时范围，则 pointsCount = 1440。
  // 图表绘图区从 plotLeft 到 plotRight。
  // 用户手指点在中间位置，大约会吸附到 index = 720。
  private snapToDataPoint(rawX: number): SnapResult {
    // 当前选中的时间范围，例如 3、6、12、24。
    const rangeHours = this.TIME_RANGES[this.currentRangeIndex];

    // 当前范围下的数据点数量。
    // 每分钟一个点，所以点数 = 小时数 * 60。
    const pointsCount = rangeHours * 60; // 每分钟一个点

    // 绘图区左边界。
    const plotLeft = this.PADDING.left;

    // 绘图区右边界。
    const plotRight = this.canvasWidth - this.PADDING.right;

    // 绘图区宽度。
    const plotWidth = plotRight - plotLeft;

    // 把手指 x 限制在绘图区范围内。
    // 如果手指在绘图区左边，就当作 plotLeft；
    // 如果手指在绘图区右边，就当作 plotRight。
    const clampedX = Math.max(plotLeft, Math.min(plotRight, rawX));

    // 根据 x 在绘图区中的比例，换算成数据点索引。
    //
    // (clampedX - plotLeft) / plotWidth
    // 得到当前 x 在绘图区中的比例，范围 0 ~ 1。
    //
    // 再乘以 pointsCount - 1
    // 得到对应的数据索引位置。
    //
    // Math.round 表示吸附到最近的那个点。
    let index = Math.round((clampedX - plotLeft) / plotWidth * (pointsCount - 1));

    // 防止 index 越界。
    // 最小不能小于 0，最大不能超过 pointsCount - 1。
    index = Math.max(0, Math.min(pointsCount - 1, index));

    // 根据吸附后的 index 反算出准确 x 坐标。
    // 这样竖线始终落在离散数据点上，而不是手指的任意位置。
    const x = plotLeft + (index / (pointsCount - 1)) * plotWidth;

    // 返回吸附后的坐标和索引。
    return { x, index };
  }

  // ===============================
  // 格式化时间戳为 YYYY-MM-DD HH:mm
  // ===============================
  //
  // timestamp:
  //   毫秒级时间戳。
  //
  // 返回示例：
  //   2024-07-09 09:16
  private formatDateTime(timestamp: number): string {
    // 根据时间戳创建 Date 对象。
    const date = new Date(timestamp);

    // 获取年份。
    const year = date.getFullYear().toString();

    // 获取月份。
    // JS 中 getMonth() 返回 0 ~ 11，所以需要 +1。
    // padStart(2, '0') 用来补齐两位，例如 7 => 07。
    const month = (date.getMonth() + 1).toString().padStart(2, '0');

    // 获取日期。
    const day = date.getDate().toString().padStart(2, '0');

    // 获取小时。
    const hours = date.getHours().toString().padStart(2, '0');

    // 获取分钟。
    const minutes = date.getMinutes().toString().padStart(2, '0');

    // 拼接成最终字符串。
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  // ===============================
  // 切换时间范围
  // ===============================
  //
  // 每点击一次图表，就切换到下一个时间范围。
  // 切换顺序：
  //   3h -> 6h -> 12h -> 24h -> 3h ...
  toggleTimeRange() {
    // 当前索引 + 1，然后对 TIME_RANGES.length 取模。
    // 这样可以循环切换。
    this.currentRangeIndex = (this.currentRangeIndex + 1) % this.TIME_RANGES.length;

    // 时间范围变化后，需要重新绘制网格、坐标轴、数据等。
    this.drawChart();
  }

  // ===============================
  // 主绘制函数
  // ===============================
  //
  // 所有 Canvas 绘制入口都集中在这里。
  //
  // 当前绘制顺序：
  // 1. 判断 Canvas 是否有尺寸
  // 2. 计算绘图区位置和大小
  // 3. 清空画布
  // 4. 计算时间范围
  // 5. 绘制网格和坐标轴
  // 6. 绘制背景目标区域
  // 7. 绘制目标虚线
  // 8. 如果正在长按，绘制竖线和提示气泡
  drawChart() {
    // 如果 Canvas 宽高还没准备好，则不绘制。
    // 避免出现除以 0 或绘制异常。
    if (this.canvasWidth === 0 || this.canvasHeight === 0) {
      return;
    }

    // 绘图区左上角 x 坐标。
    const plotLeft = this.PADDING.left;

    // 绘图区左上角 y 坐标。
    const plotTop = this.PADDING.top;

    // 绘图区宽度 = Canvas 总宽 - 左边距 - 右边距。
    const plotWidth = this.canvasWidth - this.PADDING.left - this.PADDING.right;

    // 绘图区高度 = Canvas 总高 - 上边距 - 下边距。
    const plotHeight = this.canvasHeight - this.PADDING.top - this.PADDING.bottom;

    // 每次重绘前都先清空整个 Canvas。
    // Canvas 是即时绘制模式，不会自动清理上一帧内容。
    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    // 当前时间。
    // 图表右侧通常代表“现在”。
    const now = Date.now();

    // 当前显示的时间范围，例如 24 小时。
    const rangeHours = this.TIME_RANGES[this.currentRangeIndex];

    // 图表左侧开始时间。
    // 例如当前是 24 小时模式，则 startTime = 当前时间 - 24小时。
    const startTime = now - rangeHours * 60 * 60 * 1000;

    // 绘制网格线、x 轴刻度、y 轴刻度。
    this.drawGrid(plotLeft, plotTop, plotWidth, plotHeight, startTime, now);

    // ===============================
    // 绘制背景目标区域
    // ===============================
    //
    // 只有当 low 和 high 都有值时才绘制。
    // null 表示数据还没准备好。
    if (this.backgroundLow !== null && this.backgroundHigh !== null) {
      this.drawBackgroundRect(plotLeft, plotTop, plotWidth, plotHeight, this.backgroundLow, this.backgroundHigh);
    }

    // ===============================
    // 绘制目标虚线
    // ===============================
    //
    // 只有 target 有值时才绘制。
    if (this.backgroundTarget !== null) {
      this.drawHorizontalDashLine(plotLeft, plotTop, plotWidth, plotHeight, this.backgroundTarget);
    }

    // ===============================
    // 绘制长按指示器
    // ===============================
    //
    // showLongPressLine 为 true 时，说明用户正在长按查看某个时间点。
    // 此时绘制：
    // 1. 一条竖直虚线
    // 2. 一个顶部提示气泡
    // 3. 气泡里的时间文本
    if (this.showLongPressLine) {
      // 保存当前 Canvas 状态。
      // 后面修改 strokeStyle、fillStyle、font、lineDash 等不会影响其它绘制。
      this.ctx.save();

      // 提示气泡宽度，占 Canvas 宽度的 36%。
      const indicatorWidth = this.canvasWidth * 0.36;

      // 提示气泡高度，占 Canvas 高度的 30%。
      const indicatorHeight = this.canvasHeight * 0.30;

      // 绘图区右边界。
      const plotRight = this.canvasWidth - this.PADDING.right;

      // 默认让气泡水平居中对齐当前长按竖线。
      let indicatorLeft = this.longPressX - indicatorWidth / 2;

      // 如果气泡超出绘图区左侧，则贴到 plotLeft。
      if (indicatorLeft < plotLeft) {
        indicatorLeft = plotLeft;
      } else if (indicatorLeft + indicatorWidth > plotRight) {
        // 如果气泡超出绘图区右侧，则向左移动，让右边贴到 plotRight。
        indicatorLeft = plotRight - indicatorWidth;
      }

      // 气泡顶部位置。
      // 当前逻辑是直接放在绘图区顶部。
      const indicatorTop = plotTop;

      // ===============================
      // 绘制长按竖直虚线
      // ===============================

      // 虚线颜色。
      this.ctx.strokeStyle = 'rgb(228,232,228)';

      // 虚线宽度。
      this.ctx.lineWidth = 1;

      // 设置虚线样式。
      // [5, 5] 表示画 5px，空 5px，循环重复。
      this.ctx.setLineDash([5, 5]);

      // 开始一条新路径。
      this.ctx.beginPath();

      // 从绘图区顶部开始。
      this.ctx.moveTo(this.longPressX, plotTop);

      // 到绘图区底部结束。
      this.ctx.lineTo(this.longPressX, plotTop + plotHeight);

      // 真正把线画出来。
      this.ctx.stroke();

      // 清空虚线样式，避免影响后续绘制。
      this.ctx.setLineDash([]);

      // ===============================
      // 绘制提示气泡背景
      // ===============================

      // 气泡背景颜色。
      this.ctx.fillStyle = 'rgb(220,221,224)';

      // 绘制圆角矩形。
      // 注意 drawRoundRect 内部只负责 fill，不负责 stroke。
      this.drawRoundRect(this.ctx, indicatorLeft, indicatorTop, indicatorWidth, indicatorHeight, 4);

      // 气泡内部 padding。
      // 目前只使用了 top，right/bottom/left 暂时没有参与布局。
      const padding: PaddingType = { top: 8, right: 12, bottom: 12, left: 12 };

      // 文本顶部位置。
      const contentTop = indicatorTop + padding.top;

      // 当前显示时间范围的毫秒数。
      const rangeMs = rangeHours * 3600 * 1000;

      // 当前范围的数据点数量。
      const pointsCount = rangeHours * 60;

      // 根据当前吸附索引 currentIndex 计算对应的实际时间。
      //
      // 图表时间范围是：
      //   now - rangeMs  到  now
      //
      // currentIndex 在 0 ~ pointsCount - 1 中。
      // index = 0 表示最左侧时间点。
      // index = pointsCount - 1 表示最右侧当前时间。
      const snappedTime = now - rangeMs + (this.currentIndex / (pointsCount - 1)) * rangeMs;

      // 格式化显示时间。
      const timeText = this.formatDateTime(snappedTime);

      // 设置文本颜色。
      this.ctx.fillStyle = 'rgb(80,86,86)';

      // 设置文本字体。
      // bold 表示加粗。
      // 12vp 表示字号。
      // sans-serif 表示无衬线字体。
      this.ctx.font = 'bold 12vp sans-serif';

      // 文本水平居中。
      this.ctx.textAlign = 'center';

      // 文本基线使用顶部对齐。
      this.ctx.textBaseline = 'top';

      // 文本 x 坐标：气泡水平中心。
      const textX = indicatorLeft + indicatorWidth / 2;

      // 绘制时间文本。
      this.ctx.fillText(timeText, textX, contentTop);

      // 恢复 Canvas 状态。
      // 避免长按指示器的样式影响之后的绘制。
      this.ctx.restore();
    }
  }

  // ===============================
  // 绘制横向充满 X 轴、纵向从 low 到 high 的半透明矩形
  // ===============================
  //
  // plotLeft / plotTop / plotWidth / plotHeight:
  //   绘图区的位置和大小。
  //
  // low / high:
  //   y 轴上的数值范围。
  //
  // 当前 y 轴最大值被固定为 22。
  // 所以 y 坐标换算公式是：
  //   y = plotTop + plotHeight - (value / 22) * plotHeight
  //
  // 为什么要用 plotTop + plotHeight - ...？
  // 因为 Canvas 的 y 轴是向下增大的，而数学坐标通常是向上增大的。
  private drawBackgroundRect(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number, low: number, high: number) {
    // high 对应的 y 坐标。
    // high 数值越大，y 越靠上。
    const topY = plotTop + plotHeight - (high / 22) * plotHeight;

    // low 对应的 y 坐标。
    // low 数值越小，y 越靠下。
    const bottomY = plotTop + plotHeight - (low / 22) * plotHeight;

    // 保存当前绘图状态。
    this.ctx.save();

    // 半透明青色背景。
    this.ctx.fillStyle = 'rgba(0,197,228,0.24)';

    // 绘制矩形。
    // x 从 plotLeft 开始，宽度覆盖整个绘图区。
    // y 从 topY 到 bottomY。
    this.ctx.fillRect(plotLeft, topY, plotWidth, bottomY - topY);

    // 恢复绘图状态。
    this.ctx.restore();
  }

  // ===============================
  // 绘制 y = target 处的水平虚线
  // ===============================
  //
  // target 是 y 轴上的某个值。
  // 当前 y 轴最大值固定为 22。
  private drawHorizontalDashLine(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number, target: number) {
    // 将 target 数值转换成 Canvas y 坐标。
    const dashY = plotTop + plotHeight - (target / 22) * plotHeight;

    // 保存当前绘图状态。
    this.ctx.save();

    // 虚线颜色。
    this.ctx.strokeStyle = 'rgb(170,170,170)';

    // 线宽。
    this.ctx.lineWidth = 1;

    // 设置虚线样式。
    this.ctx.setLineDash([5, 5]);

    // 开始路径。
    this.ctx.beginPath();

    // 从绘图区左侧开始。
    this.ctx.moveTo(plotLeft, dashY);

    // 到绘图区右侧结束。
    this.ctx.lineTo(plotLeft + plotWidth, dashY);

    // 绘制虚线。
    this.ctx.stroke();

    // 清除虚线设置。
    this.ctx.setLineDash([]);

    // 恢复绘图状态。
    this.ctx.restore();
  }

  // ===============================
  // 绘制圆角矩形辅助函数
  // ===============================
  //
  // ctx:
  //   Canvas 2D 绘图上下文。
  //
  // x / y:
  //   矩形左上角坐标。
  //
  // w / h:
  //   矩形宽高。
  //
  // r:
  //   圆角半径。
  //
  // 说明：
  // Canvas 原生没有直接的 fillRoundRect 这种接口，
  // 所以需要通过 moveTo、lineTo、arcTo 手动拼出圆角矩形路径。
  private drawRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
    // 开始一条新路径。
    ctx.beginPath();

    // 从左上角圆角之后的位置开始。
    ctx.moveTo(x + r, y);

    // 绘制上边线，到右上角圆角之前。
    ctx.lineTo(x + w - r, y);

    // 右上角圆角。
    ctx.arcTo(x + w, y, x + w, y + r, r);

    // 右边线，到右下角圆角之前。
    ctx.lineTo(x + w, y + h - r);

    // 右下角圆角。
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);

    // 下边线，到左下角圆角之后。
    ctx.lineTo(x + r, y + h);

    // 左下角圆角。
    ctx.arcTo(x, y + h, x, y + h - r, r);

    // 左边线，到左上角圆角之前。
    ctx.lineTo(x, y + r);

    // 左上角圆角。
    ctx.arcTo(x, y, x + r, y, r);

    // 闭合路径。
    ctx.closePath();

    // 使用当前 fillStyle 填充这个圆角矩形。
    ctx.fill();
  }

  // ===============================
  // 绘制网格与坐标轴
  // ===============================
  //
  // plotLeft / plotTop / plotWidth / plotHeight:
  //   绘图区的位置和大小。
  //
  // startTime:
  //   当前图表最左侧对应的时间戳。
  //
  // endTime:
  //   当前图表最右侧对应的时间戳，通常是 now。
  //
  // 该函数负责绘制：
  // 1. y 轴横向网格线
  // 2. y 轴右侧刻度文本
  // 3. x 轴竖向网格线
  // 4. x 轴底部时间文本
  // 5. 左边界和底边界坐标轴线
  private drawGrid(plotLeft: number, plotTop: number, plotWidth: number, plotHeight: number,
    startTime: number, endTime: number) {
    // 网格线颜色。
    this.ctx.strokeStyle = 'rgb(80,86,86)';

    // 网格线宽度。
    this.ctx.lineWidth = 0.5;

    // 坐标轴文字颜色。
    this.ctx.fillStyle = '#666';

    // 坐标轴文字字体。
    this.ctx.font = '12vp sans-serif';

    // y 轴文字左对齐。
    this.ctx.textAlign = 'left';

    // ===============================
    // 绘制 y 轴横向网格线和刻度文字
    // ===============================
    //
    // y 轴刻度从 2 到 22，每隔 2 一个刻度。
    // 最大值固定为 22。
    for (let val = 2; val <= 22; val += 2) {
      // 将 val 映射到 Canvas y 坐标。
      //
      // val = 22 时，y = plotTop，位于绘图区顶部。
      // val = 0 时，y = plotTop + plotHeight，位于绘图区底部。
      const y = plotTop + plotHeight - (val / 22) * plotHeight;

      // 绘制一条横向网格线。
      this.ctx.beginPath();
      this.ctx.moveTo(plotLeft, y);
      this.ctx.lineTo(plotLeft + plotWidth, y);
      this.ctx.stroke();

      // 在绘图区右侧绘制 y 轴刻度文本。
      // y + 4 是为了让文字视觉上更靠近网格线中间。
      this.ctx.fillText(val.toString(), plotLeft + plotWidth + 5, y + 4);
    }

    // ===============================
    // 准备绘制 x 轴刻度
    // ===============================

    // x 轴文字水平居中。
    this.ctx.textAlign = 'center';

    // 当前图表展示的总时间长度，单位毫秒。
    const rangeMs = endTime - startTime;

    // 当前图表展示的总小时数。
    // 因为 TIME_RANGES 本身是整数小时，所以这里 round 后一般是 3、6、12、24。
    const rangeHours = Math.round(rangeMs / (60 * 60 * 1000));

    // stepMs 表示 x 轴刻度间隔。
    // thresholdMs 表示是否绘制当前整点刻度的阈值。
    //
    // 举例：
    // 当前时间是 09:16。
    // 最近整点是 09:00。
    // 如果 diffFromBase = 16 分钟。
    // 对于 3 小时模式 thresholdMs = 15 分钟，
    // 因为 16 >= 15，所以会绘制 09am 这个刻度。
    let stepMs: number;
    let thresholdMs: number;

    // 根据不同时间范围设置 x 轴刻度间隔。
    switch (rangeHours) {
      case 3:
        // 3 小时范围：每 1 小时一个刻度。
        stepMs = 1 * 60 * 60 * 1000;

        // 当前整点距离现在超过 15 分钟才绘制。
        thresholdMs = 15 * 60 * 1000;
        break;
      case 6:
        // 6 小时范围：每 1 小时一个刻度。
        stepMs = 1 * 60 * 60 * 1000;

        // 当前整点距离现在超过 40 分钟才绘制。
        thresholdMs = 40 * 60 * 1000;
        break;
      case 12:
        // 12 小时范围：每 2 小时一个刻度。
        stepMs = 2 * 60 * 60 * 1000;

        // 当前整点距离现在超过 1 小时才绘制。
        thresholdMs = 60 * 60 * 1000;
        break;
      case 24:
        // 24 小时范围：每 4 小时一个刻度。
        stepMs = 4 * 60 * 60 * 1000;

        // 当前整点距离现在超过 1 小时才绘制。
        thresholdMs = 60 * 60 * 1000;
        break;
      default:
        // 兜底逻辑：默认每 4 小时一个刻度。
        stepMs = 4 * 60 * 60 * 1000;
        thresholdMs = 60 * 60 * 1000;
    }

    // ===============================
    // 绘制最右侧“现在”刻度
    // ===============================

    // 图表最右侧 x 坐标表示当前时间。
    const nowX = plotLeft + plotWidth;

    // 绘制“现在”对应的竖向网格线。
    this.ctx.beginPath();
    this.ctx.moveTo(nowX, plotTop);
    this.ctx.lineTo(nowX, plotTop + plotHeight);
    this.ctx.stroke();

    // 在底部绘制“现在”文字。
    this.ctx.fillText('现在', nowX, plotTop + plotHeight + 15);

    // ===============================
    // 计算最近的整点时间
    // ===============================

    // 根据 endTime 创建日期对象。
    const baseDate = new Date(endTime);

    // 把时间归零到最近的整点。
    // 例如 09:16:30 => 09:00:00。
    baseDate.setMinutes(0, 0, 0);

    // 最近整点时间戳。
    const baseTime = baseDate.getTime();

    // 当前时间距离最近整点过去了多久。
    // 例如现在 09:16，则 diffFromBase = 16 分钟。
    const diffFromBase = endTime - baseTime;

    // 判断是否绘制最近整点刻度。
    //
    // 条件 1：当前时间距离最近整点的时间差要大于阈值。
    // 条件 2：最近整点必须在图表时间范围内。
    const drawBaseTick = diffFromBase >= thresholdMs && baseTime >= startTime;

    // ===============================
    // 绘制最近整点刻度
    // ===============================
    if (drawBaseTick) {
      // 将 baseTime 映射到 x 坐标。
      const x = plotLeft + ((baseTime - startTime) / rangeMs) * plotWidth;

      // 绘制竖向网格线。
      this.ctx.beginPath();
      this.ctx.moveTo(x, plotTop);
      this.ctx.lineTo(x, plotTop + plotHeight);
      this.ctx.stroke();

      // 生成 12 小时制标签。
      const date = new Date(baseTime);

      // getHours() 是 0 ~ 23。
      // 转成 12 小时制。
      let hour12 = date.getHours() % 12;

      // 0 点或 12 点在 12 小时制里显示为 12。
      if (hour12 === 0) hour12 = 12;

      // 判断上午/下午。
      const ampm = date.getHours() < 12 ? 'am' : 'pm';

      // 拼出标签，例如 09am、02pm。
      const label = `${hour12.toString().padStart(2, '0')}${ampm}`;

      // 绘制 x 轴刻度文字。
      this.ctx.fillText(label, x, plotTop + plotHeight + 15);
    }

    // ===============================
    // 从最近整点开始，向左按 stepMs 逐个绘制刻度
    // ===============================

    // 第一个向左的刻度时间。
    let tickTime = baseTime - stepMs;

    // 只要 tickTime 仍然在图表范围内，就继续绘制。
    while (tickTime >= startTime) {
      // 将 tickTime 映射成 x 坐标。
      const x = plotLeft + ((tickTime - startTime) / rangeMs) * plotWidth;

      // 绘制竖向网格线。
      this.ctx.beginPath();
      this.ctx.moveTo(x, plotTop);
      this.ctx.lineTo(x, plotTop + plotHeight);
      this.ctx.stroke();

      // 构造刻度文字。
      const date = new Date(tickTime);

      // 转换成 12 小时制小时。
      let hour12 = date.getHours() % 12;

      // 0 点或 12 点显示为 12。
      if (hour12 === 0) hour12 = 12;

      // 上午 / 下午。
      const ampm = date.getHours() < 12 ? 'am' : 'pm';

      // 生成最终标签。
      const label = `${hour12.toString().padStart(2, '0')}${ampm}`;

      // 绘制底部 x 轴文字。
      this.ctx.fillText(label, x, plotTop + plotHeight + 15);

      // 继续往左推一个刻度间隔。
      tickTime -= stepMs;
    }

    // ===============================
    // 绘制坐标轴边框线
    // ===============================

    // 坐标轴边框颜色。
    this.ctx.strokeStyle = '#333';

    // 坐标轴线宽。
    this.ctx.lineWidth = 1;

    // 开始路径。
    this.ctx.beginPath();

    // 从左上角开始。
    this.ctx.moveTo(plotLeft, plotTop);

    // 画左侧 y 轴线。
    this.ctx.lineTo(plotLeft, plotTop + plotHeight);

    // 画底部 x 轴线。
    this.ctx.lineTo(plotLeft + plotWidth, plotTop + plotHeight);

    // 绘制路径。
    this.ctx.stroke();
  }
}