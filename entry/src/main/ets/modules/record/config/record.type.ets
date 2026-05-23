/**
 * 历史记录 类型
 */
export enum RECORD_TYPE {
  BASE = 0,  // 基础率
  TEMP_BASE = 1,  // 临时基础率
  BOLUS = 2,  // 大剂量（延长量）
  WARNING = 3,  // 报警
  ROD_BACK = 4,  // 推杆回退
  ROD_POSITION = 5,  // 推杆定位
  RESTORE = 6,  // 恢复出厂默认设置
  PAUSE = 7,  // 暂停
  CLOSED_MODE = 8,  // 闭环模式
  SPORT_MODE = 9,  // 运动模式
  SLEEP_MODE = 10,  // 睡眠模式
  CGM_CONNECTION_STATE = 11,  // CGM连接状态
  WARNING_INFO = 12,  // 警示信息
  FIXED_FILL = 13,  // 定量充盈
  SHUTDOWN = 14,  // 泵关机
  TIME_CHANGED = 127,  // 时间更改
}
