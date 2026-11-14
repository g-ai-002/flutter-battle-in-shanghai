import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import 'paint_kit.dart';

/// 地面单位的程序化剪影：士兵、装甲车与头目战车。
///
/// 单位以中心为原点、按半径缩放，因此同一套画法适配手机与桌面。

/// 士兵外观：配色、步伐与手里的克制装备。
class SoldierLook {
  /// 依次为军装、钢盔、领巾配色与步伐频率。
  const SoldierLook(
    this.uniform,
    this.helmet,
    this.accent,
    this.walk, {
    this.aimAtPlayer = true,
    this.shield = false,
    this.blade = false,
  });

  final Color uniform, helmet, accent;
  final double walk;
  final bool aimAtPlayer, shield, blade;
}

/// 玩家外观：与敌军同剪影，换一套军装与领巾，枪口默认朝上。
const SoldierLook playerLook = SoldierLook(
  Color(0xFF6F7F5E),
  Color(0xFF4A5540),
  Color(0xFFC2452F),
  0,
  aimAtPlayer: false,
);

/// 敌军士兵外观表：步兵低头推进，其余兵种把枪口转向玩家。
const Map<EnemyKind, SoldierLook> enemyLooks = {
  EnemyKind.infantry: SoldierLook(
    Color(0xFF595142),
    Color(0xFF403A30),
    Color(0xFF9C5A2A),
    7,
    aimAtPlayer: false,
  ),
  EnemyKind.rifleman: SoldierLook(
    Color(0xFF4C473C),
    Color(0xFF363229),
    Color(0xFF7A2A20),
    2,
  ),
  EnemyKind.grenadier: SoldierLook(
    Color(0xFF5C543D),
    Color(0xFF453E30),
    Color(0xFF9C5A2A),
    2.4,
  ),
  EnemyKind.raider: SoldierLook(
    Color(0xFF54412F),
    Color(0xFF3A2C20),
    Color(0xFFC2452F),
    9,
    blade: true,
  ),
  EnemyKind.shield: SoldierLook(
    Color(0xFF4E5341),
    Color(0xFF403A30),
    Color(0xFF9C5A2A),
    7,
    shield: true,
  ),
};

/// 玩家与敌军共用的士兵剪影。
void paintSoldier(
  Canvas canvas,
  Offset center, {
  required double radius,
  required Color uniform,
  required Color helmet,
  Color accent = const Color(0xFFB5432C),
  double aim = -math.pi / 2,
  double walk = 0,
  double flash = 0,
  bool hostile = false,
  bool shield = false,
  bool blade = false,
  SoldierLayer layer = SoldierLayer.all,
}) {
  final s = radius / 9;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (layer != SoldierLayer.over) {
    // 地面阴影
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 5 * s), width: 17 * s, height: 8 * s),
      fillPaint(const Color(0x66000000)),
    );
    // 双腿
    final legSwing = math.sin(walk) * 2.2 * s;
    final legPaint = fillPaint(uniform.withValues(alpha: 0.9));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-5 * s + legSwing, 2 * s, 4.2 * s, 8 * s),
        Radius.circular(1.8 * s),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.2 * s - legSwing, 2 * s, 4.2 * s, 8 * s),
        Radius.circular(1.8 * s),
      ),
      legPaint,
    );
    _paintSoldierUnder(canvas, s, uniform, accent);
  }
  if (layer == SoldierLayer.all) _paintGun(canvas, s, aim);
  if (layer != SoldierLayer.under) {
    _paintSoldierOver(canvas, s, helmet, hostile, shield, blade);
  }
  if (layer == SoldierLayer.all && flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      9 * s,
      fillPaint(Colors.white.withValues(alpha: flash * 0.5)),
    );
  }
  canvas.restore();
}

/// 士兵分段：下半身穿插枪械，上半身压在枪之上，缓存与直接绘制共用。
enum SoldierLayer { all, under, over }

void _paintSoldierUnder(Canvas canvas, double s, Color uniform, Color accent) {
  // 背包
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-4.6 * s, -3.4 * s, 9.2 * s, 7 * s),
      Radius.circular(2.4 * s),
    ),
    fillPaint(const Color(0xFF3F3526)),
  );
  // 躯干
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-5.4 * s, -4.6 * s, 10.8 * s, 10.4 * s),
      Radius.circular(3.6 * s),
    ),
    fillPaint(uniform),
  );
  // 肩章
  canvas.drawCircle(Offset(-4.4 * s, -1.2 * s), 1.9 * s, fillPaint(accent));
}

