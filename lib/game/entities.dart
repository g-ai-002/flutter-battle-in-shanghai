import 'dart:math' as math;
import 'dart:ui';

import 'battle_config.dart';

/// 一次战斗的生命周期。
enum BattleStatus { ready, running, paused, won, lost }

/// 玩家角色：守在南岸街垒后的抵抗军士兵。
class PlayerSoldier {
  PlayerSoldier({required this.x, required this.y});

  double x;
  double y;
  double hp = kPlayerMaxHp;
  double shieldUntil = 0;
  double invulnerableUntil = 0;
  WeaponKind weapon = WeaponKind.pistol;
  double weaponUntil = 0;
  double fireCooldown = 0;
  double grenadeReadyAt = 0;
  double coverReadyAt = 0;
  double airstrikeReadyAt = 0;

  /// 枪口闪光剩余时间，仅用于渲染。
  double muzzle = 0;

  WeaponSpec get weaponSpec => WeaponSpec.specs[weapon]!;

  double get hpRatio => (hp / kPlayerMaxHp).clamp(0.0, 1.0);
}

/// 敌军单位，行为由兵种与 [holdY] 决定。
class EnemyUnit {
  EnemyUnit({
    required this.kind,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.holdY,
  });

  final EnemyKind kind;
  double x;
  double y;
  double hp;
  final double maxHp;
  final double holdY;

  /// 攻击冷却计时。
  double attackTimer = 0;

  /// 通用计时，用于步伐摆动与头目弹幕轮换。
  double timer = 0;
  int pattern = 0;

  /// 受击白闪剩余时间。
  double hitFlash = 0;

  /// 闪现标志：召回的步兵入场时短暂无敌，避免一出现就被扫掉。
  double spawnGuard = 0.45;
  double bobSeed = 0;

  bool dead = false;
  bool escaped = false;

  EnemySpec get spec => EnemySpec.specs[kind]!;
  bool get isBoss => kind == EnemyKind.boss;
  bool get isElite => spec.elite;
  double get hpRatio => (hp / maxHp).clamp(0.0, 1.0);

  bool get stopped => holdY > 0 && y >= holdY;
}

/// 子弹：玩家与敌军共用，方向由速度决定。
class BattleBullet {
  BattleBullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.radius,
    required this.fromPlayer,
    required this.color,
  }) : prevX = x,
       prevY = y,
       // 尾焰颜色在生成时算好，子弹通常要被绘制二十来帧。
       trailColor = color.withValues(alpha: fromPlayer ? 0.4 : 0.35);

  double x;
  double y;

  /// 上一逻辑步的位置：30Hz 下单步位移可能超过子弹与敌军的半径和，
  /// 碰撞必须用线段判定才不会穿模。
  double prevX;
  double prevY;
  final double vx;
  final double vy;
  double damage;
  final double radius;
  final bool fromPlayer;
  final Color color;

  /// 尾焰颜色：生成时一次性换算好，渲染层直接使用。
  final Color trailColor;

  double get angle => math.atan2(vy, vx);
}

/// 手榴弹与空投炸弹：抛物线落点爆炸，落地前有影子提示。
enum HazardKind { grenade, bomb }

class GrenadeHazard {
  GrenadeHazard({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.duration,
    required this.damage,
    required this.radius,
    required this.fromPlayer,
    this.kind = HazardKind.grenade,
  });

  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final double duration;
  double damage;
  final double radius;
  final bool fromPlayer;
  final HazardKind kind;
  double elapsed = 0;

  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// 抛物线高度，用于渲染。
  double get lift => math.sin(progress * math.pi) * 34;

  double get x => fromX + (toX - fromX) * progress;
  double get y => fromY + (toY - fromY) * progress;
}

/// 工事：玩家布置的沙袋墙，挡住敌军子弹，步兵贴上来会一点点挖开它。
class CoverWall {
  CoverWall({required this.x, required this.y, this.hp = kCoverHp})
    : maxHp = hp,
      life = kCoverLife,
      left = x - kCoverHalfWidth,
      right = x + kCoverHalfWidth,
      top = y - kCoverHeight / 2,
      bottom = y + kCoverHeight / 2;

  final double x;
  final double y;
  final double maxHp;
  final double left;
  final double right;
  final double top;
  final double bottom;

  double hp;
  double life;

  /// 受击抖动，仅用于渲染。
  double shake = 0;

  double get hpRatio => (hp / maxHp).clamp(0.0, 1.0);

  bool get ruined => hp <= 0 || life <= 0;
}


/// 可拾取的补给。
class PickupItem {
  PickupItem({required this.kind, required this.x, required this.y});

  final PickupKind kind;
  final double x;
  double y;
  double life = kPickupLife;
  double bob = 0;
}

enum EffectKind {
  explosion,
  hit,
  muzzle,
  pickup,
  shieldBreak,
  bossDown,
  boom,
  dust,
  plane,
}

/// 一次性视觉特效，渲染层按进度自行绘制。
class BattleEffect {
  BattleEffect({
    required this.kind,
    required this.x,
    required this.y,
    this.radius = 24,
    this.duration = 0.45,
  });

  final EffectKind kind;
  final double x;
  final double y;
  final double radius;
  final double duration;
  double age = 0;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get done => age >= duration;
}

/// 击杀/补给时的浮动文字。
class ScorePopup {
  ScorePopup({required this.text, required this.x, required this.y, required this.color});

  final String text;
  final double x;
  final double y;
  final Color color;
  double age = 0;
  static const double duration = 0.9;

  bool get done => age >= duration;
}

/// 火花与碎屑粒子。字段可变以支持对象池复用，避免爆炸时反复分配。
class Particle {
  Particle({
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.life = 0,
    this.maxLife = 1,
    this.color = const Color(0xFFFFB347),
    this.size = 1,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  double maxLife;
  Color color;
  double size;

  void reset({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required Color color,
    required double size,
  }) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.life = life;
    maxLife = life;
    this.color = color;
    this.size = size;
  }

  double get ratio => (life / maxLife).clamp(0.0, 1.0);
}
