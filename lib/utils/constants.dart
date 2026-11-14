/// 界面里用到的固定尺寸、键名与战场几何常数。
library;

/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

class AppConstants {
  AppConstants._();

  static const String appName = '血战上海滩';
  static const String version = '0.3.2';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyDifficulty = 'difficulty';
  static const String prefKeyScene = 'battle_scene';
  static const String prefKeyClearedScenes = 'cleared_scenes';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyBestScore = 'best_score';
  static const String prefKeyBestWave = 'best_wave';
  static const String prefKeyTotalKills = 'total_kills';
  static const String prefKeyTotalRuns = 'total_runs';
  static const String prefKeyVictories = 'victories';
}

/// 战场的逻辑坐标：固定 300 × 400，渲染时等比缩放，玩法与屏幕尺寸无关。
class Field {
  Field._();

  static const double width = 300;
  static const double height = 400;
  static const double aspect = width / height;

  /// 玩家可活动的纵向范围：守住街道下半段。
  static const double playerMinY = 170;
  static const double playerMaxY = 384;
  static const double playerMarginX = 14;
  static const double playerStartY = 340;

  static const double enemyTop = -30;
}
