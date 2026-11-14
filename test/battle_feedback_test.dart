import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_feedback.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('特效计时', () {
    test('特效与浮动文字到期后自动移除', () {
      final feedback = BattleFeedback(random: math.Random(1));
      feedback.effect(EffectKind.hit, 10, 20, duration: 0.2);
      feedback.popup('+10', 10, 20, const Color(0xFFFFD166));
      expect(feedback.effects, hasLength(1));
      expect(feedback.popups, hasLength(1));

      feedback.tick(0.1);
      expect(feedback.effects, hasLength(1));
      feedback.tick(0.15);
      expect(feedback.effects, isEmpty);
      expect(feedback.popups, hasLength(1));
      feedback.tick(1);
      expect(feedback.popups, isEmpty);
    });

    test('抖动取最大值并按时间衰减', () {
      final feedback = BattleFeedback(random: math.Random(2));
      feedback.kick(8);
      feedback.kick(3);
      expect(feedback.shake, 8);
      feedback.tick(0.2);
      expect(feedback.shake, lessThan(8));
      feedback.tick(1);
      expect(feedback.shake, 0);
    });

    test('清理会重置提示、特效与抖动', () {
      final feedback = BattleFeedback(random: math.Random(3));
      feedback.cue(BattleCue.hit);
      feedback.effect(EffectKind.hit, 1, 2);
      feedback.burst(10, 10, 20, 4);
      feedback.kick(9);
      feedback.clear();
      expect(feedback.cues, isEmpty);
      expect(feedback.effects, isEmpty);
      expect(feedback.particles, isEmpty);
      expect(feedback.shake, 0);
    });
  });

  group('粒子池', () {
    test('粒子数量不超过上限', () {
      final feedback = BattleFeedback(random: math.Random(4));
      feedback.burst(150, 150, 40, 300);
      expect(feedback.particles.length, BattleFeedback.maxParticles);

      feedback.burst(150, 150, 40, 50);
      expect(feedback.particles.length, BattleFeedback.maxParticles);
    });

    test('粒子寿命耗尽后回收复用，不持续分配', () {
      final feedback = BattleFeedback(random: math.Random(5));
      feedback.burst(150, 150, 30, 8);
      final spawned = Set<Particle>.identity()..addAll(feedback.particles);
      expect(spawned, hasLength(8));

      feedback.tick(2);
      expect(feedback.particles, isEmpty);

      feedback.burst(150, 150, 30, 8);
      expect(feedback.particles.any(spawned.contains), isTrue);
    });

    test('粒子受重力下坠并随时间消散', () {
      final feedback = BattleFeedback(random: math.Random(6));
      feedback.burst(100, 100, 0, 1);
      final particle = feedback.particles.single;
      final vy = particle.vy;
      feedback.tick(0.1);
      expect(particle.vy, greaterThan(vy));
      expect(particle.life, lessThan(particle.maxLife));
    });

    test('中间粒子到期时原地压缩，存活粒子顺序不变', () {
      final feedback = BattleFeedback(random: math.Random(7));
      feedback.burst(100, 100, 10, 8);
      final before = List<Particle>.of(feedback.particles);
      before[1].life = 0;
      before[3].life = 0;
      feedback.tick(0);

      expect(feedback.particles, hasLength(6));
      expect(feedback.particles, isNot(contains(before[1])));
      expect(feedback.particles, isNot(contains(before[3])));
      expect(
        feedback.particles.map((item) => before.indexOf(item)),
        orderedEquals([0, 2, 4, 5, 6, 7]),
      );
    });
  });
}
