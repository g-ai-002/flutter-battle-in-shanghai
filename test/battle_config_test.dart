import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('临时武器有持续时间，手枪常驻', () {
    expect(WeaponSpec.specs[WeaponKind.pistol]!.duration, 0);
    expect(WeaponSpec.specs[WeaponKind.smg]!.duration, greaterThan(0));
    expect(WeaponSpec.specs[WeaponKind.shotgun]!.duration, greaterThan(0));
    expect(WeaponSpec.specs[WeaponKind.shotgun]!.pellets, 5);
    expect(
      WeaponSpec.specs[WeaponKind.smg]!.interval,
      lessThan(WeaponSpec.specs[WeaponKind.pistol]!.interval),
    );
  });

  test('难度与刷新率在未知取值时回退到默认', () {
    expect(Difficulty.byName(null), Difficulty.veteran);
    expect(Difficulty.byName('unknown'), Difficulty.veteran);
    expect(Difficulty.byName(Difficulty.ace.name), Difficulty.ace);
    expect(Difficulty.ace.hpScale, greaterThan(Difficulty.recruit.hpScale));
    expect(Difficulty.ace.paceScale, lessThan(Difficulty.recruit.paceScale));
  });

  test('精英单位会被标记出来并拥有更高分值', () {
    expect(EnemySpec.specs[EnemyKind.armoredCar]!.elite, isTrue);
    expect(EnemySpec.specs[EnemyKind.boss]!.elite, isTrue);
    expect(EnemySpec.specs[EnemyKind.infantry]!.elite, isFalse);
    expect(
      EnemySpec.specs[EnemyKind.boss]!.score,
      greaterThan(EnemySpec.specs[EnemyKind.armoredCar]!.score),
    );
  });

  test('玩家初始生命与战场边界匹配', () {
    final player = PlayerSoldier(x: 150, y: 340);
    expect(player.hp, kPlayerMaxHp);
    expect(player.hpRatio, 1);
    player.hp = 50;
    expect(player.hpRatio, closeTo(0.5, 1e-9));
    player.hp = 0;
    expect(player.hpRatio, 0);
  });

  test('补给类型齐备且各有名称', () {
    expect(PickupKind.values, hasLength(3));
    for (final kind in PickupKind.values) {
      expect(kind.label, isNotEmpty);
    }
  });
}
