import 'dart:ui';

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/cover_field.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

CoverWall wallAt(double x, double y) => CoverWall(x: x, y: y);

BattleBullet shotAt(CoverWall cover, {double damage = 20}) {
  final bullet = BattleBullet(
    x: cover.x,
    y: cover.top + 2,
    vx: 0,
    vy: 120,
    damage: damage,
    radius: 3,
    fromPlayer: false,
    color: const Color(0xFF000000),
  );
  bullet.prevY = cover.top - 10;
  return bullet;
}

void main() {
  group('工事布置', () {
    test('开局布置两处工事，位于战场两侧', () {
      final field = CoverField()..layStarting();
      expect(field.walls, hasLength(2));
      expect(field.count, 2);
      expect(CoverField.limit, kCoverMax);
      expect(field.walls.first.x, lessThan(Field.width / 2));
      expect(field.walls.last.x, greaterThan(Field.width / 2));
    });

    test('重叠位置不能再放工事，空位可以', () {
      final field = CoverField()..layStarting();
      final first = field.walls.first;
      expect(field.place(wallAt(first.x + 4, first.y)), isFalse);
      expect(field.count, 2);
      expect(field.place(wallAt(150, 300)), isTrue);
      expect(field.count, 3);
    });

    test('清理后为空', () {
      final field = CoverField()..layStarting();
      field.clear();
      expect(field.walls, isEmpty);
    });
  });

  group('掩护与拦截', () {
    test('只有蹲在工事后方一小段距离内才算掩护', () {
      final field = CoverField()..layStarting();
      final cover = field.walls.first;
      expect(field.shelteredAt(cover.x, cover.y + 20), isTrue);
      expect(field.shelteredAt(cover.x, cover.y - 20), isFalse);
      expect(
        field.shelteredAt(cover.x + kCoverHalfWidth + 40, cover.y + 20),
        isFalse,
      );
      expect(
        field.shelteredAt(cover.x, cover.y + kCoverShelterRange + 10),
        isFalse,
      );
    });

    test('敌军子弹撞上沙袋会扣血，未命中返回 null', () {
      final field = CoverField()..layStarting();
      final cover = field.walls.first;
      final bullet = shotAt(cover);
      final hp = cover.hp;
      final hit = field.absorb(bullet);
      expect(hit, same(cover));
      expect(cover.hp, lessThan(hp));
      expect(cover.shake, 1);

      final missed = BattleBullet(
        x: cover.x + kCoverHalfWidth + 30,
        y: cover.top + 2,
        vx: 0,
        vy: 120,
        damage: 20,
        radius: 3,
        fromPlayer: false,
        color: const Color(0xFF000000),
      )..prevY = cover.top - 10;
      expect(field.absorb(missed), isNull);
    });

    test('步兵走到工事前会被挡住，挖掘会掉血', () {
      final field = CoverField()..layStarting();
      final cover = field.walls.first;
      final blocking = field.blockingAt(cover.x, cover.top);
      expect(blocking, same(cover));
      expect(field.blockingAt(cover.x, cover.top - 40), isNull);
      final hp = cover.hp;
      expect(field.gnaw(cover, 0.5), same(cover));
      expect(cover.hp, lessThan(hp));
    });

    test('爆炸只波及范围内的工事', () {
      final field = CoverField()..layStarting();
      final left = field.walls.first;
      final right = field.walls.last;
      final leftHp = left.hp;
      final rightHp = right.hp;
      field.blast(left.x, left.y, 10, 30);
      expect(left.hp, leftHp - 30);
      expect(right.hp, rightHp);
    });
  });

  group('寿命', () {
    test('血量耗尽或寿命到期后拆除并回调一次', () {
      final field = CoverField()..layStarting();
      final ruined = <CoverWall>[];
      field.walls.first.hp = 0;
      field.tick(1 / 60, onRuined: ruined.add);
      expect(field.count, 1);
      expect(ruined, hasLength(1));

      field.walls.first.life = 0.01;
      field.tick(0.02, onRuined: ruined.add);
      expect(field.walls, isEmpty);
      expect(ruined, hasLength(2));
    });

    test('受击抖动随时间衰减', () {
      final field = CoverField()..layStarting();
      final cover = field.walls.first..shake = 1;
      field.tick(0.1, onRuined: (_) {});
      expect(cover.shake, lessThan(1));
      field.tick(1, onRuined: (_) {});
      expect(cover.shake, 0);
    });
  });
}
