import dayjs from 'dayjs';
import { DOSE } from '@/modules/dose/dose.config';
import { REPORT_ID } from '@/modules/report/configs/report.id';
import { fillZero, formatTime, webTimeToServerTime } from '@/lib/time/util/time.util';
import { CARD_CHART, CARD_STATUS, isChart } from '@/modules/record/config/card.config';
import { INS, REQ_PATTERN } from '@/modules/ins/config/ins.config';
import { ChartRecordDTO, RATE_DATA } from '@/modules/admission/dto/card.dto';
import { CHART_CONFIG } from '@/modules/chart/config/chart.config';
import { getChartTimeText, getDecodeHtml, getDoubleDecodeHtml, getXAxisLabelFormatter } from '@/modules/chart/utils/chart.util';
import {
  FIFTEEN_MINUTE_INDEXES_PER_DAY,
  FIVE_MINUTE_INDEXES_PER_DAY,
  MINUTES_PER_DAY,
  MINUTES_PER_HOUR,
  MS_PER_SECOND,
  ONE_MINUTE,
  SECONDS_PER_DAY,
  SECONDS_PER_MINUTE,
  THREE_MINUTE_INDEXES_PER_DAY,
} from '@/lib/time/config/time.config';
import { realRoundTo2Digit, realRoundTo3Digit, roundTo } from '@/lib/math/util/math.util';
import { isDelayDoseStatus, isDose, isImmDoseStatus, isRate } from '@/modules/ins/utils/ins.util';
import { useScreenStore } from '@/lib/screen/store/screen.store';
import { getInsSeriesBaseConfig } from '@/modules/ins/config/ins.chart.config';
import { getHistoryTitle, getTitleByHistoryKind, isHistoryBase, isHistoryDose, isHistoryImmDose, isHistoryInfusion, isHistoryTinyDose } from '@/modules/record/utils/history.util';
import { HISTORY_KIND } from '@/modules/record/config/history.config';
import { KIND_INDEX } from '@/modules/ins/config/infusion.config';
import { isClosedLoopDose, isDelayDose } from '@/modules/dose/dose.util';
import { BASE_KIND } from '@/modules/base/config/base.kind';
import { isClosedLoopTopSecret } from '@/modules/closed-loop/util/closed.loop.util';
import { FONT_SIZE_10, FONT_SIZE_12, FONT_WEIGHT_BOLD } from '@/lib/chart/config/chart.font';
import { COLOR_BLACK_0, COLOR_RED_0 } from '@/lib/chart/config/chart.color';
import { isClosedLoopBase } from '@/modules/base/util/base.util';
import { COLOR_GRAY_2 } from '@/lib/style/color';
import { getBolusValueText } from '@/modules/ins/utils/ins.infusion.util';
import { FONT_WEIGHT_NORMAL } from '@/lib/style/font';
import { BASE } from '@/modules/base/config/base.config';
import { MIN_SCREEN_WIDTH } from '@/lib/env/config/env.screen.config';
import { MODE_VALUE_MERGE } from '@/modules/ins/config/mode.config';
import { PAUSE_COLOR, PAUSE_TEXT_COLOR } from '@/modules/ins/config/pause.config';
import { PausePayload } from '@/modules/ins/types/pause.type';
import { SelectItemVO } from '@/lib/aaruy-design/selector/vo/SelectItem.vo';
import { PUMP_STOP, PUMP_STOP_ITEM_MAP } from '@/modules/pump/config/pump.stop';
import type { PumpInfoBolusDTO } from '@/modules/pump/dto/pump.info.dto';
import type { InsChartSeriesType } from '@/modules/ins/types/ins.chart.type';
import type { InsKindType, InsPayloadType } from '@/modules/ins/types/ins.type';
import type { BolusOverlayDataType } from '@/modules/bolus/type/bolus.overlay.type';
import type { InsulinChartFormatParamType, InsulinChartYDataType, PayloadType } from '@/modules/ins/types/insulin.chart.type';


interface SeriesDataItemLabel {
  show: boolean;
  silent: boolean;
  position: string;
  distance: number;
  align: string;
  width: number;
  height: number;
  lineHeight: number;
  fontSize: number;
  fontWeight: string | number;
  color: string;
  backgroundColor: {
    image: string;
  };
  formatter: (p: InsulinChartFormatParamType) => string;
}

interface SeriesDataItem {
  value: number;
  itemStyle?: {
    color: string;
  };
  payload?: PayloadType;
  label?: SeriesDataItemLabel;
}

/**
 * 胰岛素图形 VO
 *
 * 基础率、大剂量
 */
export class InsulinChartVO {
  private readonly _startTime: number; // 图形 X 轴起始点时刻，单位秒
  private readonly _rateData: RATE_DATA; // 胰岛素数据
  private readonly _rateData3Min: RATE_DATA; // 每3分钟合并一个值
  private readonly _rateData5Min: RATE_DATA; // 每5分钟合并一个值
  private readonly _forwardOrderedRecords: Array<ChartRecordDTO>; // 拷贝一份服务返回的记录，并按记录发生时刻正序排列
  private readonly _series: InsChartSeriesType; // 跳过 RATE_DATA 直接出 series
  private readonly _isReport: boolean; // 是否用于报告
  private readonly _pxPerIndexInX: number | null; // X轴1个索引所占的像素值（px），保留2位小数;
  private readonly _isRealTime: boolean; // 是否实时输注图谱（院泵患者界面）仅PC
  private readonly _isMerge: boolean | undefined; // 是否综合图谱（PC:患者信息-实时数据、数据分析-每日综合, APP:概况-实时数据、分析-每日综合）
  private readonly _xWidth: number | undefined; // x轴的宽度(px)
  private readonly _screenWidth: number; // 屏幕宽度(px)，用于区分"手机/平板"等。
  private readonly _isInsPage: boolean;  // 是否胰岛素用量界面 仅PC
  
  // minPerIndex: 1个索引占的分钟数
  // bolusInfo: 实时运行的大剂量数据
  // xWidth: 整条X轴的像素值(px)
  constructor(startTime: number, records: Array<ChartRecordDTO>, isRealTime?: boolean, minPerIndex?: 1 | 3 | 5, bolusInfo?: PumpInfoBolusDTO, isReport?: boolean, xWidth?: number, isMerge?: boolean, isInsPage?: boolean) {
    this._startTime = startTime;
    this._isReport = isReport || false;
    this._pxPerIndexInX = minPerIndex && xWidth ? realRoundTo2Digit(xWidth / (1440 / minPerIndex)) : null;
    this._isMerge = isMerge;
    this._isRealTime = isRealTime || false;
    this._xWidth = xWidth;
    this._screenWidth = useScreenStore().widthPixel;
    this._isInsPage = isInsPage || false;
    if (isRealTime) {
      // 院泵患者卡片
      this._forwardOrderedRecords = Array.from(records).sort((a, b) => a.record_time - b.record_time);
      // this._series = this._getNewSeries(startTime, this._forwardOrderedRecords);
      this._series = this._getNewSeriesSP(startTime, this._forwardOrderedRecords, minPerIndex || 1, bolusInfo);
    } else if (minPerIndex) {
      this._forwardOrderedRecords = Array.from(records).sort((a, b) => a.record_time - b.record_time);
      this._series = this._getNewSeriesSP(startTime, this._forwardOrderedRecords, minPerIndex || 1, bolusInfo);
    } else {
      // todo: 优化
      this._forwardOrderedRecords = Array.from(records).sort((a, b) => a.record_time - b.record_time);
      this._rateData = this._getRateDataFromStartTimeAndRecords(startTime, this._forwardOrderedRecords);
      this._rateData3Min = this._getRateDataPerThreePointsFromStartTimeAndRecords(startTime, this._forwardOrderedRecords);
      this._rateData5Min = this._getRateDataPerFivePointsFromStartTimeAndRecords(startTime, this._forwardOrderedRecords);
    }
  }
  
