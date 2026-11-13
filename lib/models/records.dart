import '../game/battle_sim.dart';
import '../utils/formatters.dart';

/// 历史战绩：最高分、最远波次、累计击杀与通关次数。
class BattleRecords {
  const BattleRecords({
    this.bestScore = 0,
    this.bestWave = 0,
    this.totalKills = 0,
    this.runs = 0,
    this.victories = 0,
  });

  final int bestScore;
  final int bestWave;
  final int totalKills;
  final int runs;
  final int victories;

  double get winRate => runs == 0 ? 0 : victories / runs;

  /// 记一局战果，返回累计后的新战绩。
  BattleRecords record(BattleResult result) => BattleRecords(
    bestScore: result.score > bestScore ? result.score : bestScore,
    bestWave: result.wave > bestWave ? result.wave : bestWave,
    totalKills: totalKills + result.kills,
    runs: runs + 1,
    victories: victories + (result.won ? 1 : 0),
  );

  /// 首页一行的战绩摘要。
  String get summary => runs == 0
      ? '尚无战绩 · 守住街垒，记录第一场战斗'
      : '最高分 ${formatScore(bestScore)} · 最远第 $bestWave 波 · 累计击杀 $totalKills';
}
