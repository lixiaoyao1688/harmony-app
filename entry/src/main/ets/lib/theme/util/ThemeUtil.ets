import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { THEME } from '../config/theme.config';
import { GlobalState } from '../../../state/global.state';


export class ThemeUtil {

  private static _context: common.UIAbilityContext;

  // 初始化全局状态并保留引用
  static init(context: common.UIAbilityContext, state: GlobalState): void {
    ThemeUtil._context = context;
    state.theme = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? THEME.DARK : THEME.LIGHT;
  }

  // 切换深浅色模式
  static toggleTheme(state: GlobalState): void {
    ThemeUtil.setTheme(state, state.theme === THEME.DARK ? THEME.LIGHT : THEME.DARK);
  }

  // 设置指定颜色模式
  static setTheme(state: GlobalState, data: THEME): void {
    if (!ThemeUtil._context) {
      console.error('ThemeUtil 未初始化，请在 EntryAbility 中调用 ThemeUtil.init');
      return;
    }

    try {
      if (data === THEME.DARK) {
        ThemeUtil._context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        state.theme = THEME.DARK;
      } else {
        ThemeUtil._context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        state.theme = THEME.LIGHT;
      }
    }
    catch (error) {
      console.error('颜色模式切换失败', JSON.stringify(error));
    }

  }

}