  // 获取 CSII 的 series 数据
  private _getNewSeriesSP(ist: number, dtos: Array<ChartRecordDTO>, minPerIndex: 1 | 3 | 5, bolusInfo?: PumpInfoBolusDTO): InsChartSeriesType {
    const X_OFFSET_1 = 6;
    const MARK_LINE_WIDTH = 0;
    
    const s = [] as Array<SeriesDataItem>;
    const XEndTime = ist + SECONDS_PER_DAY;
    const currentTime = webTimeToServerTime(new Date().getTime()); // 电脑上当前时刻的时间戳，单位秒;
    const r = realRoundTo3Digit;
    const secondsPerIndex = SECONDS_PER_MINUTE * minPerIndex;
    // 3min/5min 图谱中，不足一个索引但真实存在的短输注段仍需至少展示一个索引。
    const getVisibleRunningIndexes = (start: number, seconds: number): number => {
      const visibleStartTime = Math.max(start, ist);
      const visibleEndTime = Math.min(start + seconds, XEndTime);
      if (visibleEndTime <= visibleStartTime) {
        return 0;
      }
      const startIndex = Math.floor((visibleStartTime - ist) / secondsPerIndex);
      const endIndex = Math.ceil((visibleEndTime - ist) / secondsPerIndex);
      return Math.max(1, endIndex - startIndex);
    };
    // 短基础率和后一段基础率落在同一个索引时，保留短基础率，避免被后一段直接覆盖。
    const shouldKeepOldShortBase = (oldItem: SeriesDataItem, oldKind: HISTORY_KIND | null, currentKind: HISTORY_KIND, currentStartTime: number, currentEndTime: number): boolean => {
      const oldPayload = oldItem.payload;
      if (!oldPayload || oldKind === null || !isHistoryBase(oldKind) || !isHistoryBase(currentKind)) {
        return false;
      }
      const isDifferentRecord = oldPayload.realStartTime !== currentStartTime || oldPayload.realEndTime !== currentEndTime;
      const oldDuration = oldPayload.realEndTime - oldPayload.realStartTime;
      return isDifferentRecord && oldDuration > 0 && oldDuration < secondsPerIndex && oldPayload.realEndTime <= currentStartTime;
    };
    
    // 按"x分钟/索引"来计算，求1天的索引数组
    // 如:
    // 1个索引代表1分钟，那么s的索引数组为 [0,1,2,...,1439]。
    // 1个索引代表3分钟，那么s的索引数组为 [0,1,2,...,479]。
    for (let i = 0; i < MINUTES_PER_DAY / minPerIndex; i++) {
      s.push({ value: 0 });
    }
    
    const dtoLength = dtos.length;
    for (let j = 0; j < dtoLength; j++) {
      // 取出一段
      const dto = dtos[j];
      
      // 2025-06-06 废弃: 将全部的 status 改用 kind 实现;
      // if (!isStatusIns(status)) {
      //   continue;
      // }
      if (!isHistoryInfusion(dto.kind) && !(dto.kind === HISTORY_KIND.PAUSE && j !== dtoLength - 1)) {
        // 只处理"胰岛素输注"和"非实时暂停(暂停不是最后一条记录)"的记录
        continue;
      }
      
      const startTime = dto.record_time;
      const endTime = dto.end_time;
      const runningTime = dto.seconds;
      const status = dto.status;
      const value = dto.value;
      const valuePlan = dto.value_plan || 0;
      const kind = dto.kind;
      const subKind = dto.sub_kind || 0;
      const pattern = dto.pattern || REQ_PATTERN.MANUAL;
      
      // 是否双波大剂量
      let isDoubleDose = false;
      // 是否双波大剂量中的立即量
      let isDoubleDoseImm = false;
      // 双波大剂量的计划总量
      let doubleTotalPlan = 0;
      // 双波大剂量的已输注总量
      let doubleTotalNow = 0;
      // 双波大剂量立即量的计划量
      let doubleImmPlan = 0;
      // 双波大剂量立即量的已输注量
      let doubleImmNow = 0;
      // 双波大剂量延长量的计划量
      let doubleDelayPlan = 0;
      // 双波大剂量延长量的已输注量
      let doubleDelayNow = 0;
      // 立即量开始时刻，时间戳，秒
      let immStartTime = 0;
      // 立即量实际持续时间，秒
      let immRunningTime = 0;
      // 延长量开始时刻，时间戳，秒
      let delayStartTime = 0;
      // 延长量实际持续时间，秒
      let delayRunningTime = 0;
      
      // 处理双波大剂量
      // 历史记录具备 value_plan 字段，实时消息不具备 value_plan 字段。
      if (dto.value_plan !== undefined) {
        // 历史记录: 通过有前后2条挨着的"立即量"和"延长量"记录来获取双波大剂量数据。by 李丹纯 2025-11-03 14:18:14。
        if (j > 0) {
          if (status === CARD_STATUS.RUNNING_DOSE_DELAY && dtos[j - 1].status === CARD_STATUS.RUNNING_DOSE_IMM) {
            // 当前历史记录项是延长量，且前面是立即量
            const imm = dtos[j - 1];
            const delay = dto;
            isDoubleDose = true;
            isDoubleDoseImm = false;
            // 已输注量
            doubleImmNow = r(imm.value || 0);
            doubleDelayNow = r(delay.value || 0);
            doubleTotalNow = r(doubleImmNow + doubleDelayNow);
            // 计划量
            doubleImmPlan = r(imm.value_plan || 0);
            doubleDelayPlan = r(delay.value_plan || 0);
            doubleTotalPlan = r(doubleImmPlan + doubleDelayPlan);
            // 时间
            immStartTime = imm.record_time;
            immRunningTime = imm.seconds;
            delayStartTime = delay.record_time;
            delayRunningTime = delay.seconds;
          }
        }
        if (j < dtoLength - 1) {
          if (status === CARD_STATUS.RUNNING_DOSE_IMM && dtos[j + 1].status === CARD_STATUS.RUNNING_DOSE_DELAY) {
            // 当前历史记录项是立即量，且后面是延长量。
            const imm = dto;
            const delay = dtos[j + 1];
            isDoubleDose = true;
            isDoubleDoseImm = true;
            // 已输注量
            doubleImmNow = r(imm.value || 0);
            doubleDelayNow = r(delay.value || 0);
            doubleTotalNow = r(doubleImmNow + doubleDelayNow);
            // 计划量
            doubleImmPlan = r(imm.value_plan || 0);
            if (delay.value_plan === undefined && bolusInfo) {
              // 延长量是实时消息，没有 value_plan，那么通过 PumpInfoBolusDTO 获取计划量。
              delay.value_plan = bolusInfo.large_delay;
            } else {
              // 延长量是历史记录，通过 value_plan 获取计划量。
              doubleDelayPlan = r(delay.value_plan || 0);
            }
            doubleTotalPlan = r(doubleImmPlan + doubleDelayPlan);
            // 时间
            immStartTime = imm.record_time;
            immRunningTime = imm.seconds;
            delayStartTime = delay.record_time;
            delayRunningTime = delay.seconds;
          }
        }
      } else if (bolusInfo) {
        // 实时消息: 通过 PumpInfoBolusDTO 结构获取双波大剂量数据。by 李丹纯 2025-11-06 18点左右 口述。
        isDoubleDose = isDose(dto.status) && bolusInfo.large_delay > 0;
        isDoubleDoseImm = isDoubleDose && isImmDoseStatus(dto.status);
        if (isDoubleDose) {
          // 已输注量
          doubleImmNow = r(bolusInfo.large_imm_now);
          doubleDelayNow = r(bolusInfo.large_delay_now);
          doubleTotalNow = r(doubleImmNow + doubleDelayNow);
          // 计划量
          doubleImmPlan = r(bolusInfo.large_imm);
          doubleDelayPlan = r(bolusInfo.large_delay);
          doubleTotalPlan = r(doubleImmPlan + doubleDelayPlan);
          // 时间
          if (isDoubleDoseImm) {
            // 立即量
            immStartTime = dto.record_time;
            immRunningTime = dto.seconds;
            // 未获取到延长量，需从实时运行的 PumpInfoBolusDTO 中获取
            delayStartTime = bolusInfo.large_delay_start_time;
            // 持续时间 = 现在时间 - 开始时间。by 李丹纯 2025-11-07 10:35:11
            delayRunningTime = Math.round(dayjs().unix() - delayStartTime);
          } else {
            // 延长量
            // 立即量从实时运行的 PumpInfoBolusDTO 中获取
            immStartTime = bolusInfo.large_imm_start_time;
            // 持续时间 = 现在时间 - 开始时间。by 李丹纯 2025-11-07 10:35:11
            immRunningTime = Math.round(dayjs().unix() - immStartTime);
            delayStartTime = dto.record_time;
            delayRunningTime = dto.seconds;
          }
        }
      }
      
      // 将 s 的 "0索引" 视为 ist，计算 dto.record_time 在s中的索引。
      // 如:
      // s 的索引数组为 [0,1,...,1439]，startMinuteIndex 为 168,280,1439 等。
      // s 的索引数组为 [0,1,...,479]， startMinuteIndex 为 68,479 等。
      let startMinuteIndex = 0;
      if (startTime < ist) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - ist) / (SECONDS_PER_MINUTE * minPerIndex));
      }
      
      // 计算 dto 在 s 中持续的索引数量。
      let runningIndexes = 0;
      if (isHistoryDose(kind)) {
        // 大剂量
        // 只受理大于 0U 的大剂量
        if (value > 0) {
          // 2025-10-31: 双波大剂量的延长量中，延长量需要用图片宽度来表达持续时间（seconds），除此种情况外，其他任何大剂量都无需表达持续时间。
          // 2024-08-08（已废弃）: 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
          if (isDoubleDose && isDelayDose(kind)) {
            // 延长量的持续时间是 dto.seconds。by 李丹纯 2025-11-03 14:36:25 至 李丹纯 2025-11-03 14:37:54。
            runningIndexes = getVisibleRunningIndexes(startTime, runningTime);
          }
          else {
            // 1分钟/索引: 用于院泵患者实时趋势图，固定 15 个索引;
            // 3分钟/索引: 用于宽屏，所以需要的索引数少一些;
            // 5分钟/索引: 用于窄屏(如手机)，所以需要的索引数多一些;
            runningIndexes = minPerIndex === 5 ? 4 : minPerIndex === 3 ? 2 : INS.DOSE.LAST_MINUTES;
          }
        }
      }
      else if (isHistoryBase(kind)) {
        // 基础率
        runningIndexes = getVisibleRunningIndexes(startTime, runningTime);
      }
      else {
        // 暂停
        // 暂停的结束时间戳等于下一条记录的起始时间戳（且恢复输注必然是基础率，所以下一条必是基础率。by 黄伦 2026/03/12）
        // 上面已确保暂停时 j+1 不越界，此处可放心使用 (见: dto.kind === HISTORY_KIND.PAUSE && j === dtoLength - 1)
        const nextRecord = dtos[j + 1];
        runningIndexes = getVisibleRunningIndexes(startTime, nextRecord.record_time - startTime);
      }
      
      // 填充每一个索引的数据
      for (let i = 0; i < runningIndexes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本索引的数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isHistoryDose(kind)) {
          // 本段大剂量记录的结束索引 (0 ~ runningIndexes-1)
          let endIndex = runningIndexes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningIndexes * (SECONDS_PER_MINUTE * minPerIndex)) >= XEndTime) {
            endIndex = Math.floor((XEndTime - startTime) / (SECONDS_PER_MINUTE * minPerIndex));
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= MINUTES_PER_DAY / minPerIndex || index < 0) {
          continue;
        }
        
        // 新数据填充逻辑: (大剂量立即量图形会持续一段固定时间，所以有可能造成旧数据覆盖新数据的情况)
        // 1. oldItem 未被填充过，直接填入新数据。
        // 2. oldItem 被前面的记录填充过了，仅以下情况需要覆盖 oldItem:
        //    2.1 新数据和前面记录是同类型。
        //    2.2 新数据是大剂量立即量。
        const oldItem = s[index];
        const oldItemKind = oldItem && oldItem.payload ? oldItem.payload.kind : null;
        if ((oldItemKind === null || oldItemKind === kind || isHistoryImmDose(kind)) && !shouldKeepOldShortBase(oldItem, oldItemKind, kind, startTime, endTime)) {
          const isRecordDose = isHistoryDose(kind);
          // rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0];
          // const status = status;
          // const realValue = isDoubleDose ? doubleTotalNow : value;
          const realValue = value;
          // const startTime = this._getFormatStartTime(startTime || 0);
          const startTimeText = this._getFormatStartTime(startTime || 0);
          const lastTime = this._getFormatLastTime(runningTime || 0);
          const isDoseMid = (isMid ? 1 : 0) === 1; // 是否是大剂量并且是该段中点
          
          let isWaiting = false; // 该数据点是否未到时间 (比如某个基础率是16:00输注, 但电脑上的时刻才15:30)
          // 1. 双波大剂量延长量的 seconds 的含义是"已输注时间"而非"计划输注时间"，所以是实时显示"已输注时间"，无需检查。(2025-10-31)
          // 2. 除双波大剂量延长量外的其他大剂量不会预设一段很长的时间，所以立即显示。(2025-09-23)
          // 综合以上两点，仅非大剂量则需要检查。
          if (!isRecordDose && ist + index * (SECONDS_PER_MINUTE * minPerIndex) > currentTime) {
            isWaiting = true;
          }
          
          // 2025-06-06 废弃: 将全部的 status 改用 kind 实现;
          // const ins = insMap.get(status);
          // const u = ins ? ins.UNIT : '';
          // const c = ins ? (isWaiting ? INS.DISABLED_COLOR : ins.COLOR) : INS.DASH_LINE_COLOR;
          // const t = ins ? ins.NAME : '';
          let u = '';
          let title = '';
          let c = INS.DASH_LINE_COLOR;
          const ins = this._getInsFromKind(kind, subKind as InsKindType);
          if (ins) {
            u = ins.UNIT;
            title = getHistoryTitle(kind, subKind as InsKindType, isDoubleDose);
            c = isWaiting ? INS.DISABLED_COLOR : ins.COLOR;
          }
          if (kind === HISTORY_KIND.PAUSE) {
            c = PAUSE_COLOR;
          }
          
          // 大剂量的 Y 值顶满 Y 轴
          // const valueY = isDose(status) ? INS.MAX_NORMAL : realValue;
          // 2024-09-24 周总建议: 大剂量不要过高。
          // 2026-03-12 增加暂停柱体，高度等于图谱底部开闭环模式柱体高度
          const valueY = kind === HISTORY_KIND.PAUSE ? MODE_VALUE_MERGE : isRecordDose ? INS.DOSE.SPECIAL_HEIGHT : realValue;
          // 椭圆宽度计算: 1.双波立即量的情况，需用总量做判断;  2.其余情况用"当前记录的输注剂量"判断即可。
          let circleWidth = (doubleTotalNow || realValue).toString().length > 4 ? 60 : 40;
          // 椭圆字号
          let fontSize = FONT_SIZE_12;
          // 椭圆持续的索引数（若使用索引计算宽度则赋值）
          let circleDurationIndex: number | undefined = undefined;
          // 屏幕宽度
          const sw = this._screenWidth;
          if (this._pxPerIndexInX) {
            // 计算椭圆宽度（非合并的大剂量, px）: 根据大剂量值以及渲染场景（院泵实时/患者信息/胰岛素用量）而定。
            const px = this._pxPerIndexInX;
            const count = (doubleTotalNow || realValue).toString().length;
            
            if (this._isRealTime) {
              circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, true);
            }
            else if (this._isMerge) {
              if (this._isReport) {
                // 胰岛素和血糖综合评估报告
                circleWidth = px * this._getBolusCircleIndexCountFromTextCountForReport(count, minPerIndex, REPORT_ID.MERGE);
              }
              else {
                if (sw < MIN_SCREEN_WIDTH.NEW_PAD) {
                  // 概况-输注实时,分析-每日综合 仅APP phone
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, true, true, true);
                  fontSize = FONT_SIZE_10;
                }
                else if (sw < MIN_SCREEN_WIDTH.PC) {
                  // 概况-输注实时,分析-每日综合 仅APP pad
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, true, true, false);
                  fontSize = FONT_SIZE_12;
                }
                else {
                  // 患者信息-实时数据图谱，数据分析-每日综合 仅PC
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, true);
                }
              }
            }
            else {
              // 其他情况，如: 胰岛素用量。
              if (this._isReport) {
                if (this._xWidth && this._xWidth > 600) {
                  // 胰岛素用量趋势图/胰岛素用量与血糖趋势图
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCountForReport(count, minPerIndex);
                }
                else {
                  // 胰岛素用量报告
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCountForReport(count, minPerIndex, REPORT_ID.INS);
                }
              }
              else {
                if (sw < MIN_SCREEN_WIDTH.NEW_PAD) {
                  // 分析-每日胰岛素 仅APP phone
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, false, true, true);
                  fontSize = FONT_SIZE_10;
                }
                else if (sw < MIN_SCREEN_WIDTH.PC) {
                  // 分析-每日胰岛素 仅APP pad
                  circleWidth = px * this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, false, true, false);
                  fontSize = FONT_SIZE_12;
                }
                else {
                  // 数据分析-胰岛素用量 仅PC
                  const durationIdx = this._getBolusCircleIndexCountFromTextCount(count, minPerIndex, false, false);
                  circleDurationIndex = durationIdx;
                  circleWidth = px * durationIdx;
                }
              }
            }
          }
          
          const doseHeight = isDoubleDose ? 23 : 20;
          const doseLineHeight = isDoubleDose ? 20 : 20;
          // 2025-06-06: 微型大剂量不展示数值
          // 2025-08-15: 延长大剂量不展示底部的椭圆
          const isLabelShowed = isClosedLoopDose(kind, subKind as InsKindType) || isDelayDose(kind) ? false : isDoseMid;
          // 获取大剂量底部的椭圆（区分普通大剂量和双波大剂量）
          const doseImage = isDoubleDose ? INS.DOUBLE_DOSE_IMAGE : INS.DOSE_IMAGE_BASE64;
          // 获取大剂量底部的字体颜色（判断是否"未完成计划的大剂量输注"）
          const dosePlan = dto.value_plan;
          // isDoubleDoseImm 已保证 j < dtoLength - 1，所以可使用 dtos[j+1]。
          const isUnFinished = isDoubleDoseImm
            ? dtos[j].value_plan !== undefined && dtos[j + 1].value_plan !== undefined && doubleTotalNow !== doubleTotalPlan
            : isRecordDose && dosePlan !== undefined && value !== dosePlan;
          const doseTextColor = isUnFinished ? COLOR_RED_0 : COLOR_BLACK_0;
          
          // encode
          const payload: PayloadType = {
            status: status,
            kind: kind,
            subKind: subKind as InsKindType,
            unit: u,
            title: title,
            startTime: startTimeText,
            lastTime: lastTime,
            realValue: realValue,
            isWaiting: isWaiting,
            planValue: dosePlan,
            realStartTime: startTime,
            realEndTime: endTime,
            xIndex: index,
            // 椭圆持续的索引数（可选）
            circleDurationIndex: circleDurationIndex,
            // 椭圆在 x 轴上的起止索引（可选）
            circleStartIndex: circleDurationIndex !== undefined ? Math.max(0, Math.floor(index - Math.floor(circleDurationIndex / 2))) : undefined,
            circleEndIndex: circleDurationIndex !== undefined ? Math.min(Math.floor(MINUTES_PER_DAY / minPerIndex) - 1, Math.floor(index + Math.floor(circleDurationIndex / 2))) : undefined,
            pattern: pattern,
          };
          if (isDoubleDose) {
            payload.isDoubleBolus = true;
            payload.totalValue = doubleTotalNow;
            payload.doubleBolus = {
              totalPlan: doubleTotalPlan,
              immPlan: doubleImmPlan,
              delayPlan: doubleDelayPlan,
              totalNow: doubleTotalNow,
              immNow: doubleImmNow,
              delayNow: doubleDelayNow,
              immStartTime: immStartTime,
              immRunningTime: immRunningTime,
              delayStartTime: delayStartTime,
              delayRunningTime: delayRunningTime,
            };
            // 被停止的大剂量: 双波大剂量
            // http://192.168.1.236:81/redmine/issues/7920
            if (j < dtoLength - 1 && doubleTotalNow < doubleTotalPlan) {
              // by hgc 2026/04/27
              // 1. 必须是历史记录, 非实时记录: j < dtoLength - 1;
              // 2. 停止时刻: 用 "开始时刻" + "持续时间";
              const doubleRunningTime = immRunningTime + delayRunningTime;
              const T = doubleRunningTime < 60 ? 'HH:mm:ss' : 'HH:mm';
              payload.doubleBolus.doubleStartAndStopText = `${dayjs.unix(immStartTime).format(T)}开始, ${dayjs.unix(immStartTime + doubleRunningTime).format(T)}停止`;
            }
          } else {
            // 被停止的大剂量: 普通大剂量
            // http://192.168.1.236:81/redmine/issues/7920
            if (j < dtoLength - 1 && kind === HISTORY_KIND.LARGE_DOSE && value < valuePlan) {
              // by hgc 2026/04/27
              // 1. 必须是历史记录, 非实时记录: j < dtoLength - 1;
              // 2. 停止时间用 record_time + seconds;
              const T = runningTime < 60 ? 'HH:mm:ss' : 'HH:mm';
              payload.startAndStopText = `${dayjs.unix(startTime).format(T)}开始, ${dayjs.unix(startTime + runningTime).format(T)}停止`;
            }
          }
          
          if (kind === HISTORY_KIND.LARGE_DOSE) {
            // 本段立即量在 X 轴的起始索引
            payload.bolusStartIndex = startMinuteIndex;
          }
          
          if (kind === HISTORY_KIND.PAUSE) {
            payload.reason = dto.value;
          }
          
          const d: SeriesDataItem = {
            value: valueY,
            itemStyle: { color: c },
            payload: payload,
            label: {
              // 柱状图下方椭圆样式（仅大剂量）
              show: isLabelShowed,
              // 鼠标移上去显示默认指针（禁用交互）
              silent: true,
              position: 'bottom',
              // 椭圆和柱体的垂直距离(px)
              distance: this._isInsPage ? 2 : 0,
              align: 'center',
              width: circleWidth,
              height: doseHeight,
              lineHeight: doseLineHeight,
              fontSize: fontSize,
              fontWeight: FONT_WEIGHT_BOLD,
              color: doseTextColor,
              backgroundColor: {
                image: doseImage,
              },
              formatter: (p: InsulinChartFormatParamType) => getBolusValueText(p, 3),
            },
          };
          
          if (this._isReport && d.payload && d.label) {
            const status = d.payload.status;
            if (isDose(status)) {
              d.value = DOSE.REPORT_VALUE_FOR_INS_DAILY;
              d.label.position = 'top';
              // 给宽度大的报告提供更大的字体
              d.label.fontSize = this._xWidth && this._xWidth > 600 ? FONT_SIZE_12 : FONT_SIZE_10;
              d.label.distance = 2;
              d.label.formatter = (p: InsulinChartFormatParamType) => getBolusValueText(p, 3);
              // @ts-ignore
              d.label.offset = [0, 0];
              d.label.color = COLOR_BLACK_0;
              d.label.fontWeight = FONT_WEIGHT_NORMAL;
              // @ts-ignore
              // d.label.backgroundColor = 'transparent';
              if (d.itemStyle) {
                d.itemStyle.color = isDelayDoseStatus(status) ? DOSE.COLOR_WEAK_DELAY : DOSE.COLOR_WEAK;
              }
            } else {
              // @ts-ignore
              d.label = { show: false };
              if (d.payload && isRate(d.payload.status)) {
                if (d.itemStyle) {
                  d.itemStyle.color = BASE.COLOR_WEAK;
                }
              }
            }
          }
          
          // 注意: 即将覆盖时，检查旧数据是否也是大剂量且 label.show 为 true，如果是，那么要重新设置旧大剂量的 label.show 为 true 的位置
          const oldS = s[index];
          if (oldS && oldS.payload && isHistoryImmDose(oldS.payload.kind) && oldS.label && oldS.label.show) {
            const runningIndexCount = minPerIndex === 5 ? 4 : minPerIndex === 3 ? 2 : INS.DOSE.LAST_MINUTES;
            const start = index - Math.floor(runningIndexCount / 2); // 旧大剂量起始索引
            let end = -1; // 未被覆盖的旧大剂量结束索引
            // 往前找到第一个未被覆盖的旧大剂量元素 (label.show 必定为 false)
            for (let oi = index - 1; oi >= start; oi--) {
              const T = s[oi];
              if (T && T.payload && isHistoryImmDose(T.payload.kind) && d.payload && d.payload.realStartTime !== T.payload.realStartTime) {
                end = oi;
              }
            }
            if (end > -1 && end >= start) {
              const M = s[start + Math.floor((end - start) / 2)];
              if (M && M.payload && isHistoryImmDose(M.payload.kind) && oldS.payload.realStartTime === M.payload.realStartTime && M.label && !M.label.show) {
                M.label.show = true;
              }
            }
          }
          
          s[index] = d;
        }
      }
    }
    
    const baseConfig =
      minPerIndex === 1
        ? {
          type: 'bar',
          barCategoryGap: '0', // 直方图间距为0
          barMinWidth: 0.31, // 柱条的最小宽度 (调了一个参数，解决直方图缺口问题)
          cursor: 'default',
          markLine: {
            silent: true,
            animation: false,
            label: {
              show: true,
              position: 'start',
              distance: X_OFFSET_1,
              color: CHART_CONFIG.TEXT_COLOR,
              fontSize: CHART_CONFIG.FONT_SIZE_XXS,
            },
            lineStyle: {
              width: MARK_LINE_WIDTH,
              color: CHART_CONFIG.AXIS_LINE_COLOR,
            },
            symbol: 'none',
            data: [{ yAxis: INS.MARK_VALUE_NORMAL_1 }, { yAxis: INS.MARK_VALUE_NORMAL_2 }, { yAxis: INS.MARK_VALUE_NORMAL_3 }],
          },
        }
        : getInsSeriesBaseConfig();
    
    // ================= 立即量椭圆重叠渲染算法 by cyy 2026-05-25 Start =================
    // 存储“合并后的椭圆”
    const overlayBolusSet: Set<BolusOverlayDataType> = new Set();
    // 存储"独立的立即量椭圆"
    const independentBoluses: Set<SeriesDataItem> = new Set();
    
    // 算法内部使用的椭圆结构，统一描述原始椭圆和合并后的椭圆。
    type BolusEllipse = {
      xAxis: number; // 椭圆中心点在 x 轴数组中的索引，用来定位 markPoint 或原始 label。
      circleStartIndex: number; // 椭圆显示范围覆盖到的最左侧索引，用来判断是否与左侧椭圆重叠。
      circleEndIndex: number; // 椭圆显示范围覆盖到的最右侧索引，用来判断是否与右侧椭圆重叠。
      startBolusIndex: number; // 当前椭圆包含的第一段立即量中心索引，用来计算合并后的覆盖范围。
      endBolusIndex: number; // 当前椭圆包含的最后一段立即量中心索引，用来计算合并后的覆盖范围。
      total: number; // 当前椭圆包含的立即量总剂量，合并时会累加。
      count: number; // 当前椭圆包含的立即量段数，合并后显示为括号中的数量。
      width: number; // 当前椭圆的实际像素宽度，最终传给 ECharts 的 rich label。
      hasPlanFailed: boolean; // 当前椭圆范围内是否存在未按计划完成的大剂量，用来决定文字是否标红。
      item?: SeriesDataItem; // 原始独立椭圆对应的 series 数据项，合并椭圆没有这个字段。
    };
    
    const pxPerIndex = this._pxPerIndexInX || 1; // 每个 x 轴索引对应的像素宽度；缺省用 1，避免没有宽度数据时除以空值。
    const isReport = this._isReport; // 缓存当前是否报告场景，后续多处需要根据报告场景调整位置和字号。
    // 根据当前渲染场景返回合并椭圆文字字号。
    const getOverlayFontSize = (): number => {
      if (isReport) {
        // 报告场景需要根据图谱宽度决定字号。宽报告用 12 号字，窄报告用 10 号字。
        return this._xWidth && this._xWidth > 600 ? FONT_SIZE_12 : FONT_SIZE_10;
      }
      // 非报告场景下，手机宽度用小字号，平板和 PC 用正常字号。
      return this._screenWidth < MIN_SCREEN_WIDTH.NEW_PAD ? FONT_SIZE_10 : FONT_SIZE_12;
    };
    // 判断某一段立即量是否存在实际输注量不等于计划量的情况
    const isPlanFailed = (payload: PayloadType): boolean => {
      if (payload.doubleBolus) {
        // 双波大剂量需要比较总已输注量和总计划量。双波总量不一致时，认为这段大剂量未按计划完成。
        return payload.doubleBolus.totalNow !== payload.doubleBolus.totalPlan;
      }
      if (payload.planValue !== undefined) {
        // 普通大剂量只有存在计划量时才需要比较。普通大剂量实际量不等于计划量时，认为未按计划完成。
        return payload.realValue !== payload.planValue;
      }
      // 没有计划量信息时不标记失败，保持原来的黑色文字。
      return false;
    };
    // 返回两个椭圆是否重叠
    const isOverlap = (left: BolusEllipse, right: BolusEllipse): boolean => {
      // 左椭圆右边界超过右椭圆左边界时，认为两个椭圆视觉上重叠。
      return left.circleEndIndex > right.circleStartIndex;
    };
    // 获取原始立即量椭圆的左边界索引
    const getCircleStartIndex = (item: SeriesDataItem, payload: PayloadType, xAxis: number): number => {
      if (payload.circleStartIndex !== undefined) {
        // 如果创建 payload 时已经算过索引边界，优先复用它。返回预计算的左边界，避免重复用像素宽度反推。
        return payload.circleStartIndex;
      }
      // 没有预计算索引时，用中心点减去半个椭圆宽度换算出的索引数
      return Math.floor(xAxis - (item.label as SeriesDataItemLabel).width / pxPerIndex / 2);
    };
    // 获取原始立即量椭圆的右边界索引
    const getCircleEndIndex = (item: SeriesDataItem, payload: PayloadType, xAxis: number): number => {
      if (payload.circleEndIndex !== undefined) {
        // 如果创建 payload 时已经算过索引边界，优先复用它。返回预计算的右边界，避免重复用像素宽度反推。
        return payload.circleEndIndex;
      }
      // 没有预计算值时，用中心点加上半个椭圆宽度换算出的索引数。
      return Math.floor(xAxis + (item.label as SeriesDataItemLabel).width / pxPerIndex / 2);
    };
    // 合并两个已经确认重叠的椭圆，并返回新的合并椭圆。
    const mergeBolusEllipse = (left: BolusEllipse, right: BolusEllipse): BolusEllipse => {
      // 合并椭圆包含的第一段立即量，取左右两边更靠前的中心索引。
      const startBolusIndex = Math.min(left.startBolusIndex, right.startBolusIndex);
      // 合并椭圆包含的最后一段立即量，取左右两边更靠后的中心索引。
      const endBolusIndex = Math.max(left.endBolusIndex, right.endBolusIndex);
      // 合并后的总量等于两个椭圆的总量之和。
      const total = left.total + right.total;
      // 合并后的数量等于两个椭圆内立即量段数之和。
      const count = left.count + right.count;
      // 合并椭圆展示文本，格式为“总量(段数)”。
      const text = `${realRoundTo3Digit(total)}(${count})`;
      
      // 根据文本长度换算文字完整展示所需的最小索引跨度。
      let textIndexCount = this._getBolusCircleIndexCountFromTextCount(text.length, minPerIndex, this._isRealTime, this._isMerge);
      if (this._isReport) {
        const id = this._isMerge ? REPORT_ID.MERGE : this._xWidth && this._xWidth > 600 ? undefined : REPORT_ID.INS;
        textIndexCount = this._getBolusCircleIndexCountFromTextCountForReport(text.length, minPerIndex, id);
      }
      else if (this._screenWidth < MIN_SCREEN_WIDTH.NEW_PAD) {
        // 概况-输注实时,分析-每日综合 phone
        textIndexCount = this._getBolusCircleIndexCountFromTextCount(text.length, minPerIndex, false, this._isMerge, true, true);
      }
      else if (this._screenWidth >= MIN_SCREEN_WIDTH.NEW_PAD && this._screenWidth < MIN_SCREEN_WIDTH.PC) {
        // 概况-输注实时,分析-每日综合 pad
        textIndexCount = this._getBolusCircleIndexCountFromTextCount(text.length, minPerIndex, false, this._isMerge, true, false);
      }
      
      // 计算合并椭圆所需索引数，需同时满足: 1.覆盖首尾立即量; 2.容纳文本宽度。
      const runningIndexCount = Math.max(textIndexCount, endBolusIndex - startBolusIndex + 1);
      // 合并椭圆中心放在首尾立即量中心索引的中点。
      const xAxis = Math.floor(startBolusIndex + (endBolusIndex - startBolusIndex) / 2);
      // 用合并后的总跨度计算半宽索引，便于得到左右边界。
      const halfIndexCount = Math.floor(runningIndexCount / 2);
      // 返回新的合并椭圆对象，供后续继续参与重叠判断。
      return {
        // 写入合并椭圆中心索引。
        xAxis,
        // 写入合并椭圆的左边界索引。
        circleStartIndex: xAxis - halfIndexCount,
        // 写入合并椭圆的右边界索引。
        circleEndIndex: xAxis + halfIndexCount,
        // 写入合并椭圆包含的第一段立即量中心索引。
        startBolusIndex,
        // 写入合并椭圆包含的最后一段立即量中心索引。
        endBolusIndex,
        // 写入合并后的总剂量。
        total,
        // 写入合并后的立即量段数。
        count,
        // 把合并跨度从索引数转换成像素宽度。
        width: runningIndexCount * pxPerIndex,
        // 只要左右任意一边存在计划失败，合并椭圆就需要标红。
        hasPlanFailed: left.hasPlanFailed || right.hasPlanFailed,
      };
    };
    // 把算法得到的合并椭圆结构转换成 ECharts markPoint 可消费的数据结构。
    const getOverlayBolus = (bolus: BolusEllipse): BolusOverlayDataType => {
      // 生成 markPoint label 中展示的“总量(段数)”文本。
      const text = `${realRoundTo3Digit(bolus.total)}(${bolus.count})`;
      // 返回 markPoint data 项。
      return {
        // markPoint 的水平位置放在合并椭圆中心索引。
        xAxis: bolus.xAxis,
        // 报告场景把椭圆放在 y=3 附近，普通场景放在底部 y=0。
        yAxis: isReport ? 3 : 0,
        // 保留合并椭圆左边界，便于后续如果需要继续判断重叠。
        circleStartIndex: bolus.circleStartIndex,
        // 保留合并椭圆右边界，便于后续如果需要继续判断重叠。
        circleEndIndex: bolus.circleEndIndex,
        // 使用矩形 symbol 承载 label，实际可见的是 label 背景图。
        symbol: 'rect',
        // symbol 本身不占可见尺寸，避免额外图形干扰。
        symbolSize: 0,
        // symbol 不做额外偏移，位置完全由 xAxis/yAxis 和 label 决定。
        symbolOffset: [0, 0],
        // 配置合并椭圆的可见标签。
        label: {
          // 合并椭圆必须显示。
          show: true,
          // 禁用 label 鼠标交互，避免影响图谱 tooltip/hover。
          silent: true,
          // 报告场景显示在柱体上方，普通场景显示在底部。
          position: isReport ? 'top' : 'bottom',
          // 报告场景给 2px 间距 (趋势图报告给 12px)，普通场景贴近底部。
          distance: isReport ? (this._xWidth && this._xWidth > 600) ? 12 : 2 : 0,
          // 文本和背景椭圆相对中心对齐。
          align: 'center',
          // 用 rich text 的 bolus 样式渲染合并后的文本。
          formatter: `{bolus|${text}}`,
          // 定义 formatter 中 bolus 片段的样式。
          rich: {
            // bolus rich 样式对应真正可见的椭圆外观。
            bolus: {
              // 设置椭圆宽度，保证能覆盖合并范围并容纳文本。
              width: bolus.width,
              // 设置椭圆高度，与普通大剂量椭圆高度保持一致。
              height: 20,
              // 行高等于高度，让文本垂直居中。
              lineHeight: 20,
              // 根据场景选择合并椭圆字号。
              fontSize: getOverlayFontSize(),
              // 报告场景使用常规字重，普通图谱使用加粗字重。
              fontWeight: isReport ? 400 : 700,
              // 未按计划完成时文字标红，否则使用黑色。
              color: bolus.hasPlanFailed ? COLOR_RED_0 : COLOR_BLACK_0,
              // 配置 rich label 的背景图。
              backgroundColor: {
                // 使用普通大剂量椭圆图片作为合并椭圆背景。
                image: INS.DOSE_IMAGE_BASE64,
              }
            }
          }
        }
      };
    };
    
    // 将所有 series 的立即量中心椭圆转为算法所需结构，并按 x 轴索引升序收集。
    const bolusEllipses: Array<BolusEllipse> = [];
    // 遍历整条 series 数据，寻找当前仍显示 label 的立即量中心点。
    for (let i = 0, sLen = s.length; i < sLen; i++) {
      // 取出当前索引对应的 series 数据项。
      const item = s[i];
      // 取出自定义 payload，后续用来判断类型和读取剂量数据。
      const payload = item.payload;
      // 取出 label，后续用来判断当前椭圆是否可见以及读取宽度。
      const label = item.label;
      if (!payload || !isHistoryImmDose(payload.kind) || !label || !label.show || !label.width || payload.realValue === 0) {
        // 1. 非立即量椭圆中心点直接跳过;
        // 2. 0U 的立即量不绘制在图谱上，所以不受理;
        continue;
      }
      // 原始立即量椭圆中心索引。
      const xAxis = payload.xIndex;
      // 先隐藏所有原始立即量椭圆，后面只恢复显示不重叠的独立椭圆。
      label.show = false;
      // 把原始立即量转换成算法所需椭圆结构，加入待合并列表。
      bolusEllipses.push({
        // 写入原始椭圆中心索引。
        xAxis,
        // 写入原始椭圆左边界索引。
        circleStartIndex: getCircleStartIndex(item, payload, xAxis),
        // 写入原始椭圆右边界索引。
        circleEndIndex: getCircleEndIndex(item, payload, xAxis),
        // 单个原始椭圆的首立即量索引就是自身中心索引。
        startBolusIndex: xAxis,
        // 单个原始椭圆的尾立即量索引就是自身中心索引。
        endBolusIndex: xAxis,
        // 单个原始椭圆的剂量优先用双波总量，其次用常规立即量，缺省为 0。
        total: payload.totalValue || payload.realValue || 0,
        // 单个原始椭圆只代表一段立即量。
        count: 1,
        // 单个原始椭圆宽度沿用当前 label 宽度。
        width: label.width,
        // 记录这段立即量是否未按计划完成。
        hasPlanFailed: isPlanFailed(payload),
        // 保留原始 series 数据项，便于确认独立后恢复 label.show。
        item,
      });
    }
    
    // 已经处理过的、不需要再向左回看的椭圆（使用栈保存）
    const ellipseStack: Array<BolusEllipse> = [];
    // 按从左到右的顺序处理所有 series 中的立即量椭圆。
    for (let i = 0, bLen = bolusEllipses.length; i < bLen; i++) {
      // 当前待处理椭圆，可能是原始的立即量椭圆，也可能在后面变成合并椭圆。
      let currentBolus = bolusEllipses[i];
      // 取栈顶椭圆，它是当前椭圆左侧最近的已处理椭圆。
      let prevBolus = ellipseStack[ellipseStack.length - 1];
      // 如果左侧没有椭圆，或左侧最近椭圆和当前椭圆不重叠，就不需要合并。
      if (!prevBolus || !isOverlap(prevBolus, currentBolus)) {
        // 当前椭圆作为"独立候选"或"后续合并候选"入栈。
        ellipseStack.push(currentBolus);
        // 当前椭圆处理完毕，继续处理下一个 series 中的立即量椭圆。
        continue;
      }
      // 当前椭圆与左侧栈顶重叠，弹出栈顶并合并成新的当前椭圆。
      currentBolus = mergeBolusEllipse(ellipseStack.pop() as BolusEllipse, currentBolus);
      // 合并后的椭圆可能变宽，需要继续向左检查是否又压到了更早的椭圆。
      while (ellipseStack.length > 0) {
        // 重新读取合并后当前椭圆左侧最近的栈顶椭圆。
        prevBolus = ellipseStack[ellipseStack.length - 1];
        if (!isOverlap(prevBolus, currentBolus)) {
          // 如果新的左邻椭圆不再与当前合并椭圆重叠，就停止向左合并。
          break;
        }
        // 左邻仍然重叠，继续弹出并合并到当前椭圆中。
        currentBolus = mergeBolusEllipse(ellipseStack.pop() as BolusEllipse, currentBolus);
      }
      // 向左回溯合并循环结束。
      // 把最终合并后的当前椭圆放回栈中，等待后续右侧椭圆继续检查。
      ellipseStack.push(currentBolus);
    }
    
    // 遍历栈中最终得到的椭圆结果（已合并椭圆、独立的立即量椭圆）
    for (const bolus of ellipseStack) {
      // 只包含一段立即量且仍有原始数据项的椭圆，说明它没有参与合并。
      if (bolus.count === 1 && bolus.item) {
        // 记录为独立立即量椭圆，方便调试或后续扩展使用。
        independentBoluses.add(bolus.item);
      }
      else {
        // 包含多段立即量的椭圆是合并椭圆，转换成 markPoint 所需结构，后续会单独渲染。
        overlayBolusSet.add(getOverlayBolus(bolus));
      }
    }
    
    // 恢复所有独立立即量椭圆显示
    for (const bolus of independentBoluses) {
      if (bolus.label) {
        bolus.label.show = true;
      }
    }
    // ================= 立即量椭圆重叠渲染算法 End ===================================
    
    return {
      ...baseConfig,
      markPoint: {
        animation: false,
        tooltip: {
          // 禁用 markPoint 的提示框
          show: false,
        },
        emphasis: {
          // 禁用高亮样式
          disabled: true,
        },
        data: Array.from(overlayBolusSet),
      },
      tooltip: {
        trigger: 'item',
        formatter: (p: InsulinChartFormatParamType) => this._decode(p),
      },
      data: s,
    } as any;
    
  }
  
  // 获取浮窗中的HTML模板
  public static getHtml(p: InsPayloadType): string {
    const isPC = useScreenStore().isPC;
    
    // 字号见 src/modules/merge/util/merge.util.ts: getMergeDecodeHtml
    const fwPC = FONT_WEIGHT_BOLD;
    
    const sfsAPP = '12px';
    const fwAPP = FONT_WEIGHT_BOLD;
    
    const isBolus = isHistoryDose(p.kind);
    const isTinyBolus = isHistoryTinyDose(p.kind, p.subKind);
    const timeColor = p.isWaiting ? COLOR_BLACK_0 : COLOR_GRAY_2;
    
    // 标题
    const isClosedLoopRate = isClosedLoopBase(p.kind, p.subKind);
    const rateText = getTitleByHistoryKind(p.kind, p.subKind);
    // 数值
    const valueText = isBolus ? (p.total > 0 ? `${p.value}/${p.total}U` : `${p.value}U`) : `${p.value}U/h`;
    // 起止时间段
    const getTimeText = (time: number) => dayjs.unix(time).format('HH:mm');
    const startTimeText = getTimeText(p.startTime);
    const endTimeText = getTimeText(p.endTime);
    const timeText = `${startTimeText}-${endTimeText}`;
    
    let html: string;
    if (isPC) {
      if (p.isDoubleBolus && p.doubleBolus) {
        // 双波大剂量
        const data = p.doubleBolus;
        // 数据行
        const totalLine = `<div style="font-weight: ${fwPC};">双波大剂量: <span>${data.totalNow}</span>/${data.totalPlan}U</div>`;
        const detailLine = `<div>
          <span style="margin-right: 8px;">立即量: <span>${data.immNow}</span>/${data.immPlan}U</span>
          <span>延长量: <span>${data.delayNow}</span>/${data.delayPlan}U</span>
        </div>`;
        
        // 时间行，区分"正常运行"和"中途被停止", 正常如:"08:00-10:00", 中途被停止如:"08:12开始,08:30停止"
        let timeLine: string;
        if (data.doubleStartAndStopText) {
          timeLine = `<div style="color: ${COLOR_GRAY_2};">${data.doubleStartAndStopText}</div>`;
        } else {
          timeLine = `<div style="color: ${timeColor};">${getChartTimeText(data.immStartTime)}-${getChartTimeText(data.delayStartTime + data.delayRunningTime)}</div>`;
        }
        
        // 等待行，未到当前时刻时显示，如: '已预设，未到输注时间'
        const waitingLine = p.isWaiting ? '<div>已预设，未到输注时间</div>' : '';
        html = `<div style="padding-top: 8px;">${totalLine + detailLine + timeLine + waitingLine}</div>`;
      } else {
        // 普通大剂量、基础率
        // 数据行，如 '大剂量: 8.555/10U'、'基础率: 0.65U/h'。
        const mainText = `<span>${isClosedLoopRate ? '闭环基础率' : rateText + ': ' + valueText}</span>`;
        const kindText = isTinyBolus ? '<span>(微型)</span>' : '';
        const mainLine = `<div style="font-weight: ${fwPC};">${mainText + kindText}</div>`;
        
        // 时间行，区分"闭环基础率", "正常运行"和"中途被停止", 闭环基础率隐藏信息, 正常如:"08:00-10:00", 中途被停止如:"08:12开始,08:30停止"
        let timeLine: string;
        if (isClosedLoopRate) {
          timeLine = '';
        } else if (p.startAndStopText) {
          timeLine = `<div style="color: ${COLOR_GRAY_2};">${p.startAndStopText}</div>`;
        } else {
          timeLine = `<div style="color: ${timeColor};">${timeText}</div>`;
        }
        
        // 等待行，未到当前时刻时显示，如: '已预设，未到输注时间'
        const waitingLine = p.isWaiting ? '<div>已预设，未到输注时间</div>' : '';
        html = `<div style="padding-top: 8px;">${mainLine + timeLine + waitingLine}</div>`;
      }
    } else {
      // APP端
      if (p.isDoubleBolus && p.doubleBolus) {
        // 双波大剂量
        const data = p.doubleBolus;
        // 数据行
        const totalLine = `<div style="font-weight: ${fwAPP};">双波大剂量: <span>${data.totalNow}</span>/${data.totalPlan}U</div>`;
        const detailLine = `<div style="font-size: ${sfsAPP};">立即量: <span>${data.immNow}</span>/${data.immPlan}U</div>
          <div style="font-size: ${sfsAPP};">延长量: <span>${data.delayNow}</span>/${data.delayPlan}U</div>`;
        
        // 时间行，区分"正常运行"和"中途被停止", 正常如:"08:00-10:00", 中途被停止如:"08:12开始,08:30停止"
        let timeLine: string;
        if (data.doubleStartAndStopText) {
          timeLine = `<div style="color: ${COLOR_GRAY_2};">${data.doubleStartAndStopText}</div>`;
        } else {
          timeLine = `<div style="color: ${timeColor};">${getChartTimeText(data.immStartTime)}-${getChartTimeText(data.delayStartTime + data.delayRunningTime)}</div>`;
        }
        
        // 等待行，未到当前时刻时显示，如: '已预设，未到输注时间'
        const waitingLine = p.isWaiting ? '<div>已预设，未到输注时间</div>' : '';
        html = `<div style="padding-top: 8px;">${totalLine + detailLine + timeLine + waitingLine}</div>`;
      } else {
        // 普通大剂量、基础率
        // 数据行，如 '大剂量: 8.555/10U'、'基础率: 0.65U/h'。
        const mainText = `<span>${isClosedLoopRate ? '闭环基础率' : rateText + ': ' + valueText}</span>`;
        const kindText = isTinyBolus ? '<span>(微型)</span>' : '';
        const mainLine = `<div style="font-weight: ${fwAPP};">${mainText + kindText}</div>`;
        
        // 时间行，区分"闭环基础率", "正常运行"和"中途被停止", 闭环基础率隐藏信息, 正常如:"08:00-10:00", 中途被停止如:"08:12开始,08:30停止"
        let timeLine: string;
        if (isClosedLoopRate) {
          timeLine = '';
        } else if (p.startAndStopText) {
          timeLine = `<div style="color: ${COLOR_GRAY_2};">${p.startAndStopText}</div>`;
        } else {
          timeLine = `<div style="color: ${timeColor};">${timeText}</div>`;
        }
        
        // 等待行，未到当前时刻时显示，如: '已预设，未到输注时间'
        const waitingLine = p.isWaiting ? '<div>已预设，未到输注时间</div>' : '';
        html = `<div style="padding-top: 8px;">${mainLine + timeLine + waitingLine}</div>`;
      }
    }
    
    return html;
  }
  
  // 获取暂停的HTML模板
  public static getPauseHtml(p: PausePayload): string {
    return `<div style="padding-top: 8px;">输注暂停${p.reasonText ? `(${p.reasonText})` : ''}</div>`;
  }
  
  private _getFormatStartTime(time: number): string {
    const f = fillZero;
    const date = new Date(time * MS_PER_SECOND);
    return `起始 ${f(date.getMonth() + 1)}-${f(date.getDate())} ${f(date.getHours())}:${f(date.getMinutes())}`;
  }
  
  private _getFormatLastTime(time: number): string {
    return `持续 ${formatTime(time)}`;
  }
  
  private _getInsFromKind(kind: HISTORY_KIND, subKind: InsKindType): any {
    let ins: any;
    if (kind === HISTORY_KIND.BASE) {
      ins = subKind === BASE_KIND.CLOSE_UP ? CARD_CHART.INSULIN.LINE_101_CLOSE_UP : CARD_CHART.INSULIN.LINE_101;
    } else if (kind === HISTORY_KIND.TEMP_BASE) {
      ins = CARD_CHART.INSULIN.LINE_102;
    } else if (isHistoryDose(kind)) {
      // 大剂量
      if (isDelayDose(kind)) {
        // 延长大剂量
        ins = CARD_CHART.INSULIN.LINE_104;
      } else {
        // 常规大剂量
        if (isClosedLoopDose(kind, subKind)) {
          // 微型大剂量
          ins = CARD_CHART.INSULIN.LINE_103_TINY;
        } else {
          // 非微型大剂量 (餐时/临时)
          ins = CARD_CHART.INSULIN.LINE_103;
        }
      }
    }
    return ins;
  }
  
  // minutesPerIndex: 每个索引代表多少分钟
  private _encode(data: RATE_DATA, minutesPerIndex: number): Array<InsulinChartYDataType> {
    if (!data || !data.length) {
      return [];
    }
    
    const currentTime = webTimeToServerTime(new Date().getTime()); // 电脑上当前时刻的时间戳，单位秒;
    return data.map((d, i) => {
      const status = d[0];
      const realValue = d[1];
      const realStartTime = d[2] || 0;
      const realEndTime = d[3] || 0;
      const startTime = this._getFormatStartTime(realStartTime);
      const lastTime = this._getFormatLastTime(realEndTime);
      const isDoseMid = d[4] === 1; // 是否是大剂量并且是该段中点
      const kind = d[KIND_INDEX];
      const subKind = d[6];
      
      const ist = this._startTime;
      const index = i;
      let isWaiting = false; // 该数据点是否未到时间 (比如某个基础率是16:00输注, 但电脑上的时刻才15:30)
      // 大剂量不会预设一段很长的时间，所以立即显示，非大剂量则需要检查。2025-09-23
      if (!isDose(status) && ist + index * minutesPerIndex * SECONDS_PER_MINUTE > currentTime) {
        isWaiting = true;
      }
      
      let u = '';
      let title = '';
      let c = INS.DASH_LINE_COLOR;
      const ins = this._getInsFromKind(kind, subKind);
      
      if (ins) {
        u = ins.UNIT;
        title = ins.NAME;
        c = isWaiting ? INS.DISABLED_COLOR : ins.COLOR;
      }
      
      // 2025-06-06 废弃: 将全部的 status 改用 kind 实现;
      // const ins = insMap.get(status);
      // const u = ins ? ins.UNIT : '';
      // const t = ins ? ins.NAME : '';
      // const c = ins ? (isWaiting ? INS.DISABLED_COLOR : ins.COLOR) : INS.DASH_LINE_COLOR;
      
      // 大剂量的 Y 值顶满 Y 轴
      // const valueY = isDose(status) ? INS.MAX_NORMAL : realValue;
      // 2024-09-24 周总建议: 大剂量不要过高。
      const valueY = isHistoryDose(kind) ? INS.DOSE.SPECIAL_HEIGHT : realValue;
      const doseWidth = realValue.toString().length > 4 ? 60 : 40;
      
      // 2025-06-06: 微型大剂量不展示数值
      // 2025-08-15: 延长大剂量不展示底部的椭圆
      const isLabelShowed = isClosedLoopDose(kind, subKind) || isDelayDose(kind) ? false : isDoseMid;
      
      return {
        value: valueY,
        itemStyle: { color: c },
        payload: {
          status: status,
          kind: kind,
          subKind: subKind,
          unit: u,
          title: title,
          startTime: startTime,
          lastTime: lastTime,
          realValue: realValue,
          isWaiting: isWaiting,
          realStartTime: realStartTime,
          realEndTime: realEndTime,
          xIndex: i,
        },
        label: {
          // 常规大剂量/双波立即大剂量 下方椭圆专属样式
          show: isLabelShowed,
          // 鼠标移上去显示默认指针（禁用交互）
          slient: true,
          position: 'bottom',
          offset: [0, -5],
          align: 'center',
          formatter: (p: InsulinChartFormatParamType) => `{dose|${roundTo(p.data.payload.realValue, DOSE.VALUE_DIGIT)}}`,
          rich: {
            dose: {
              width: doseWidth,
              height: 20,
              fontSize: 12,
              color: 'rgb(0,0,0)',
              backgroundColor: {
                image: INS.DOSE_IMAGE_BASE64,
              },
            },
          },
        },
      };
    });
  }
  
  private _decode(p: InsulinChartFormatParamType): string {
    const payload = p.data.payload;
    const kind = payload.kind;
    const subKind = payload.subKind;
    
    if (kind === HISTORY_KIND.PAUSE) {
      return getDecodeHtml(PAUSE_COLOR, PAUSE_TEXT_COLOR, '', '输注暂停', SelectItemVO.getText(PUMP_STOP_ITEM_MAP, payload.reason as PUMP_STOP), '', '');
    } else {
      // 2025-06-06 废弃: 将全部的 status 改用 kind 实现;
      // const ins = insMap.get(payload.status);
      const ins = this._getInsFromKind(kind, subKind);
      const bgColor = ins ? (payload.isWaiting ? INS.DISABLED_COLOR : ins.COLOR) : INS.DASH_LINE_COLOR;
      const color = ins ? (payload.isWaiting ? INS.DISABLED_TEXT_COLOR : ins.TEXT_COLOR) : CHART_CONFIG.TEXT_COLOR;
      // const waitingText = isRate(payload.status) && payload.isWaiting ? '已预设，未到输注时间' : '';
      const waitingText = isHistoryBase(kind) && payload.isWaiting ? '已预设，未到输注时间' : '';
      
      // 2025-06-07: 隐藏闭环泵机密数据;
      const isTopSecret = isClosedLoopTopSecret(kind, subKind);
      
      // 输注剂量的情况 文本，如 '0.375/9U'
      // let valueText = isTopSecret ? '' : (payload.realValue + ' ' + payload.unit);
      let valueText = '';
      if (isTopSecret) {
        valueText = '';
      } else if (payload.planValue) {
        valueText = `${payload.realValue}/${payload.planValue}U`;
      } else {
        valueText = payload.realValue + ' ' + payload.unit;
      }
      
      const startTimeText = isTopSecret ? '' : payload.startTime;
      const lastTimeText = isTopSecret ? '' : payload.lastTime;
      
      if (payload.doubleBolus) {
        return getDoubleDecodeHtml(payload.doubleBolus);
      } else {
        return getDecodeHtml(bgColor, color, valueText, payload.title, startTimeText, lastTimeText, waitingText);
      }
    }
  }
  
  // 每分钟一个点
  public get series() {
    // return this._getSeries(this._rateData)[0];
    return this._series;
  }
  
  private _getSeries(data: RATE_DATA, minutesPerIndex: number) {
    return [
      {
        ...getInsSeriesBaseConfig(),
        tooltip: {
          trigger: 'item',
          formatter: (p: InsulinChartFormatParamType) => this._decode(p),
        },
        data: this._encode(data, minutesPerIndex),
      },
    ];
  }
  
  public static hasTinyData(records: Array<ChartRecordDTO>): boolean {
    return !!records.filter((data) => isChart(data.status)).find((data) => data.value < INS.VALUE_TINY);
  }
  
  public addLabelToConfig(config: any, text: string, width: number, zIndex: number) {
    config.graphic = [
      {
        type: 'group',
        right: 10,
        top: 5,
        children: [
          {
            type: 'rect',
            cursor: 'default',
            z: zIndex,
            left: 'center',
            top: 'middle',
            shape: {
              width: width,
              height: 24,
            },
            style: {
              fill: 'rgb(58,68,77,0.5)',
            },
          },
          {
            type: 'text',
            cursor: 'default',
            z: zIndex,
            left: 'center',
            top: 'middle',
            style: {
              fill: 'rgb(255,255,255)',
              width: width,
              overflow: 'break',
              text: text,
              font: '12px Microsoft YaHei',
            },
          },
        ],
      },
    ];
  }
  
  private _getConfig(data: RATE_DATA, minutesPerIndex: number) {
    const startTime = this._startTime;
    const series = this._getSeries(data, minutesPerIndex);
    
    const yMax = INS.MAX_NORMAL;
    
    return {
      grid: {
        left: 40,
        right: 20,
        top: 8,
        bottom: 22,
      },
      animation: false,
      backgroundColor: 'transparent',
      tooltip: {
        show: true,
        trigger: 'item',
        extraCssText: 'padding: 0 !important;',
        position: function (point: Array<number>, _, dom: Element, __, size) {
          // point: 鼠标位置 [x,y]。 左上角点是 [0,0]。
          // dom: 鼠标悬停显示的 dom 结点。
          // size.viewSize: canvas容器尺寸，如 [x,y]。
          
          const dw = dom ? dom.clientWidth || 0 : 0;
          const dh = dom ? dom.clientHeight || 0 : 0;
          const cw = size.viewSize[0] || 0;
          
          const x = point[0];
          const y = point[1];
          
          // 默认top在点的上方，left居中。
          const DEFAULT_Y = y - dh - 10;
          const DEFAULT_X = x - dw / 2;
          
          let top = DEFAULT_Y;
          if (DEFAULT_Y < 0) {
            top = y + 10;
          }
          
          let left = DEFAULT_X;
          if (DEFAULT_X < 0) {
            left = x;
          } else if (x + dw / 2 > cw) {
            left = x - dw;
          }
          
          return { left: left, top: top };
        },
      },
      xAxis: {
        type: 'category',
        data: CHART_CONFIG.X_DATA,
        axisLabel: {
          show: false, // 胰岛素图形不展示 X 轴刻度
          color: CHART_CONFIG.TEXT_COLOR,
          fontSize: CHART_CONFIG.FONT_SIZE_XXS,
          interval: MINUTES_PER_HOUR * 4 - ONE_MINUTE,
          formatter: getXAxisLabelFormatter(true, startTime),
        },
        axisTick: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      yAxis: {
        type: 'value',
        min: INS.MIN,
        max: yMax,
        splitLine: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      series: series,
    };
  }
  
  public get configSP() {
    const startTime = this._startTime;
    const series = this._series;
    const yMax = INS.MAX_NORMAL;
    return {
      grid: {
        left: 40,
        right: 20,
        top: 8,
        bottom: 22,
      },
      animation: false,
      backgroundColor: 'transparent',
      tooltip: {
        show: true,
        trigger: 'item',
        extraCssText: 'padding: 0 !important;',
        position: function (point: Array<number>, _, dom: Element, __, size) {
          // point: 鼠标位置 [x,y]。 左上角点是 [0,0]。
          // dom: 鼠标悬停显示的 dom 结点。
          // size.viewSize: canvas容器尺寸，如 [x,y]。
          
          const dw = dom ? dom.clientWidth || 0 : 0;
          const dh = dom ? dom.clientHeight || 0 : 0;
          const cw = size.viewSize[0] || 0;
          
          const x = point[0];
          const y = point[1];
          
          // 默认top在点的上方，left居中。
          const DEFAULT_Y = y - dh - 10;
          const DEFAULT_X = x - dw / 2;
          
          let top = DEFAULT_Y;
          if (DEFAULT_Y < 0) {
            top = y + 10;
          }
          
          let left = DEFAULT_X;
          if (DEFAULT_X < 0) {
            left = x;
          } else if (x + dw / 2 > cw) {
            left = x - dw;
          }
          
          return { left: left, top: top };
        },
      },
      xAxis: {
        type: 'category',
        data: CHART_CONFIG.X_DATA,
        axisLabel: {
          show: false, // 胰岛素图形不展示 X 轴刻度
          color: CHART_CONFIG.TEXT_COLOR,
          fontSize: CHART_CONFIG.FONT_SIZE_XXS,
          interval: MINUTES_PER_HOUR * 4 - ONE_MINUTE,
          formatter: getXAxisLabelFormatter(true, startTime),
        },
        axisTick: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      yAxis: {
        type: 'value',
        min: INS.MIN,
        max: yMax,
        splitLine: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      series: series,
    };
  }
  
  public get config5() {
    return this._getConfig(this._rateData5Min, 5);
  }
  
  public get config3() {
    const startTime = this._startTime;
    const series = this._series;
    const yMax = INS.MAX_NORMAL;
    return {
      grid: {
        left: 40,
        right: 20,
        top: 8,
        bottom: 22,
      },
      animation: false,
      backgroundColor: 'transparent',
      tooltip: {
        show: true,
        trigger: 'item',
        extraCssText: 'padding: 0 !important;',
        position: function (point: Array<number>, _, dom: Element, __, size) {
          // point: 鼠标位置 [x,y]。 左上角点是 [0,0]。
          // dom: 鼠标悬停显示的 dom 结点。
          // size.viewSize: canvas容器尺寸，如 [x,y]。
          
          const dw = dom ? dom.clientWidth || 0 : 0;
          const dh = dom ? dom.clientHeight || 0 : 0;
          const cw = size.viewSize[0] || 0;
          
          const x = point[0];
          const y = point[1];
          
          // 默认top在点的上方，left居中。
          const DEFAULT_Y = y - dh - 10;
          const DEFAULT_X = x - dw / 2;
          
          let top = DEFAULT_Y;
          if (DEFAULT_Y < 0) {
            top = y + 10;
          }
          
          let left = DEFAULT_X;
          if (DEFAULT_X < 0) {
            left = x;
          } else if (x + dw / 2 > cw) {
            left = x - dw;
          }
          
          return { left: left, top: top };
        },
      },
      xAxis: {
        type: 'category',
        data: CHART_CONFIG.X_DATA,
        axisLabel: {
          show: false, // 胰岛素图形不展示 X 轴刻度
          color: CHART_CONFIG.TEXT_COLOR,
          fontSize: CHART_CONFIG.FONT_SIZE_XXS,
          interval: MINUTES_PER_HOUR * 4 - ONE_MINUTE,
          formatter: getXAxisLabelFormatter(true, startTime),
        },
        axisTick: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      yAxis: {
        type: 'value',
        min: INS.MIN,
        max: yMax,
        splitLine: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      series: series,
    };
    // return this._getConfig(this._rateData3Min, 3);
  }
  
  public get config() {
    return this._getConfig(this._rateData, 1);
  }
  
  public get configForReport() {
    const startTime = this._startTime;
    const series = [this._series];
    const yMax = INS.MAX_NORMAL;
    
    return {
      grid: {
        left: 40,
        right: 20,
        top: 8,
        bottom: 22,
      },
      animation: false,
      backgroundColor: 'transparent',
      tooltip: {
        show: true,
        trigger: 'item',
        extraCssText: 'padding: 0 !important;',
        position: function (point: Array<number>, _, dom: Element, __, size) {
          // point: 鼠标位置 [x,y]。 左上角点是 [0,0]。
          // dom: 鼠标悬停显示的 dom 结点。
          // size.viewSize: canvas容器尺寸，如 [x,y]。
          
          const dw = dom ? dom.clientWidth || 0 : 0;
          const dh = dom ? dom.clientHeight || 0 : 0;
          const cw = size.viewSize[0] || 0;
          
          const x = point[0];
          const y = point[1];
          
          // 默认top在点的上方，left居中。
          const DEFAULT_Y = y - dh - 10;
          const DEFAULT_X = x - dw / 2;
          
          let top = DEFAULT_Y;
          if (DEFAULT_Y < 0) {
            top = y + 10;
          }
          
          let left = DEFAULT_X;
          if (DEFAULT_X < 0) {
            left = x;
          } else if (x + dw / 2 > cw) {
            left = x - dw;
          }
          
          return { left: left, top: top };
        },
      },
      xAxis: {
        type: 'category',
        data: CHART_CONFIG.X_DATA,
        axisLabel: {
          show: false, // 胰岛素图形不展示 X 轴刻度
          color: CHART_CONFIG.TEXT_COLOR,
          fontSize: CHART_CONFIG.FONT_SIZE_XXS,
          interval: MINUTES_PER_HOUR * 4 - ONE_MINUTE,
          formatter: getXAxisLabelFormatter(true, startTime),
        },
        axisTick: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      yAxis: {
        type: 'value',
        min: INS.MIN,
        max: yMax,
        splitLine: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        axisLine: {
          show: true,
          lineStyle: {
            color: CHART_CONFIG.AXIS_LINE_COLOR,
          },
        },
      },
      series: series,
    };
  }
  
  
  private _getBolusCircleIndexCountFromTextCountForReport(c: number, minPerIndex: number, id?: REPORT_ID): number {
    const g = (hour: number) => Math.floor((hour * 60) / minPerIndex);
    if (id === REPORT_ID.MERGE || id === REPORT_ID.INS) {
      // 胰岛素和血糖综合评估报告/胰岛素用量报告
      if (c === 1) {
        return g(2.4);
      }
      if (c === 2) {
        return g(3.2);
      }
      if (c === 3) {
        return g(3.6);
      }
      if (c === 4) {
        return g(4.2);
      }
      if (c === 5) {
        return g(5.2);
      }
      if (c === 6) {
        return g(7);
      }
      if (c === 7) {
        return g(8);
      }
      if (c === 8) {
        return g(8.5);
      }
      if (c === 9) {
        return g(9);
      }
      return g(10);
    }
    else {
      // 胰岛素用量与血糖趋势图/胰岛素用量趋势图
      if (c === 1) {
        return g(0.8);
      }
      if (c === 2) {
        return g(0.8);
      }
      if (c === 3) {
        return g(1);
      }
      if (c === 4) {
        return g(1.2);
      }
      if (c === 5) {
        return g(1.5);
      }
      if (c === 6) {
        return g(1.8);
      }
      if (c === 7) {
        return g(2);
      }
      if (c === 8) {
        return g(2.2);
      }
      if (c === 9) {
        return g(2.4);
      }
      return g(3);
    }
  }
  
  // 计算包住大剂量椭圆内文本所需要的索引数
  // c: 椭圆内字符数（包括小数点和括号）
  // minPerIndex: 每个索引代表多少分钟
  private _getBolusCircleIndexCountFromTextCount(c: number, minPerIndex: number, isRealTime?: boolean, isMerge?: boolean, isApp?: boolean, isPhone?: boolean): number {
    const g = (hour: number) => Math.floor((hour * 60) / minPerIndex);
    if (isRealTime) {
      // 院泵实时 仅PC
      const is4k = useScreenStore().is4KOrAbove;
      if (c === 1) {
        return g(is4k ? 1.2 : 2);
      }
      if (c === 2) {
        return g(is4k ? 1.5 : 2.4);
      }
      if (c === 3) {
        return g(is4k ? 1.8 : 2.8);
      }
      if (c === 4) {
        return g(is4k ? 2 : 3.2);
      }
      if (c === 5) {
        return g(is4k ? 2.2 : 4);
      }
      if (c === 6) {
        return g(is4k ? 2.4 : 4.8);
      }
      if (c === 7) {
        return g(is4k ? 2.8 : 5);
      }
      if (c === 8) {
        return g(is4k ? 3 : 5.4);
      }
      if (c === 9) {
        return g(is4k ? 3.2 : 6.2);
      }
      return g(is4k ? 3.4 : 8);
    }
    else if (isMerge) {
      if (isApp) {
        // 概况-输注实时,分析-每日综合 仅APP
        if (isPhone) {
          if (c === 1) {
            return g(1.4);
          }
          if (c === 2) {
            return g(1.8);
          }
          if (c === 3) {
            return g(2);
          }
          if (c === 4) {
            return g(2.2);
          }
          if (c === 5) {
            return g(2.4);
          }
          if (c === 6) {
            return g(2.8);
          }
          if (c === 7) {
            return g(3);
          }
          if (c === 8) {
            return g(3.2);
          }
          if (c === 9) {
            return g(3.6);
          }
          return g(4);
        }
        else {
          if (c === 1) {
            return g(1);
          }
          if (c === 2) {
            return g(1.2);
          }
          if (c === 3) {
            return g(1.4);
          }
          if (c === 4) {
            return g(1.6);
          }
          if (c === 5) {
            return g(1.8);
          }
          if (c === 6) {
            return g(2.2);
          }
          if (c === 7) {
            return g(2.4);
          }
          if (c === 8) {
            return g(2.8);
          }
          if (c === 9) {
            return g(3);
          }
          return g(3.6);
        }
      }
      else {
        // 患者信息-综合分析，数据分析-每日综合 仅PC
        if (c === 1) {
          return g(0.6);
        }
        if (c === 2) {
          return g(0.8);
        }
        if (c === 3) {
          return g(1);
        }
        if (c === 4) {
          return g(1.2);
        }
        if (c === 5) {
          return g(1.4);
        }
        if (c === 6) {
          return g(1.5);
        }
        if (c === 7) {
          return g(1.6);
        }
        if (c === 8) {
          return g(1.8);
        }
        if (c === 9) {
          return g(2);
        }
        return g(2.4);
      }
    }
    else {
      if (isApp) {
        // 分析-每日胰岛素 仅APP
        if (isPhone) {
          if (c === 1) {
            return g(1.4);
          }
          if (c === 2) {
            return g(1.8);
          }
          if (c === 3) {
            return g(2);
          }
          if (c === 4) {
            return g(2.2);
          }
          if (c === 5) {
            return g(2.4);
          }
          if (c === 6) {
            return g(3);
          }
          if (c === 7) {
            return g(3.2);
          }
          if (c === 8) {
            return g(3.6);
          }
          if (c === 9) {
            return g(4);
          }
          return g(4.2);
        }
        else {
          if (c === 1) {
            return g(1);
          }
          if (c === 2) {
            return g(1.2);
          }
          if (c === 3) {
            return g(1.4);
          }
          if (c === 4) {
            return g(1.6);
          }
          if (c === 5) {
            return g(1.8);
          }
          if (c === 6) {
            return g(2.2);
          }
          if (c === 7) {
            return g(2.4);
          }
          if (c === 8) {
            return g(3);
          }
          if (c === 9) {
            return g(3.2);
          }
          return g(3.6);
        }
      }
      else {
        // 数据分析-胰岛素用量 仅PC
        if (c === 1) {
          return g(0.8);
        }
        if (c === 2) {
          return g(1.2);
        }
        if (c === 3) {
          return g(1.2);
        }
        if (c === 4) {
          return g(1.5);
        }
        if (c === 5) {
          return g(1.8);
        }
        if (c === 6) {
          return g(2);
        }
        if (c === 7) {
          return g(2.1);
        }
        if (c === 8) {
          return g(2.4);
        }
        if (c === 9) {
          return g(2.8);
        }
        return g(3);
      }
    }
  }
  
  /**
   * 将格式化的胰岛素记录 dto 转化为 RATE_DATE。
   *
   * 注意:
   * 1.这是后端的逻辑，搬到前端运行。
   * 2.返回的胰岛素数据必然从当前时刻到第二天的当前时刻，所以 x 轴对应上 RATE_DATA 的索引就可以。
   *
   * @param firstStartTime 这一批数据的开始时间，时间戳，单位秒
   * @param forwardOrderedRecords 根据历史记录和实时状态生成的数据，必须按 record_time 正序
   */
  private _getRateDataFromStartTimeAndRecords(firstStartTime: number, forwardOrderedRecords: Array<ChartRecordDTO>): RATE_DATA {
    const rateData = [] as RATE_DATA;
    const endTime = firstStartTime + SECONDS_PER_DAY;
    
    for (let i = 0; i < MINUTES_PER_DAY; i++) {
      rateData.push([0, 0, 0, 0, 0, HISTORY_KIND.INVALID_VALUE, 0]);
    }
    
    for (let j = 0, len = forwardOrderedRecords.length; j < len; j++) {
      const data = forwardOrderedRecords[j];
      const startTime = data.record_time;
      const runningTime = data.seconds;
      const status = data.status;
      const value = data.value;
      const kind = data.kind;
      const subKind = data.sub_kind || 0;
      
      if (!isHistoryInfusion(kind)) {
        continue;
      }
      
      // 计算本段记录的测量时刻，即分钟索引 (范围 0~1439)
      let startMinuteIndex = 0;
      if (startTime < firstStartTime) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - firstStartTime) / SECONDS_PER_MINUTE);
      }
      
      // 计算本段记录的持续时间 (分钟)
      let runningMinutes = 0;
      if (isHistoryDose(kind)) {
        // 2024-08-08: 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
        runningMinutes = INS.DOSE.LAST_MINUTES;
      } else {
        let runningSeconds = runningTime;
        if (startTime < firstStartTime) {
          runningSeconds = runningTime - (firstStartTime - startTime);
        } else {
          runningSeconds = runningTime;
        }
        runningMinutes = Math.floor(runningSeconds / SECONDS_PER_MINUTE);
      }
      
      // 填充每一分钟的数据
      for (let i = 0; i < runningMinutes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本分钟数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isHistoryDose(kind)) {
          // 本段大剂量记录的结束索引 (0 ~ runningMinutes-1)
          let endIndex = runningMinutes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningMinutes * SECONDS_PER_MINUTE) >= endTime) {
            endIndex = Math.floor((endTime - startTime) / SECONDS_PER_MINUTE);
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= MINUTES_PER_DAY || index < 0) {
          continue;
        }
        
        // 基础率运行时间 >30min
        // 大剂量运行时间 1s~33min
        // 2024-08-12 黄伦: 基础率运行的同时不可以运行大剂量，所以不存在大剂量被前面的基础率占位的情况
        // 按 record_time 顺序填充，每次填充一段记录。
        // |***********-------------------  (第一次填充)
        // |***********|***---------------  (第二次填充)
        // |***********|***|*******-------  (第三次填充)
        // rateData[index] 可能被前面的记录填充过，但此处尝试覆盖。
        // index 代表的数据
        
        // 填充 rateData, 注意:
        // 1. 趋势图写死了大剂量的持续时间;
        // 2. 显示大剂量的优先级高，大剂量可以覆盖掉前面的基础率，基础率不可以覆盖掉前面的大剂量;
        // 3. 前后相同 status 的数据，后面的会覆盖前面的;
        if (rateData[index][KIND_INDEX] === HISTORY_KIND.INVALID_VALUE || isHistoryDose(kind) || rateData[index][KIND_INDEX] === kind) {
          rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0, kind, subKind as InsKindType];
        }
      }
    }
    
    return rateData;
  }
  
  /**
   * 将格式化的胰岛素记录 dto 转化为 RATE_DATE。
   *
   * 每 15 分钟的数据合成一个数值。
   */
  private _getRateDataPerFifthPointsFromStartTimeAndRecords(firstStartTime: number, forwardOrderedRecords: Array<ChartRecordDTO>): RATE_DATA {
    const rateData = [] as RATE_DATA;
    const endTime = firstStartTime + SECONDS_PER_DAY;
    const SECONDS_PER_INDEX = SECONDS_PER_MINUTE * 15;
    
    for (let i = 0; i < FIFTEEN_MINUTE_INDEXES_PER_DAY; i++) {
      rateData.push([0, 0, 0, 0, 0, HISTORY_KIND.INVALID_VALUE, 0]);
    }
    for (let j = 0, len = forwardOrderedRecords.length; j < len; j++) {
      const data = forwardOrderedRecords[j];
      const startTime = data.record_time;
      const runningTime = data.seconds;
      const status = data.status;
      const value = data.value;
      const kind = data.kind;
      const subKind = data.sub_kind || 0;
      
      if (!isHistoryInfusion(kind)) {
        continue;
      }
      
      // 计算本段记录的测量时刻，即索引 (范围 0~95)
      let startMinuteIndex = 0;
      if (startTime < firstStartTime) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - firstStartTime) / SECONDS_PER_INDEX);
      }
      
      // 每 15 分钟1个索引，计算本段记录的持续索引数
      let runningIndexes = 0;
      if (isHistoryDose(kind)) {
        // 2024-08-08: 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
        runningIndexes = Math.floor(INS.DOSE.LAST_MINUTES_FOR_MOBILE_CLINIC / 15); // 打卡移动端的大剂量，固定持续 30 分钟。
        if (useScreenStore().isMobile && useScreenStore().widthPixel >= 600) {
          // 平板比较宽，持续一个索引即可
          runningIndexes = 1;
        }
      } else {
        let runningSeconds = runningTime;
        if (startTime < firstStartTime) {
          runningSeconds = runningTime - (firstStartTime - startTime);
        } else {
          runningSeconds = runningTime;
        }
        // 末尾的持续时间不到一个索引的，算一个索引
        runningIndexes = Math.ceil(runningSeconds / SECONDS_PER_INDEX);
      }
      
      // 填充每一个索引的数据
      for (let i = 0; i < runningIndexes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本分钟数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isHistoryDose(kind)) {
          // 本段大剂量记录的结束索引 (0 ~ runningIndexes-1)
          let endIndex = runningIndexes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningIndexes * SECONDS_PER_INDEX) >= endTime) {
            endIndex = Math.floor((endTime - startTime) / SECONDS_PER_INDEX);
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= FIFTEEN_MINUTE_INDEXES_PER_DAY || index < 0) {
          continue;
        }
        
        if (rateData[index][KIND_INDEX] === HISTORY_KIND.INVALID_VALUE || isHistoryDose(kind) || rateData[index][KIND_INDEX] === kind) {
          rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0, kind, subKind as InsKindType];
        }
      }
    }
    
    return rateData;
  }
  
  /**
   * 将格式化的胰岛素记录 dto 转化为 RATE_DATE。
   *
   * 每 5 分钟的数据合成一个数值。
   */
  private _getRateDataPerFivePointsFromStartTimeAndRecords(firstStartTime: number, forwardOrderedRecords: Array<ChartRecordDTO>): RATE_DATA {
    const rateData = [] as RATE_DATA;
    const endTime = firstStartTime + SECONDS_PER_DAY;
    const SECONDS_PER_INDEX = SECONDS_PER_MINUTE * 5;
    
    for (let i = 0; i < FIVE_MINUTE_INDEXES_PER_DAY; i++) {
      rateData.push([0, 0, 0, 0, 0, HISTORY_KIND.INVALID_VALUE, 0]);
    }
    for (let j = 0, len = forwardOrderedRecords.length; j < len; j++) {
      const data = forwardOrderedRecords[j];
      const startTime = data.record_time;
      const runningTime = data.seconds;
      const status = data.status;
      const value = data.value;
      const kind = data.kind;
      const subKind = data.sub_kind || 0;
      
      if (!isHistoryInfusion(kind)) {
        continue;
      }
      
      // 将本段记录的测量时刻转为坐标轴中的 X 索引，范围: [0,287]。
      let startMinuteIndex = 0;
      if (startTime < firstStartTime) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - firstStartTime) / SECONDS_PER_INDEX);
      }
      
      // 每 5 分钟 1 个索引，计算本段记录的持续索引数。
      let runningIndexes = 0;
      if (isHistoryDose(kind)) {
        // 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
        runningIndexes = INS.DOSE.LASTING_INDEX_FOR_PHONE;
      } else {
        let runningSeconds = runningTime;
        if (startTime < firstStartTime) {
          runningSeconds = runningTime - (firstStartTime - startTime);
        } else {
          runningSeconds = runningTime;
        }
        // 末尾的持续时间不到一个索引的，算一个索引
        runningIndexes = Math.ceil(runningSeconds / SECONDS_PER_INDEX);
      }
      
      // 填充每一个索引的数据
      for (let i = 0; i < runningIndexes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本分钟数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isHistoryDose(kind)) {
          // 本段大剂量记录的结束索引 (0 ~ runningIndexes-1)
          let endIndex = runningIndexes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningIndexes * SECONDS_PER_INDEX) >= endTime) {
            endIndex = Math.floor((endTime - startTime) / SECONDS_PER_INDEX);
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= FIVE_MINUTE_INDEXES_PER_DAY || index < 0) {
          continue;
        }
        
        if (rateData[index][KIND_INDEX] === HISTORY_KIND.INVALID_VALUE || isHistoryDose(kind) || rateData[index][KIND_INDEX] === kind) {
          rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0, kind, subKind as InsKindType];
        }
      }
    }
    
    return rateData;
  }
  
  /**
   * 将格式化的胰岛素记录 dto 转化为 RATE_DATA。
   *
   * 每 3 分钟的数据合成一个数值。
   */
  private _getRateDataPerThreePointsFromStartTimeAndRecords(firstStartTime: number, forwardOrderedRecords: Array<ChartRecordDTO>): RATE_DATA {
    const rateData = [] as RATE_DATA;
    const endTime = firstStartTime + SECONDS_PER_DAY;
    const SECONDS_PER_INDEX = SECONDS_PER_MINUTE * 3;
    
    for (let i = 0; i < THREE_MINUTE_INDEXES_PER_DAY; i++) {
      rateData.push([0, 0, 0, 0, 0, HISTORY_KIND.INVALID_VALUE, 0]);
    }
    
    for (let j = 0, len = forwardOrderedRecords.length; j < len; j++) {
      // 取出一段记录，开始处理
      const data = forwardOrderedRecords[j];
      const startTime = data.record_time;
      const runningTime = data.seconds;
      const status = data.status;
      const value = data.value;
      const kind = data.kind;
      const subKind = data.sub_kind || 0;
      
      if (!isHistoryInfusion(kind)) {
        continue;
      }
      
      // 计算本段记录的测量时刻，即索引 (范围 0~479)
      let startMinuteIndex = 0;
      if (startTime < firstStartTime) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - firstStartTime) / SECONDS_PER_INDEX);
      }
      
      // 每3分钟1个索引，计算本段记录的持续索引数
      let runningIndexes = 0;
      if (isHistoryDose(kind)) {
        // 2024-08-08: 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
        // runningIndexes = Math.floor(INS.DOSE.LAST_MINUTES / 3);
        runningIndexes = INS.DOSE.LASTING_INDEX_FOR_PAD_AND_PC;
      } else {
        let runningSeconds = runningTime;
        if (startTime < firstStartTime) {
          runningSeconds = runningTime - (firstStartTime - startTime);
        } else {
          runningSeconds = runningTime;
        }
        runningIndexes = Math.floor(runningSeconds / SECONDS_PER_INDEX);
      }
      
      // 填充每一个索引的数据
      for (let i = 0; i < runningIndexes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本分钟数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isHistoryDose(kind)) {
          // 本段大剂量记录的结束索引 (0 ~ runningIndexes-1)
          let endIndex = runningIndexes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningIndexes * SECONDS_PER_INDEX) >= endTime) {
            endIndex = Math.floor((endTime - startTime) / SECONDS_PER_INDEX);
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= THREE_MINUTE_INDEXES_PER_DAY || index < 0) {
          continue;
        }
        
        if (rateData[index][KIND_INDEX] === HISTORY_KIND.INVALID_VALUE || isHistoryDose(kind) || rateData[index][KIND_INDEX] === kind) {
          rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0, kind, subKind as InsKindType];
        }
      }
    }
    
    return rateData;
  }
  
  /**
   * 2025-06-06 废弃: 将全部的 status 改用 kind 实现;
   * （留一个旧方案作参照）
   */
  private _old_getRateDataFromStartTimeAndRecords(firstStartTime: number, forwardOrderedRecords: Array<ChartRecordDTO>): RATE_DATA {
    const rateData = [] as RATE_DATA;
    const endTime = firstStartTime + SECONDS_PER_DAY;
    
    for (let i = 0; i < MINUTES_PER_DAY; i++) {
      rateData.push([0, 0, 0, 0, 0, 0, 0]);
    }
    
    for (let j = 0, len = forwardOrderedRecords.length; j < len; j++) {
      const data = forwardOrderedRecords[j];
      const startTime = data.record_time;
      const runningTime = data.seconds;
      const status = data.status;
      const value = data.value;
      const kind = data.kind;
      const subKind = data.sub_kind;
      
      if (status < 100 || status > 200) {
        continue;
      }
      
      // 计算本段记录的测量时刻，即分钟索引 (范围 0~1439)
      let startMinuteIndex = 0;
      if (startTime < firstStartTime) {
        startMinuteIndex = 0;
      } else {
        startMinuteIndex = Math.floor((startTime - firstStartTime) / SECONDS_PER_MINUTE);
      }
      
      // 计算本段记录的持续时间 (分钟)
      let runningMinutes = 0;
      if (isDose(status)) {
        // 2024-08-08: 大剂量仅作为一个标识，在图形上是固定宽度的，所以固定一个持续时间，无需计算。
        runningMinutes = INS.DOSE.LAST_MINUTES;
      } else {
        let runningSeconds = runningTime;
        if (startTime < firstStartTime) {
          runningSeconds = runningTime - (firstStartTime - startTime);
        } else {
          runningSeconds = runningTime;
        }
        runningMinutes = Math.floor(runningSeconds / SECONDS_PER_MINUTE);
      }
      
      // 填充每一分钟的数据
      for (let i = 0; i < runningMinutes; i++) {
        const index = startMinuteIndex + i;
        let isMid = false; // "本分钟数据" 是否在 "该段大剂量记录数据" 中间，"非大剂量数据" 始终为 false。
        
        if (isDose(status)) {
          // 本段大剂量记录的结束索引 (0 ~ runningMinutes-1)
          let endIndex = runningMinutes - 1;
          // 大剂量结束时间超过 X轴终点 时，选用终点作为结束索引。
          if (startTime + Math.floor(runningMinutes * SECONDS_PER_MINUTE) >= endTime) {
            endIndex = Math.floor((endTime - startTime) / SECONDS_PER_MINUTE);
          }
          if (i === Math.floor(endIndex / 2)) {
            // 找到本段大剂量记录的中间索引，标记
            isMid = true;
          }
        }
        
        if (index >= MINUTES_PER_DAY || index < 0) {
          continue;
        }
        
        // 2024-08-12 黄伦: 基础率运行的同时不可以运行大剂量
        // 按 record_time 顺序填充，每次填充一段记录。
        // |***********-------------------  (第一次填充)
        // |***********|***---------------  (第二次填充)
        // |***********|***|*******-------  (第三次填充)
        // rateData[index] 可能被前面的记录填充过，但此处尝试覆盖。
        // index 代表的数据只会 "覆盖同status的数据" 或 "填充空数据"，不会 "覆盖不同status的数据"。
        if (rateData[index][0] === 0 || rateData[index][0] === status) {
          rateData[index] = [status, value, startTime, runningTime, isMid ? 1 : 0, data.kind, (data.sub_kind as InsKindType) || 0];
        }
      }
    }
    return rateData;
  }
}
