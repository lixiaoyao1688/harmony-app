import { LAN } from '../lib/lan/config/lan.config';
import { THEME } from '../lib/theme/config/theme.config';


export class GlobalState {

  private _lan: LAN = LAN.CHINESE;
  private _theme: THEME = THEME.DARK;

  // 多语言
  public get lan(): LAN {
    return this._lan;
  }
  public set lan(data: LAN) {
    this._lan = data;
  }

  // 深浅色模式
  public get theme(): THEME {
    return this._theme;
  }
  public set theme(data: THEME) {
    this._theme = data;
  }

}

// 创建全局状态单例
export const globalState: GlobalState = new GlobalState();
