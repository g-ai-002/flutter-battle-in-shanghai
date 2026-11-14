import 'dart:math' as math;

import 'battle_config.dart';
import 'battle_scenes.dart';
import 'wave_plan.dart';

/// 战役关卡的波次表：三处阵地各五波，越靠后的阵地敌军越硬。
///
/// 每处阵地单独成函数，随机数按阵地种子生成，因此同一关同一难度每次
/// 阵型完全一致；无尽模式的编排仍在 `wave_plan.dart`。
List<WavePlan> sceneWaves(
  BattleScene scene,
  Difficulty difficulty, {
  math.Random? random,
}) {
  final builder = WaveBuilder(
    difficulty: difficulty,
    random: random ?? math.Random(scene.seed),
  );
  return switch (scene) {
    BattleScene.zhabei => _zhabeiWaves(builder, scene.hpScale),
    BattleScene.bund => _bundWaves(builder, scene.hpScale),
    BattleScene.warehouse => _warehouseWaves(builder, scene.hpScale),
  };
}

/// 闸北：窄巷正面推进，两翼从街口包抄。
List<WavePlan> _zhabeiWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  builder.line(EnemyKind.infantry, 6, 0.2, 0.55);
  final waves = <WavePlan>[book.next(1, name: '前哨试探')];

  builder.line(EnemyKind.infantry, 3, 0.2, 0.5, fromX: 40, toX: 56);
  builder.line(EnemyKind.infantry, 3, 0.45, 0.5, fromX: 244, toX: 260);
  builder.line(
    EnemyKind.rifleman,
    2,
    2.6,
    1.0,
    fromX: 110,
    toX: 190,
    holdMin: 80,
    holdMax: 140,
  );
  builder.add(EnemyKind.raider, 3.2, 54);
  builder.add(EnemyKind.raider, 3.6, 246);
  waves.add(book.next(2, name: '两翼夹击'));

  builder.line(EnemyKind.infantry, 5, 0.6, 0.5, fromX: 60, toX: 240);
  builder.add(EnemyKind.shield, 0.8, 150);
  builder.line(
    EnemyKind.rifleman,
    4,
    0.3,
    0.8,
    fromX: 56,
    toX: 244,
    holdMin: 66,
    holdMax: 130,
  );
  builder.line(
    EnemyKind.grenadier,
    2,
    2.2,
    1.2,
    fromX: 96,
    toX: 204,
    holdMin: 100,
    holdMax: 150,
  );
  waves.add(book.next(3, name: '火力压制'));

  builder.line(EnemyKind.infantry, 6, 0.2, 0.42);
  builder.add(EnemyKind.armoredCar, 1.0, 92, holdY: 82);
  builder.add(EnemyKind.armoredCar, 2.4, 208, holdY: 82);
  builder.line(
    EnemyKind.rifleman,
    2,
    2.0,
    1.0,
    fromX: 60,
    toX: 240,
    holdMin: 72,
    holdMax: 120,
  );
  builder.line(
    EnemyKind.grenadier,
    2,
    3.4,
    1.3,
    fromX: 120,
    toX: 180,
    holdMin: 108,
    holdMax: 150,
  );
  waves.add(book.next(4, name: '装甲突袭'));

  builder.add(EnemyKind.infantry, 0.2, 60);
  builder.add(EnemyKind.rifleman, 0.6, 240, holdY: 96);
  builder.add(EnemyKind.infantry, 1.0, 240);
  builder.add(EnemyKind.grenadier, 1.4, 190, holdY: 118);
  builder.add(EnemyKind.raider, 0.8, 96);
  builder.add(EnemyKind.raider, 1.0, 204);
  builder.add(EnemyKind.boss, 2.6, 150, holdY: 78);
  waves.add(book.next(5, name: '头目决战', boss: true));
  return waves;
}

