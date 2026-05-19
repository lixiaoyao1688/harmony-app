import { i18n } from '@kit.LocalizationKit';
import { LAN } from "../config/lan.config";
import { GlobalState } from "../../../state/global.state";


// 切换语言
export function toggleLanguage(state: GlobalState): void {
  setLanguage(state, state.lan === LAN.CHINESE ? LAN.ENGLISH : LAN.CHINESE);
}

// 设置指定语言
function setLanguage(state: GlobalState, lan: LAN): void {
  try {
    // 设置应用偏好语言。仅影响当前应用，不会改变整个设备的系统语言。
    // https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-i18n#setapppreferredlanguage11
    i18n.System.setAppPreferredLanguage(lan);
    state.lan = lan;
  }
  catch (error) {
    console.error('语言切换失败', JSON.stringify(error));
  }
}
