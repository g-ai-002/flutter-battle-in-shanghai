import 'dart:math' as math;

import '../utils/constants.dart';
import 'battle_config.dart';
import 'combat_math.dart';
import 'entities.dart';

/// 工事（沙袋掩体）的布置、寿命与拦截规则。
///
/// 只管沙袋自身的状态与几何：挡子弹、被步兵挖掘、被爆炸波及、到期拆除。
/// 视觉特效用回调交给战斗模拟统一记账，方便单测直接验证规则。
class CoverField {
  /// 同时存在的工事上限。
  static const int limit = kCoverMax;

  final List<CoverWall> walls = [];

  int get count => walls.length;

  /// 开局的两处沙袋，让玩家一上来就有掩体可用。
  void layStarting() {
    walls
      ..clear()
      ..add(CoverWall(x: 78, y: 262))
      ..add(CoverWall(x: Field.width - 78, y: 262));
  }

  void clear() => walls.clear();

  /// 玩家是否蹲在某段工事后方的掩护范围内。
  bool shelteredAt(double x, double y) {
    for (final cover in walls) {
      if ((x - cover.x).abs() > kCoverHalfWidth + 10) continue;
      final behind = y - cover.y;
      if (behind < 0 || behind > kCoverShelterRange) continue;
      return true;
    }
    return false;
  }

  /// 指定位置前方有没有工事挡住去路。
  CoverWall? blockingAt(double x, double y) {
    for (final cover in walls) {
      if ((x - cover.x).abs() > kCoverHalfWidth + 4) continue;
      if (y < cover.top - 4 || y > cover.bottom + 12) continue;
      return cover;
    }
    return null;
  }

  /// 放置一段新工事；与已有工事重叠时拒绝。
  bool place(CoverWall wall) {
    for (final cover in walls) {
      if ((cover.x - wall.x).abs() < kCoverHalfWidth &&
          (cover.y - wall.y).abs() < 26) {
        return false;
      }
    }
    walls.add(wall);
    return true;
  }

  /// 推进寿命与受击抖动，塌掉的工事通过 [onRuined] 交回调用方处理。
  void tick(double dt, {required void Function(CoverWall) onRuined}) {
    for (final cover in walls) {
      cover.life -= dt;
      cover.shake = math.max(0, cover.shake - dt * 3.2);
    }
    for (var i = walls.length - 1; i >= 0; i--) {
      final cover = walls[i];
      if (!cover.ruined) continue;
      walls.removeAt(i);
      onRuined(cover);
    }
  }

  /// 步兵贴在工事前挖掘，返回被挖的那段工事。
  CoverWall? gnaw(CoverWall cover, double dt) {
    if (!walls.contains(cover)) return null;
    cover.hp -= kCoverGnawDamage * dt;
    cover.shake = 1;
    return cover;
  }

  /// 敌军子弹撞上沙袋：扣工事血量并返回命中的那段，己方子弹不会调用这里。
  CoverWall? absorb(BattleBullet bullet) {
    for (final cover in walls) {
      final hit = segmentHitsBox(
        bullet.prevX,
        bullet.prevY,
        bullet.x,
        bullet.y,
        cover.left,
        cover.top,
        cover.right,
        cover.bottom,
      );
      if (!hit) continue;
      cover.hp -= bullet.damage;
      cover.shake = 1;
      return cover;
    }
    return null;
  }

  /// 爆炸波及：范围内的工事一起掉血。
  void blast(double x, double y, double radius, double damage) {
    for (final cover in walls) {
      if (!circleOverlap(x, y, cover.x, cover.y, radius + kCoverHalfWidth)) {
        continue;
      }
      cover.hp -= damage;
      cover.shake = 1;
    }
  }
}
