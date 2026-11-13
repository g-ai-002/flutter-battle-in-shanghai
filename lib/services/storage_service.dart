import 'package:shared_preferences/shared_preferences.dart';

import '../game/battle_config.dart';
import '../game/battle_scenes.dart';
import '../game/battle_sim.dart';
import '../game/logic_rate.dart';
import '../models/records.dart';
import '../utils/constants.dart';

/// 轻量偏好存储：写入失败时静默忽略，不影响战斗主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? true;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  /// 敌军难度，未设置或未知值回退到老兵。
  Difficulty get difficulty =>
      Difficulty.byName(_p.getString(AppConstants.prefKeyDifficulty));

  Future<void> setDifficulty(Difficulty value) =>
      _write((p) => p.setString(AppConstants.prefKeyDifficulty, value.name));

  /// 最近选择的阵地，未设置或未知值回退到闸北。
  BattleScene get scene =>
      BattleScene.byName(_p.getString(AppConstants.prefKeyScene));

  Future<void> setScene(BattleScene value) =>
      _write((p) => p.setString(AppConstants.prefKeyScene, value.name));

  /// 已通关的阵地，按名称存储，未知名称直接忽略。
  Set<BattleScene> get clearedScenes {
    final raw = _p.getStringList(AppConstants.prefKeyClearedScenes) ?? const [];
    return BattleScene.values.where((scene) => raw.contains(scene.name)).toSet();
  }

  Future<void> markSceneCleared(BattleScene scene) => _write((p) async {
    if (clearedScenes.contains(scene)) return true;
    final raw = _p.getStringList(AppConstants.prefKeyClearedScenes) ?? <String>[];
    await p.setStringList(AppConstants.prefKeyClearedScenes, [
      ...raw,
      scene.name,
    ]);
    return true;
  });

  /// 战场逻辑更新速率，未设置或未知值回退到 60Hz。
  LogicRate get logicRate =>
      LogicRate.byName(_p.getString(AppConstants.prefKeyLogicRate));

  Future<void> setLogicRate(LogicRate value) =>
      _write((p) => p.setString(AppConstants.prefKeyLogicRate, value.name));

  BattleRecords get records => BattleRecords(
    bestScore: _p.getInt(AppConstants.prefKeyBestScore) ?? 0,
    bestWave: _p.getInt(AppConstants.prefKeyBestWave) ?? 0,
    totalKills: _p.getInt(AppConstants.prefKeyTotalKills) ?? 0,
    runs: _p.getInt(AppConstants.prefKeyTotalRuns) ?? 0,
    victories: _p.getInt(AppConstants.prefKeyVictories) ?? 0,
  );

  /// 一局结束后累计战绩。
  Future<void> recordRun(BattleResult result) => _write((p) async {
    final next = records.record(result);
    await p.setInt(AppConstants.prefKeyBestScore, next.bestScore);
    await p.setInt(AppConstants.prefKeyBestWave, next.bestWave);
    await p.setInt(AppConstants.prefKeyTotalKills, next.totalKills);
    await p.setInt(AppConstants.prefKeyTotalRuns, next.runs);
    await p.setInt(AppConstants.prefKeyVictories, next.victories);
    return true;
  });
}
