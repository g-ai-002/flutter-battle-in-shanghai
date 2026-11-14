import 'dart:math' as math;

import 'battle_config.dart';
import 'battle_scenes.dart';
import 'wave_plan.dart';

/// 战役关卡的波次表：四处阵地各五波，越靠后的阵地敌军越硬。
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
    BattleScene.suzhou => _suzhouWaves(builder, scene.hpScale),
  };
}

/// 闸北：窄巷正面推进，两翼从街口包抄。
List<WavePlan> _zhabeiWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  book.line(EnemyKind.infantry, 6, 0.2, 0.55);
  book.wave('前哨试探');

  book.line(EnemyKind.infantry, 3, 0.2, 0.5, fromX: 40, toX: 56);
  book.line(EnemyKind.infantry, 3, 0.45, 0.5, fromX: 244, toX: 260);
  book.line(
    EnemyKind.rifleman,
    2,
    2.6,
    1.0,
    fromX: 110,
    toX: 190,
    holdMin: 80,
    holdMax: 140,
  );
  book.add(EnemyKind.raider, 3.2, 54);
  book.add(EnemyKind.raider, 3.6, 246);
  book.wave('两翼夹击');

  book.line(EnemyKind.infantry, 5, 0.6, 0.5, fromX: 60, toX: 240);
  book.add(EnemyKind.shield, 0.8, 150);
  book.line(
    EnemyKind.rifleman,
    4,
    0.3,
    0.8,
    fromX: 56,
    toX: 244,
    holdMin: 66,
    holdMax: 130,
  );
  book.line(
    EnemyKind.grenadier,
    2,
    2.2,
    1.2,
    fromX: 96,
    toX: 204,
    holdMin: 100,
    holdMax: 150,
  );
  book.wave('火力压制');

  book.line(EnemyKind.infantry, 6, 0.2, 0.42);
  book.add(EnemyKind.armoredCar, 1.0, 92, holdY: 82);
  book.add(EnemyKind.armoredCar, 2.4, 208, holdY: 82);
  book.line(
    EnemyKind.rifleman,
    2,
    2.0,
    1.0,
    fromX: 60,
    toX: 240,
    holdMin: 72,
    holdMax: 120,
  );
  book.line(
    EnemyKind.grenadier,
    2,
    3.4,
    1.3,
    fromX: 120,
    toX: 180,
    holdMin: 108,
    holdMax: 150,
  );
  book.wave('装甲突袭');

  book.add(EnemyKind.infantry, 0.2, 60);
  book.add(EnemyKind.rifleman, 0.6, 240, holdY: 96);
  book.add(EnemyKind.infantry, 1.0, 240);
  book.add(EnemyKind.grenadier, 1.4, 190, holdY: 118);
  book.add(EnemyKind.raider, 0.8, 96);
  book.add(EnemyKind.raider, 1.0, 204);
  book.add(EnemyKind.boss, 2.6, 150, holdY: 78);
  book.wave('头目决战', boss: true);
  return book.waves;
}