void _paintSoldierOver(
  Canvas canvas,
  double s,
  Color helmet,
  bool hostile,
  bool shield,
  bool blade,
) {
  // 钢盔
  canvas.drawCircle(Offset(0, -5.2 * s), 4.6 * s, fillPaint(helmet));
  canvas.drawArc(
    Rect.fromCircle(center: Offset(0, -5.2 * s), radius: 4.8 * s),
    math.pi,
    math.pi,
    false,
    strokePaint(helmet.withValues(alpha: 0.7), 1.2 * s),
  );
  // 敌我识别：敌军暗红领巾
  if (hostile) {
    canvas.drawRect(
      Rect.fromLTWH(-1.6 * s, 0.4 * s, 3.2 * s, 1.4 * s),
      fillPaint(const Color(0xFF8E2F23)),
    );
  }
  // 刀锋兵的白刃：朝前下方斜举，和步枪形成区分。
  if (blade) {
    canvas.drawLine(
      Offset(4.2 * s, 1.2 * s),
      Offset(9 * s, 9.6 * s),
      strokePaint(const Color(0xFFD7DEE2), 1.5 * s)
        ..strokeCap = StrokeCap.round,
    );
  }
  // 盾牌兵的钢板：挡在身体正面，子弹打上去会被削掉大半。
  if (shield) {
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(-7.4 * s, 0.2 * s, 14.8 * s, 12.4 * s),
      Radius.circular(3.4 * s),
    );
    canvas.drawRRect(plate, fillPaint(const Color(0xFF6E7566)));
    canvas.drawRRect(plate, strokePaint(const Color(0xFF9AA38E), 1.1 * s));
    for (final x in [-4.2, 0.0, 4.2]) {
      canvas.drawCircle(
        Offset(x * s, 3.6 * s),
        0.9 * s,
        fillPaint(const Color(0xFF3C4136)),
      );
    }
  }
}

/// 士兵精灵的外接范围与基准半径：下半身与上半身分开录制，枪夹在中间。
const double kSoldierArtRadius = 9;
const Rect kSoldierUnderBounds = Rect.fromLTRB(-9, -5, 9, 11);
const Rect kSoldierOverBounds = Rect.fromLTRB(-9, -11.5, 10.5, 14);

/// 步枪与背带：单独绘制，精灵缓存才能在枪口方向变化时继续复用。
void paintSoldierGun(
  Canvas canvas,
  Offset center, {
  required double radius,
  double aim = -math.pi / 2,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  _paintGun(canvas, radius / 9, aim);
  canvas.restore();
}

void _paintGun(Canvas canvas, double s, double aim) {
  final gunStart = Offset(math.cos(aim) * 3 * s, math.sin(aim) * 3 * s);
  canvas.drawLine(
    gunStart,
    Offset(math.cos(aim) * 15 * s, math.sin(aim) * 15 * s),
    strokePaint(const Color(0xFF1A1512), 2.2 * s)..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(
      gunStart.dx + math.cos(aim + 1.2) * 3,
      gunStart.dy + math.sin(aim + 1.2) * 3,
    ),
    Offset(
      gunStart.dx + math.cos(aim - 1.4) * 2,
      gunStart.dy + math.sin(aim - 1.4) * 3,
    ),
    strokePaint(const Color(0xFF1A1512), 1.6 * s),
  );
}

/// 受击白闪：铺在整个士兵之上，精灵缓存外单独绘制。
void paintSoldierFlash(
  Canvas canvas,
  Offset center, {
  required double radius,
  double flash = 0,
}) {
  if (flash <= 0) return;
  canvas.drawCircle(
    center,
    radius,
    fillPaint(Colors.white.withValues(alpha: flash * 0.5)),
  );
}

/// 装甲车精灵的外接范围与基准半径：位图按这个矩形录制，绘制时按半径缩放。
/// 矩形比车体各边多留 1 个单位，避免贴图边缘被过滤采样切掉抗锯齿。
const double kArmoredCarArtRadius = 20;
const Rect kArmoredCarArtBounds = Rect.fromLTRB(-22, -14.5, 22, 15.5);

/// 头目精灵的外接范围与基准半径。
const double kBossArtRadius = 30;
const Rect kBossArtBounds = Rect.fromLTRB(-34, -24, 34, 24.5);

/// 装甲车车身：阴影、履带、车轮、车身与炮塔，整局不变。
void paintArmoredCarBody(
  Canvas canvas,
  Offset center, {
  required double radius,
}) {
  final s = radius / 20;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, 6 * s), width: 40 * s, height: 14 * s),
    fillPaint(const Color(0x66000000)),
  );
  // 履带
  final track = fillPaint(const Color(0xFF1F1B16));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-20 * s, -12 * s, 40 * s, 7 * s),
      Radius.circular(3 * s),
    ),
    track,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-20 * s, 5 * s, 40 * s, 7 * s),
      Radius.circular(3 * s),
    ),
    track,
  );
  // 车轮纹路
  for (var i = -3; i <= 3; i++) {
    final x = i * 5.2 * s;
    for (final y in [-8.5, 8.5]) {
      canvas.drawCircle(
        Offset(x, y * s),
        1.5 * s,
        fillPaint(const Color(0xFF57493A)),
      );
    }
  }
  // 车身
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-16 * s, -11 * s, 32 * s, 22 * s),
    Radius.circular(4 * s),
  );
  canvas.drawRRect(hull, fillPaint(const Color(0xFF4B4A3A)));
  canvas.drawRRect(hull, strokePaint(const Color(0xFF6B6A54), 1 * s));
  // 装甲板
  canvas.drawRect(
    Rect.fromLTWH(-16 * s, -2 * s, 7 * s, 4 * s),
    fillPaint(const Color(0xFF3A392C)),
  );
  canvas.drawRect(
    Rect.fromLTWH(9 * s, -2 * s, 7 * s, 4 * s),
    fillPaint(const Color(0xFF3A392C)),
  );
  // 炮塔
  canvas.drawCircle(
    Offset(0, -1 * s),
    6.4 * s,
    fillPaint(const Color(0xFF5C5B47)),
  );
  canvas.drawRect(
    Rect.fromLTWH(-1.2 * s, 3 * s, 2.4 * s, 12 * s),
    fillPaint(const Color(0xFF2E2D24)),
  );
  canvas.restore();
}

