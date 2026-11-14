import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// 自动化 bot：对准最近敌军、适时投雷，并在压力大时布置工事与呼叫空袭，
/// 验证战役在会用工事的操作下确实可以打通。
void playCampaign(BattleSim sim) {
  var guard = 0;
  while (!sim.finished && guard < 60 * 300) {
    final targets = sim.enemies.where((enemy) => !enemy.dead).toList()
      ..sort((a, b) => a.y.compareTo(b.y));
    if (targets.isNotEmpty) {
      final dx = targets.first.x - sim.player.x;
      sim.movePlayer(dx.clamp(-2.4, 2.4), 0);
    }
    if (sim.grenadeCooldownLeft <= 0 && targets.length >= 2) {
      sim.throwGrenade();
    }
    if (sim.airstrikeCooldownLeft <= 0 && targets.length >= 3) {
      sim.callAirstrike();
    }
    if (sim.coverCooldownLeft <= 0 &&
        !sim.sheltering &&
        sim.player.hp < 70 &&
        sim.coverCount < sim.coverLimit) {
      sim.deployCover();
    }
    sim.update(1 / 60);
    guard++;
  }
}

void main() {
  test('老兵难度下按正常操作可以打通五波战役', () {
    final sim = BattleSim(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
      random: math.Random(42),
    )..start();
    playCampaign(sim);

    expect(sim.status, BattleStatus.won);
    expect(sim.wave, kCampaignWaves);
    expect(sim.kills, greaterThanOrEqualTo(30));
    expect(sim.score, greaterThan(5000));
    expect(sim.player.hp, greaterThan(0));
  });

  test('四处阵地在老兵难度下都可以打通', () {
    for (final scene in BattleScene.values) {
      final sim = BattleSim(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
        scene: scene,
        random: math.Random(42),
      )..start();
      playCampaign(sim);

      expect(sim.status, BattleStatus.won, reason: scene.label);
      expect(sim.wave, kCampaignWaves, reason: scene.label);
      expect(sim.kills, greaterThanOrEqualTo(25), reason: scene.label);
      expect(sim.player.hp, greaterThan(0), reason: scene.label);
    }
  });

  test('王牌难度下通关更吃力，但仍有胜算', () {
    final sim = BattleSim(
      mode: BattleMode.campaign,
      difficulty: Difficulty.ace,
      random: math.Random(7),
    )..start();
    playCampaign(sim);

    expect(sim.status, BattleStatus.won);
    expect(sim.result.won, isTrue);
  });
}
