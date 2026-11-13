import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/logic_rate.dart';
import 'package:battle_in_shanghai/services/storage_service.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('默认偏好：深色、老兵、60Hz、声音全开', () async {
    final storage = await StorageService.instance;
    expect(storage.darkMode, isTrue);
    expect(storage.difficulty, Difficulty.veteran);
    expect(storage.logicRate, LogicRate.hz60);
    expect(storage.soundEnabled, isTrue);
    expect(storage.musicEnabled, isTrue);
    expect(storage.hapticsEnabled, isTrue);
    expect(storage.records.runs, 0);
  });

  test('偏好可以写入并读回', () async {
    final storage = await StorageService.instance;
    await storage.setDarkMode(false);
    await storage.setDifficulty(Difficulty.ace);
    await storage.setLogicRate(LogicRate.hz120);
    await storage.setSoundEnabled(false);
    await storage.setMusicEnabled(false);
    await storage.setHapticsEnabled(false);
    expect(storage.darkMode, isFalse);
    expect(storage.difficulty, Difficulty.ace);
    expect(storage.logicRate, LogicRate.hz120);
    expect(storage.soundEnabled, isFalse);
    expect(storage.musicEnabled, isFalse);
    expect(storage.hapticsEnabled, isFalse);
  });

  test('未知的难度与刷新率回退到默认值', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyDifficulty: 'nightmare',
      AppConstants.prefKeyLogicRate: 'hz240',
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    expect(storage.difficulty, Difficulty.veteran);
    expect(storage.logicRate, LogicRate.hz60);
  });

  test('一局结束后累计战绩并持久化', () async {
    final storage = await StorageService.instance;
    await storage.recordRun(
      const BattleResult(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
        won: true,
        score: 5200,
        kills: 26,
        wave: 5,
        maxCombo: 9,
        seconds: 120,
      ),
    );
    final records = storage.records;
    expect(records.bestScore, 5200);
    expect(records.bestWave, 5);
    expect(records.totalKills, 26);
    expect(records.runs, 1);
    expect(records.victories, 1);
  });
}