/// 车灯：缓慢明灭，单独绘制以免整台车逐帧重画。
void paintArmoredCarLamp(
  Canvas canvas, {
  required Offset center,
  required double radius,
  double time = 0,
}) {
  final s = radius / 20;
  final lamp = 0.4 + 0.25 * math.sin(time * 5);
  canvas.drawCircle(
    Offset(center.dx - 13 * s, center.dy + 9 * s),
    1.5 * s,
    fillPaint(const Color(0xFFFFD9A0).withValues(alpha: lamp)),
  );
}

/// 受击白闪：铺在整车之上。
void paintArmoredCarFlash(
  Canvas canvas, {
  required Offset center,
  required double radius,
  double flash = 0,
}) {
  if (flash <= 0) return;
  final s = radius / 20;
  canvas.drawCircle(
    center,
    20 * s,
    fillPaint(Colors.white.withValues(alpha: flash * 0.35)),
  );
}

/// 头目车身：履带、车轮、铆钉与双炮塔，整局不变。
void paintBossBody(Canvas canvas, Offset center, {required double radius}) {
  final s = radius / 30;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, 8 * s), width: 64 * s, height: 22 * s),
    fillPaint(const Color(0x77000000)),
  );
  for (final y in [-22.0, 12.0]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-32 * s, y * s, 64 * s, 10 * s),
        Radius.circular(4 * s),
      ),
      fillPaint(const Color(0xFF1B1712)),
    );
    for (var i = -5; i <= 5; i++) {
      for (final offset in [y + 2.5, y + 7.5]) {
        canvas.drawCircle(
          Offset(i * 6 * s, offset * s),
          1.6 * s,
          fillPaint(const Color(0xFF4A3E30)),
        );
      }
    }
  }
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-26 * s, -18 * s, 52 * s, 36 * s),
    Radius.circular(6 * s),
  );
  canvas.drawRRect(hull, fillPaint(const Color(0xFF4A4636)));
  canvas.drawRRect(hull, strokePaint(const Color(0xFF7C755A), 1.4 * s));
  // 铆钉
  for (var i = -3; i <= 3; i++) {
    for (final y in [-14.0, 14.0]) {
      canvas.drawCircle(
        Offset(i * 7 * s, y * s),
        1.3 * s,
        fillPaint(const Color(0xFF8B8263)),
      );
    }
  }
  // 双炮塔
  for (final x in [-11.0, 11.0]) {
    canvas.drawCircle(
      Offset(x * s, -2 * s),
      8 * s,
      fillPaint(const Color(0xFF5B5744)),
    );
    canvas.drawRect(
      Rect.fromLTWH((x - 1.6) * s, 4 * s, 3.2 * s, 18 * s),
      fillPaint(const Color(0xFF302C23)),
    );
  }
  canvas.restore();
}

/// 头目的警示灯：闪烁节奏单独绘制。
void paintBossBeacon(
  Canvas canvas, {
  required Offset center,
  required double radius,
  double time = 0,
}) {
  final s = radius / 30;
  final blink = 0.45 + 0.4 * math.sin(time * 6).abs();
  canvas.drawCircle(
    Offset(center.dx, center.dy - 14 * s),
    2.6 * s,
    fillPaint(const Color(0xFFFF5A3C).withValues(alpha: blink)),
  );
}

/// 头目受击白闪。
void paintBossFlash(
  Canvas canvas, {
  required Offset center,
  required double radius,
  double flash = 0,
}) {
  if (flash <= 0) return;
  final s = radius / 30;
  canvas.drawCircle(
    center,
    30 * s,
    fillPaint(Colors.white.withValues(alpha: flash * 0.3)),
  );
}
