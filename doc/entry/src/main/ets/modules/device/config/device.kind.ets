export enum DEVICE_KIND {
  INSULIN_PUMP = 0,           // 胰岛素泵
  PHONE = 1,                  // 手机
  CONTROLLER = 2,             // 控制器
  WATCH = 3,                  // 手表
  CGM = 4,                    // 持续血糖监测
  CGM_PHONE = 5,              // 持续血糖监测手机端
  INSULIN_PUMP_RESEARCH = 6,  // 胰岛素泵科研版
  PHONE_APP_RESEARCH = 7,     // 手机app科研版
  CLOSED_LOOP_PUMP_PHONE = 8, // 闭环泵手机APP
  CLOSED_LOOP_INSULIN_PUMP = 9, // 闭环胰岛素泵
  CLOSED_LOOP_PUMP_WATCH = 10, // 闭环泵手表APP
  CLOSED_LOOP_PUMP_K330 = 11,  // 闭环泵K330控制器
  CGM_DEBUG = 255             // 持续血糖监测的调试设备
}