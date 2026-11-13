import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/models/records.dart';
import 'package:flutter_test/flutter_test.dart';

BattleResult result({
  int score = 1000,
  int kills = 10,
  int wave = 3,
  bool won = false,
}) => BattleResult(
  mode: BattleMode.campaign,
  difficulty: Difficulty.veteran,
  won: won,
  score: score,
  kills: kills,
  wave: wave,
  maxCombo: 5,
  seconds: 60,
);

void main() {
  test('空战绩的摘要提示先打一局', () {
    const records = BattleRecords();
    expect(records.runs, 0);
    expect(records.winRate, 0);
    expect(records.summary, contains('尚无战绩'));
  });

  test('记录一局后更新最高分、最远波次与累计击杀', () {
    const empty = BattleRecords();
    final one = empty.record(result(score: 1200, kills: 8));
    expect(one.bestScore, 1200);
    expect(one.bestWave, 3);
    expect(one.totalKills, 8);
    expect(one.runs, 1);
    expect(one.victories, 0);

    final two = one.record(result(score: 800, kills: 5, wave: 1, won: true));
    expect(two.bestScore, 1200);
    expect(two.bestWave, 3);
    expect(two.totalKills, 13);
    expect(two.runs, 2);
    expect(two.victories, 1);
    expect(two.winRate, 0.5);
    expect(two.summary, contains('1,200'));
  });
}