/// 外滩：江岸开阔，步兵散得更开，远处楼顶的枪手先发制人。
List<WavePlan> _bundWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  book.line(EnemyKind.infantry, 7, 0.2, 0.45, fromX: 36, toX: 264);
  book.add(EnemyKind.rifleman, 3.0, 150, holdY: 112);
  book.wave('江岸登陆');

  book.line(
    EnemyKind.rifleman,
    4,
    0.3,
    0.7,
    fromX: 52,
    toX: 248,
    holdMin: 64,
    holdMax: 108,
  );
  book.line(
    EnemyKind.rifleman,
    2,
    2.4,
    1.1,
    fromX: 96,
    toX: 204,
    holdMin: 112,
    holdMax: 150,
  );
  book.line(EnemyKind.infantry, 4, 0.6, 0.6, fromX: 70, toX: 230);
  book.wave('楼顶狙击');

  book.line(EnemyKind.rifleman, 4, 0.2, 0.65, holdMin: 70, holdMax: 124);
  book.line(
    EnemyKind.grenadier,
    3,
    1.6,
    1.0,
    fromX: 84,
    toX: 216,
    holdMin: 100,
    holdMax: 146,
  );
  book.line(EnemyKind.infantry, 5, 0.4, 0.5, fromX: 60, toX: 240);
  book.add(EnemyKind.shield, 1.0, 150);
  book.wave('交叉火力');

  book.add(EnemyKind.armoredCar, 0.8, 84, holdY: 84);
  book.add(EnemyKind.armoredCar, 2.6, 216, holdY: 84);
  book.line(EnemyKind.infantry, 6, 0.2, 0.4);
  book.line(
    EnemyKind.rifleman,
    2,
    2.0,
    1.0,
    fromX: 70,
    toX: 230,
    holdMin: 78,
    holdMax: 116,
  );
  book.wave('铁甲巡江');

  book.add(EnemyKind.infantry, 0.2, 56);
  book.add(EnemyKind.infantry, 0.7, 244);
  book.add(EnemyKind.rifleman, 1.0, 240, holdY: 92);
  book.add(EnemyKind.grenadier, 1.6, 176, holdY: 116);
  book.add(EnemyKind.shield, 1.2, 120);
  book.add(EnemyKind.raider, 0.6, 60);
  book.add(EnemyKind.raider, 0.9, 240);
  book.add(EnemyKind.boss, 2.8, 150, holdY: 76);
  book.wave('租界头目', boss: true);
  return book.waves;
}

/// 四行仓库：两路纵队贴着砖墙压上，正面几乎没有空隙。
List<WavePlan> _warehouseWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  book.line(EnemyKind.infantry, 4, 0.2, 0.45, fromX: 58, toX: 100);
  book.line(EnemyKind.infantry, 4, 0.3, 0.45, fromX: 200, toX: 242);
  book.wave('仓库外围');

  book.line(EnemyKind.infantry, 6, 0.2, 0.42, fromX: 56, toX: 244);
  book.add(EnemyKind.raider, 1.6, 58);
  book.add(EnemyKind.raider, 1.9, 242);
  book.line(
    EnemyKind.grenadier,
    3,
    1.4,
    0.9,
    fromX: 90,
    toX: 210,
    holdMin: 96,
    holdMax: 140,
  );
  book.line(
    EnemyKind.rifleman,
    2,
    2.2,
    1.0,
    fromX: 70,
    toX: 230,
    holdMin: 78,
    holdMax: 120,
  );
  book.wave('断墙死守');

  book.line(EnemyKind.infantry, 7, 0.2, 0.34, fromX: 50, toX: 250);
  book.line(
    EnemyKind.rifleman,
    5,
    0.4,
    0.7,
    fromX: 52,
    toX: 248,
    holdMin: 68,
    holdMax: 126,
  );
  book.add(EnemyKind.grenadier, 2.8, 150, holdY: 132);
  book.wave('火线压制');

  book.add(EnemyKind.armoredCar, 0.6, 80, holdY: 82);
  book.add(EnemyKind.armoredCar, 1.8, 150, holdY: 78);
  book.add(EnemyKind.armoredCar, 3.0, 220, holdY: 82);
  book.line(EnemyKind.infantry, 5, 0.2, 0.45);
  book.add(EnemyKind.shield, 1.2, 150);
  book.line(
    EnemyKind.grenadier,
    2,
    2.2,
    1.2,
    fromX: 106,
    toX: 194,
    holdMin: 104,
    holdMax: 148,
  );
  book.wave('坦克围城');

  book.add(EnemyKind.infantry, 0.2, 52);
  book.add(EnemyKind.infantry, 0.5, 248);
  book.add(EnemyKind.infantry, 0.8, 90);
  book.add(EnemyKind.infantry, 1.1, 210);
  book.add(EnemyKind.rifleman, 1.4, 244, holdY: 90);
  book.add(EnemyKind.raider, 0.7, 56);
  book.add(EnemyKind.raider, 0.9, 244);
  book.add(EnemyKind.shield, 2.0, 150);
  book.add(EnemyKind.boss, 2.4, 150, holdY: 74);
  book.wave('最终突围', boss: true);
  return book.waves;
}