/// 外滩：江岸开阔，步兵散得更开，远处楼顶的枪手先发制人。
List<WavePlan> _bundWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  builder.line(EnemyKind.infantry, 7, 0.2, 0.45, fromX: 36, toX: 264);
  builder.add(EnemyKind.rifleman, 3.0, 150, holdY: 112);
  final waves = <WavePlan>[book.next(1, name: '江岸登陆')];

  builder.line(
    EnemyKind.rifleman,
    4,
    0.3,
    0.7,
    fromX: 52,
    toX: 248,
    holdMin: 64,
    holdMax: 108,
  );
  builder.line(
    EnemyKind.rifleman,
    2,
    2.4,
    1.1,
    fromX: 96,
    toX: 204,
    holdMin: 112,
    holdMax: 150,
  );
  builder.line(EnemyKind.infantry, 4, 0.6, 0.6, fromX: 70, toX: 230);
  waves.add(book.next(2, name: '楼顶狙击'));

  builder.line(EnemyKind.rifleman, 4, 0.2, 0.65, holdMin: 70, holdMax: 124);
  builder.line(
    EnemyKind.grenadier,
    3,
    1.6,
    1.0,
    fromX: 84,
    toX: 216,
    holdMin: 100,
    holdMax: 146,
  );
  builder.line(EnemyKind.infantry, 5, 0.4, 0.5, fromX: 60, toX: 240);
  builder.add(EnemyKind.shield, 1.0, 150);
  waves.add(book.next(3, name: '交叉火力'));

  builder.add(EnemyKind.armoredCar, 0.8, 84, holdY: 84);
  builder.add(EnemyKind.armoredCar, 2.6, 216, holdY: 84);
  builder.line(EnemyKind.infantry, 6, 0.2, 0.4);
  builder.line(
    EnemyKind.rifleman,
    2,
    2.0,
    1.0,
    fromX: 70,
    toX: 230,
    holdMin: 78,
    holdMax: 116,
  );
  waves.add(book.next(4, name: '铁甲巡江'));

  builder.add(EnemyKind.infantry, 0.2, 56);
  builder.add(EnemyKind.infantry, 0.7, 244);
  builder.add(EnemyKind.rifleman, 1.0, 240, holdY: 92);
  builder.add(EnemyKind.grenadier, 1.6, 176, holdY: 116);
  builder.add(EnemyKind.shield, 1.2, 120);
  builder.add(EnemyKind.raider, 0.6, 60);
  builder.add(EnemyKind.raider, 0.9, 240);
  builder.add(EnemyKind.boss, 2.8, 150, holdY: 76);
  waves.add(book.next(5, name: '租界头目', boss: true));
  return waves;
}

/// 四行仓库：两路纵队贴着砖墙压上，正面几乎没有空隙。
List<WavePlan> _warehouseWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  builder.line(EnemyKind.infantry, 4, 0.2, 0.45, fromX: 58, toX: 100);
  builder.line(EnemyKind.infantry, 4, 0.3, 0.45, fromX: 200, toX: 242);
  final waves = <WavePlan>[book.next(1, name: '仓库外围')];

  builder.line(EnemyKind.infantry, 6, 0.2, 0.42, fromX: 56, toX: 244);
  builder.add(EnemyKind.raider, 1.6, 58);
  builder.add(EnemyKind.raider, 1.9, 242);
  builder.line(
    EnemyKind.grenadier,
    3,
    1.4,
    0.9,
    fromX: 90,
    toX: 210,
    holdMin: 96,
    holdMax: 140,
  );
  builder.line(
    EnemyKind.rifleman,
    2,
    2.2,
    1.0,
    fromX: 70,
    toX: 230,
    holdMin: 78,
    holdMax: 120,
  );
  waves.add(book.next(2, name: '断墙死守'));

  builder.line(EnemyKind.infantry, 7, 0.2, 0.34, fromX: 50, toX: 250);
  builder.line(
    EnemyKind.rifleman,
    5,
    0.4,
    0.7,
    fromX: 52,
    toX: 248,
    holdMin: 68,
    holdMax: 126,
  );
  builder.add(EnemyKind.grenadier, 2.8, 150, holdY: 132);
  waves.add(book.next(3, name: '火线压制'));

  builder.add(EnemyKind.armoredCar, 0.6, 80, holdY: 82);
  builder.add(EnemyKind.armoredCar, 1.8, 150, holdY: 78);
  builder.add(EnemyKind.armoredCar, 3.0, 220, holdY: 82);
  builder.line(EnemyKind.infantry, 5, 0.2, 0.45);
  builder.add(EnemyKind.shield, 1.2, 150);
  builder.line(
    EnemyKind.grenadier,
    2,
    2.2,
    1.2,
    fromX: 106,
    toX: 194,
    holdMin: 104,
    holdMax: 148,
  );
  waves.add(book.next(4, name: '坦克围城'));

  builder.add(EnemyKind.infantry, 0.2, 52);
  builder.add(EnemyKind.infantry, 0.5, 248);
  builder.add(EnemyKind.infantry, 0.8, 90);
  builder.add(EnemyKind.infantry, 1.1, 210);
  builder.add(EnemyKind.rifleman, 1.4, 244, holdY: 90);
  builder.add(EnemyKind.raider, 0.7, 56);
  builder.add(EnemyKind.raider, 0.9, 244);
  builder.add(EnemyKind.shield, 2.0, 150);
  builder.add(EnemyKind.boss, 2.4, 150, holdY: 74);
  waves.add(book.next(5, name: '最终突围', boss: true));
  return waves;
}

/// 把当前排好的刷怪点封成一波，三个阵地共用同一套写法。
class _WaveBook {
  const _WaveBook(this.builder, this.hp);

  final WaveBuilder builder;
  final double hp;

  WavePlan next(int index, {String name = '', bool boss = false}) => WavePlan(
    index: index,
    name: name,
    boss: boss,
    hpMultiplier: hp,
    orders: builder.flush(),
  );
}
