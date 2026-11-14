import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/wave_director.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('战役波次调度', () {
    test('开始波次后进入集结，播报与倒计时同步', () {
      final director = WaveDirector(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
        random: math.Random(3),
      );

      expect(director.begin(1, 100), BattleCue.wave);
      expect(director.wave, 1);
      expect(director.waveBreak, WaveDirector.waveBreakSeconds);
      expect(director.announcing, isTrue);
      expect(director.announcement, '第 1 波 · 前哨试探');
      expect(director.waveName, '前哨试探');
      expect(director.phaseBrief, '敌军集结中');
      expect(director.pendingSpawns, greaterThan(0));
      expect(director.allSpawned, isFalse);
    });

    test('集结结束前不出怪，倒计时结束后按时间表释放', () {
      final director = WaveDirector(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
      )..begin(1, 100);

      expect(director.takeDue(100), isEmpty);
      director.tick(1.6);
      expect(director.waveBreak, lessThanOrEqualTo(0));

      final before = director.pendingSpawns;
      final due = director.takeDue(101.8);
      expect(due, isNotEmpty);
      expect(due.first.at, lessThanOrEqualTo(0.3 + 1e-9));
      expect(director.pendingSpawns, before - due.length);
    });

    test('连续取刷怪指令复用同一缓冲，不逐次分配列表', () {
      final director = WaveDirector(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
      )..begin(1, 100);
      final first = director.takeDue(101.8);
      expect(first, isNotEmpty);
      final second = director.takeDue(200);
      expect(second, isNotEmpty);
      expect(identical(first, second), isTrue);
      expect(director.takeDue(200), isEmpty);
    });

    test('头目波次延长集结并给出警告', () {
      final director = WaveDirector(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
      );

      expect(director.begin(5, 0), BattleCue.boss);
      expect(director.waveBreak, WaveDirector.bossBreak);
      expect(director.bossWarning, isTrue);
      expect(director.announcement, '警告 · 九七式指挥车 接近');
      expect(director.phaseBrief, '头目正在逼近');
      expect(director.plan?.boss, isTrue);
    });

    test('重置后回到未开局状态', () {
      final director = WaveDirector(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
      )..begin(2, 10);
      director.reset();

      expect(director.wave, 0);
      expect(director.plan, isNull);
      expect(director.waveBreak, 0);
      expect(director.announcing, isFalse);
      expect(director.pendingSpawns, 0);
      expect(director.allSpawned, isTrue);
      expect(director.phaseBrief, '敌军集结中');
    });
  });

  test('无尽模式每五波安排头目', () {
    final director = WaveDirector(
      mode: BattleMode.endless,
      difficulty: Difficulty.veteran,
      random: math.Random(5),
    );

    expect(director.waveCount, 0);
    expect(director.begin(4, 0), BattleCue.wave);
    expect(director.boss, isFalse);
    expect(director.begin(5, 0), BattleCue.boss);
    expect(director.boss, isTrue);
    expect(director.hpMultiplier, greaterThan(1));
  });
}
