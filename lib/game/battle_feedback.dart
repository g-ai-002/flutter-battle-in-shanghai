import 'dart:math' as math;
import 'dart:ui' show Color;

import 'battle_config.dart';
import 'entities.dart';

/// 战场反馈层：特效、浮动文字、粒子与屏幕抖动。
///
/// 这里只做「演出」记账，不参与命中与数值判定；战斗模拟在规则节点调用
/// 快捷方法，渲染层直接读取列表。粒子来自对象池，满屏爆炸不会持续分配。
class BattleFeedback {
  BattleFeedback({math.Random? random}) : _random = random ?? math.Random();

  /// 同时存在的粒子上限，保证满屏爆炸时的绘制量可控。
  static const int maxParticles = 180;
  static const int _maxPooledParticles = 96;

  final math.Random _random;

  final List<BattleEffect> effects = [];
  final List<ScorePopup> popups = [];
  final List<Particle> particles = [];

  /// 待消费的播放提示，控制器取走后清空。
  final List<BattleCue> cues = [];

  final List<Particle> _pool = [];

  /// 镜头抖动强度，渲染层按它偏移画面。
  double shake = 0;

  /// 推进特效、浮动文字、粒子与抖动。
  void tick(double dt) {
    for (final effect in effects) {
      effect.age += dt;
    }
    effects.removeWhere((effect) => effect.done);
    for (final popup in popups) {
      popup.age += dt;
    }
    popups.removeWhere((popup) => popup.done);
    for (final particle in particles) {
      particle.life -= dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= 0.98;
      particle.vy += 42 * dt;
    }
    for (var i = particles.length - 1; i >= 0; i--) {
      if (particles[i].life > 0) continue;
      _recycle(particles.removeAt(i));
    }
    if (shake > 0) shake = math.max(0, shake - dt * 22);
  }

  void cue(BattleCue value) => cues.add(value);

  /// 抖动只增不减，避免小爆炸盖掉正在进行的大爆炸。
  void kick(double value) {
    if (value > shake) shake = value;
  }

  void effect(
    EffectKind kind,
    double x,
    double y, {
    double radius = 24,
    double duration = 0.45,
  }) => effects.add(
    BattleEffect(kind: kind, x: x, y: y, radius: radius, duration: duration),
  );

  void popup(String text, double x, double y, Color color) =>
      popups.add(ScorePopup(text: text, x: x, y: y, color: color));

  /// 爆炸/碎屑粒子：池里取、上限封顶，超出预算的部分直接丢弃。
  void burst(double x, double y, double radius, int count) {
    final budget = math.min(count, maxParticles - particles.length);
    for (var i = 0; i < budget; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 24 + _random.nextDouble() * radius * 3.2;
      final particle = _pool.isNotEmpty ? _pool.removeLast() : Particle();
      particle.reset(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 12,
        life: 0.35 + _random.nextDouble() * 0.45,
        color: _random.nextBool()
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF6B3D),
        size: 1.4 + _random.nextDouble() * 2.2,
      );
      particles.add(particle);
    }
  }

  void clear() {
    effects.clear();
    popups.clear();
    for (final particle in particles) {
      _recycle(particle);
    }
    particles.clear();
    cues.clear();
    shake = 0;
  }

  void _recycle(Particle particle) {
    if (_pool.length < _maxPooledParticles) _pool.add(particle);
  }
}
