import { i18n } from '@kit.LocalizationKit';
import { systemDateTime } from '@kit.BasicServicesKit';

// 时间转化表
// 世界时间(Europe/London, UTC):     2021-01-01 00:00:00 (0°经线, 本初子午线, 格林尼治皇家天文台, 英国伦敦)
// 北京时间(Asia/Shanghai, UTC+8):   2021-01-01 08:00:00
// 纽约时间(America/NewYork, UTC-5): 2020-12-31 19:00:00

// 基准时间戳(ms)
// 北京时间(Asia/Shanghai, UTC+8):   2021-01-01 00:00:00
export const BASE_TIME_STAMP: number = 1609430400000;

/**
 * 返回从 "当前时区的2021-01-01 00:00:00" 到 "当前时区的当前时间戳" 经过的时间 (s)
 * @returns
 */
export async function getPassedTime(): Promise<number> {
  try {
    // 当前时区
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-date-time#systemdatetimegettimezone-1
    const zoneID = await systemDateTime.getTimezone();
    console.log('当前时区:', zoneID);
    // 当前时区的当前时刻 (ms)
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-date-time#systemdatetimegettime10
    const currentTime = systemDateTime.getTime();
    console.log(`${zoneID} 的当前时间戳 (ms):`, currentTime, '(' + getTimeText(currentTime) + ')');
    // 代表当前时区"2021-01-01 00:00:00:000"的时间戳 (ms)
    // 注意：月份参数为0（代表1月），毫秒参数为0
    const baseTime = new Date(2021, 0, 1, 0, 0, 0, 0).getTime();
    console.log(`${zoneID} 的 2021-01-01 00:00:00:000 代表的时间戳 (ms):`, baseTime);
    // 计算已经过的时间 (s)(泵程序的惯例: 末尾截断)
    const passedSeconds = Math.floor((currentTime - baseTime) / 1000);
    console.log(`从 "${zoneID}的2021-01-01 00:00:00" 到 "${zoneID}的当前时间戳" 经过的时间(s):`, passedSeconds);
    return passedSeconds;
  }
  catch(e) {
    console.error('getSettingTime_error', JSON.stringify(e));
    return 0;
  }
}


/**
 * 将时间戳(ms)格式化为当前时区下的时间文本
 *
 * 示例:
 * 输入
 * 1777428844753
 * 输出 "北京时间(Asia/Shanghai, UTC+8)"
 * 2026-04-27 15:19:51
 *
 * @param data 毫秒时间戳
 * @returns 格式化后的时间文本
 */
export function getTimeText(data: number): string {
  const date = new Date(data);
  const year = date.getFullYear().toString();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const seconds = date.getSeconds().toString().padStart(2, '0');
  const milliseconds = date.getMilliseconds().toString().padStart(3, '0');

  return 'yyyy-MM-dd HH:mm:ss:SSS'
    .replace('yyyy', year)
    .replace('MM', month)
    .replace('dd', day)
    .replace('HH', hours)
    .replace('mm', minutes)
    .replace('ss', seconds)
    .replace('SSS', milliseconds);
}

/**
 * 返回"时区1"对"时区2"的时间差 (ms) (注意: 可能为负数!!)
 *
 * @param timezone1 第一个时区ID，如: "Asia/Shanghai"
 * @param timezone2 第二个时区ID，如: "Europe/Moscow"
 *
 * 时区ID参考
 * https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-date-time#%E6%94%AF%E6%8C%81%E7%9A%84%E7%B3%BB%E7%BB%9F%E6%97%B6%E5%8C%BA
 *
 * @returns 时间差 (ms)
 */
export function getDiffTime(timezone1: string, timezone2: string): number {
  if (timezone1 === timezone2) {
    // 如果时区相同，返回无差异
    return 0;
  }
  try {
    // 获取两个时区的 TimeZone 对象
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-i18n#i18ngettimezone
    const tz1 = i18n.getTimeZone(timezone1);
    const tz2 = i18n.getTimeZone(timezone2);
    // 分别获取两个时区相对于0时区"世界时间(Europe/London, UTC)"的偏移量（ms）
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-i18n#getoffset
    const offset1 = tz1.getOffset();
    console.log('偏移量1(ms)', offset1, getOffsetText(offset1));
    const offset2 = tz2.getOffset();
    console.log('偏移量2(ms)', offset2, getOffsetText(offset2));
    // 计算两个时区的时间差(ms)
    return offset1 - offset2;
  }
  catch (e) {
    console.error('getDiffTime_error', JSON.stringify(e));
    throw new Error(e);
  }
}

/**
 * 返回偏移量代表的时间文本, 如 28800000 返回 "08:00:00:000"
 *
 * @param data 偏移量, 单位毫秒
 * @returns 时间文本，格式为 HH:mm:ss:SSS (小时:分:秒:毫秒)
 */
export function getOffsetText(data: number): string {
  let totalMs = Math.abs(data);

  const hours = Math.floor(totalMs / 3600000);
  totalMs -= hours * 3600000;

  const minutes = Math.floor(totalMs / 60000);
  totalMs -= minutes * 60000;

  const seconds = Math.floor(totalMs / 1000);
  const milliseconds = totalMs - seconds * 1000;

  const pad2 = (n: number): string => n.toString().padStart(2, '0');
  const pad3 = (n: number): string => n.toString().padStart(3, '0');

  return `${data < 0 ? '-' : '+'}${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)}:${pad3(milliseconds)}`;
}

/**
 * 将毫秒时间戳格式化为指定字符串
 * @param timestamp 毫秒时间戳
 * @returns 格式为 "YYYY/MM/DD HH:mm:ss.SSS" 的时间字符串
 */
export function formatTimestamp(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear().toString();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const seconds = date.getSeconds().toString().padStart(2, '0');
  const milliseconds = date.getMilliseconds().toString().padStart(3, '0');

  return `${year}/${month}/${day} ${hours}:${minutes}:${seconds}.${milliseconds}`;
}