/// 苏州河：铁桥狭窄，正面压力最重，两侧钢梁后还藏着枪手。
List<WavePlan> _suzhouWaves(WaveBuilder builder, double hp) {
  final book = _WaveBook(builder, hp);

  book.line(EnemyKind.infantry, 7, 0.2, 0.42, fromX: 48, toX: 252);
  book.line(EnemyKind.rifleman, 3, 1.6, 1.1,
      fromX: 72, toX: 228, holdMin: 72, holdMax: 126);
  book.wave('桥头遭遇');

  book.line(EnemyKind.rifleman, 5, 0.2, 0.55,
      fromX: 56, toX: 244, holdMin: 64, holdMax: 120);
  book.add(EnemyKind.shield, 0.6, 96);
  book.add(EnemyKind.shield, 1.1, 204);
  book.line(EnemyKind.infantry, 4, 0.4, 0.5, fromX: 60, toX: 240);
  book.wave('铁桥封锁');

  book.line(EnemyKind.grenadier, 3, 0.4, 0.9,
      fromX: 88, toX: 212, holdMin: 98, holdMax: 142);
  book.add(EnemyKind.armoredCar, 1.0, 88, holdY: 80);
  book.add(EnemyKind.armoredCar, 2.8, 212, holdY: 80);
  book.line(EnemyKind.infantry, 5, 0.2, 0.46);
  book.wave('河面炮火');

  book.add(EnemyKind.armoredCar, 0.6, 82, holdY: 78);
  book.add(EnemyKind.armoredCar, 2.4, 218, holdY: 78);
  book.line(EnemyKind.shield, 2, 0.8, 0.9, fromX: 104, toX: 196);
  book.line(EnemyKind.raider, 2, 0.4, 0.55, fromX: 54, toX: 246);
  book.add(EnemyKind.grenadier, 2.4, 150, holdY: 120);
  book.wave('装甲登陆');

  book.add(EnemyKind.infantry, 0.2, 50);
  book.add(EnemyKind.infantry, 0.5, 250);
  book.add(EnemyKind.raider, 0.8, 72);
  book.add(EnemyKind.raider, 1.0, 228);
  book.add(EnemyKind.rifleman, 1.2, 244, holdY: 92);
  book.add(EnemyKind.rifleman, 1.5, 56, holdY: 92);
  book.add(EnemyKind.shield, 1.8, 110);
  book.add(EnemyKind.shield, 2.0, 190);
  book.add(EnemyKind.grenadier, 2.2, 150, holdY: 120);
  book.add(EnemyKind.boss, 2.6, 150, holdY: 72);
  book.wave('桥心决战', boss: true);
  return book.waves;
}

/// 把排好的刷怪点封成一波：波次序号自动递增，四处阵地共用同一套写法。
class _WaveBook {
  _WaveBook(this.builder, this.hp);

  final WaveBuilder builder;
  final double hp;
  final List<WavePlan> waves = [];

  void add(EnemyKind kind, double at, double x, {double holdY = 0}) =>
      builder.add(kind, at, x, holdY: holdY);

  void line(EnemyKind kind, int count, double start, double gap,
          {double fromX = 46, double toX = 254,
          double holdMin = 0, double holdMax = 0}) =>
      builder.line(kind, count, start, gap,
          fromX: fromX, toX: toX, holdMin: holdMin, holdMax: holdMax);

  void wave(String name, {bool boss = false}) => waves.add(WavePlan(
        index: waves.length + 1, name: name, boss: boss,
        hpMultiplier: hp, orders: builder.flush(),
      ));
}
