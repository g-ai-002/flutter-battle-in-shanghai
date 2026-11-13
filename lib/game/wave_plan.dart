import 'dart:math' as math;

import '../utils/constants.dart';
import 'battle_config.dart';
import 'battle_scenes.dart';

/// 单个刷怪指令：波次开始后 [at] 秒在 [x] 处出现。
class SpawnOrder {
  const SpawnOrder({
    required this.at,
    required this.kind,
    required this.x,
    this.holdY = 0,
  });

  final double at;
  final EnemyKind kind;
  final double x;

  /// 枪手、掷弹兵与装甲车停下的纵向位置，0 表示一直向下推进。
  final double holdY;
}

/// 一波敌军的完整刷怪时间表。
class WavePlan {
  const WavePlan({
    required this.index,
    required this.orders,
    this.name = '',
    this.boss = false,
    this.hpMultiplier = 1,
  });

  final int index;
  final List<SpawnOrder> orders;

  /// 阵型名称，例如「两翼夹击」，在播报与战况条里展示。
  final String name;
  final bool boss;
  final double hpMultiplier;

  /// 波次持续时间，用于估算进度与刷怪节奏。
  double get duration =>
      orders.isEmpty ? 0 : orders.map((order) => order.at).reduce(math.max) + 2;
}

/// 波次编排助手：统一处理难度节奏、横向铺开与停靠高度。
///
/// 战役与无尽模式共用同一套写法，避免两份「取随机数 + 按横坐标铺开」的
/// 重复闭包各自漂移。
class WaveBuilder {
  WaveBuilder({required Difficulty difficulty, required this.random})
    : pace = difficulty.paceScale;

  /// 难度对应的刷怪间隔倍率，越小越密集。
  final double pace;
  final math.Random random;

  final List<SpawnOrder> _orders = [];

  /// 取走已经排好的刷怪点，开始编排下一波。
  List<SpawnOrder> flush() {
    final orders = List<SpawnOrder>.unmodifiable(_orders);
    _orders.clear();
    return orders;
  }

  /// 在 [at] 秒（按难度缩放）生成一个敌军。
  void add(EnemyKind kind, double at, double x, {double holdY = 0}) {
    _orders.add(SpawnOrder(at: at * pace, kind: kind, x: x, holdY: holdY));
  }

  /// 横向铺开一队敌军；[holdMax] 大于 0 时给远程兵随机停靠高度。
  void line(
    EnemyKind kind,
    int count,
    double start,
    double gap, {
    double fromX = 46,
    double toX = 254,
    double holdMin = 0,
    double holdMax = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final ratio = count == 1 ? 0.5 : i / (count - 1);
      final x = fromX + (toX - fromX) * ratio;
      final holdY = holdMax > 0
          ? holdMin + random.nextDouble() * (holdMax - holdMin)
          : 0.0;
      add(kind, start + i * gap, x, holdY: holdY);
    }
  }
}

/// 战役关卡的波次表：三处阵地各五波，越靠后的阵地敌军越硬。
List<WavePlan> sceneWaves(
  BattleScene scene,
  Difficulty difficulty, {
  math.Random? random,
}) {
  final builder = WaveBuilder(
    difficulty: difficulty,
    random: random ?? math.Random(scene.seed),
  );
  final hp = scene.hpScale;

  WavePlan wave(int index, {String name = '', bool boss = false}) => WavePlan(
    index: index,
    name: name,
    boss: boss,
    hpMultiplier: hp,
    orders: builder.flush(),
  );

  switch (scene) {
    case BattleScene.zhabei:
      builder.line(EnemyKind.infantry, 6, 0.2, 0.55);
      final waves = <WavePlan>[wave(1, name: '前哨试探')];

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
      waves.add(wave(2, name: '两翼夹击'));

      builder.line(EnemyKind.infantry, 5, 0.6, 0.5, fromX: 60, toX: 240);
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
      waves.add(wave(3, name: '火力压制'));

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
      waves.add(wave(4, name: '装甲突袭'));

      builder.add(EnemyKind.infantry, 0.2, 60);
      builder.add(EnemyKind.rifleman, 0.6, 240, holdY: 96);
      builder.add(EnemyKind.infantry, 1.0, 240);
      builder.add(EnemyKind.grenadier, 1.4, 190, holdY: 118);
      builder.add(EnemyKind.boss, 2.6, 150, holdY: 78);
      waves.add(wave(5, name: '头目决战', boss: true));
      return waves;

    case BattleScene.bund:
      // 江岸开阔：步兵散得更开，远处楼顶的枪手先发制人。
      builder.line(EnemyKind.infantry, 7, 0.2, 0.45, fromX: 36, toX: 264);
      builder.add(EnemyKind.rifleman, 3.0, 150, holdY: 112);
      final waves = <WavePlan>[wave(1, name: '江岸登陆')];

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
      waves.add(wave(2, name: '楼顶狙击'));

      builder.line(
        EnemyKind.rifleman,
        4,
        0.2,
        0.65,
        holdMin: 70,
        holdMax: 124,
      );
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
      waves.add(wave(3, name: '交叉火力'));

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
      waves.add(wave(4, name: '铁甲巡江'));

      builder.add(EnemyKind.infantry, 0.2, 56);
      builder.add(EnemyKind.infantry, 0.7, 244);
      builder.add(EnemyKind.rifleman, 1.0, 240, holdY: 92);
      builder.add(EnemyKind.grenadier, 1.6, 176, holdY: 116);
      builder.add(EnemyKind.boss, 2.8, 150, holdY: 76);
      waves.add(wave(5, name: '租界头目', boss: true));
      return waves;

    case BattleScene.warehouse:
      // 仓库外围：两路纵队贴着砖墙压上，正面几乎没有空隙。
      builder.line(EnemyKind.infantry, 4, 0.2, 0.45, fromX: 58, toX: 100);
      builder.line(EnemyKind.infantry, 4, 0.3, 0.45, fromX: 200, toX: 242);
      final waves = <WavePlan>[wave(1, name: '仓库外围')];

      builder.line(EnemyKind.infantry, 6, 0.2, 0.42, fromX: 56, toX: 244);
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
      waves.add(wave(2, name: '断墙死守'));

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
      waves.add(wave(3, name: '火线压制'));

      builder.add(EnemyKind.armoredCar, 0.6, 80, holdY: 82);
      builder.add(EnemyKind.armoredCar, 1.8, 150, holdY: 78);
      builder.add(EnemyKind.armoredCar, 3.0, 220, holdY: 82);
      builder.line(EnemyKind.infantry, 5, 0.2, 0.45);
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
      waves.add(wave(4, name: '坦克围城'));

      builder.add(EnemyKind.infantry, 0.2, 52);
      builder.add(EnemyKind.infantry, 0.5, 248);
      builder.add(EnemyKind.infantry, 0.8, 90);
      builder.add(EnemyKind.infantry, 1.1, 210);
      builder.add(EnemyKind.rifleman, 1.4, 244, holdY: 90);
      builder.add(EnemyKind.boss, 2.4, 150, holdY: 74);
      waves.add(wave(5, name: '最终突围', boss: true));
      return waves;
  }
}

/// 无尽模式的第 [index] 波：数量与强度逐波增长，每五波一个头目。
WavePlan endlessWave(int index, Difficulty difficulty, {math.Random? random}) {
  final rng = random ?? math.Random(index * 7919);
  final builder = WaveBuilder(difficulty: difficulty, random: rng);
  final bossWave = index % kEndlessBossEvery == 0;
  final baseScale = 1 + math.max(0, index - 1) * 0.07;
  final hpMultiplier = bossWave
      ? baseScale * (1 + (index ~/ kEndlessBossEvery - 1) * 0.5)
      : baseScale;
  const names = ['散兵冲击', '交叉火力', '炮兵掩护', '装甲纵队'];
  final name = bossWave ? '头目督战' : names[(index - 1) % names.length];

  double hold(double min, double max) => min + rng.nextDouble() * (max - min);

  final infantry = math.min(4 + index, 14);
  for (var i = 0; i < infantry; i++) {
    builder.add(
      EnemyKind.infantry,
      0.2 + i * 0.42,
      40 + rng.nextDouble() * 220,
    );
  }
  final riflemen = math.min(1 + index ~/ 2, 6);
  for (var i = 0; i < riflemen; i++) {
    builder.add(
      EnemyKind.rifleman,
      1.4 + i * 0.85,
      50 + rng.nextDouble() * 200,
      holdY: hold(70, 145),
    );
  }
  final grenadiers = math.min(index ~/ 3, 4);
  for (var i = 0; i < grenadiers; i++) {
    builder.add(
      EnemyKind.grenadier,
      3.0 + i * 1.1,
      70 + rng.nextDouble() * 160,
      holdY: hold(95, 150),
    );
  }
  if (index >= 4) {
    final cars = 1 + (index - 4) ~/ 3;
    for (var i = 0; i < math.min(cars, 3); i++) {
      builder.add(
        EnemyKind.armoredCar,
        4.5 + i * 1.4,
        90 + rng.nextDouble() * 120,
        holdY: hold(80, 115),
      );
    }
  }
  // 奇数波追加两翼火力：从街口两侧压上来，逼玩家换位。
  if (!bossWave && index.isOdd && index >= 3) {
    for (final x in [44.0, Field.width - 44]) {
      builder.add(
        EnemyKind.rifleman,
        2.0 + rng.nextDouble(),
        x,
        holdY: hold(74, 120),
      );
    }
  }
  if (bossWave) {
    builder.add(EnemyKind.boss, 1.2, 150, holdY: 78);
    builder.add(EnemyKind.rifleman, 0.8, 70, holdY: hold(88, 110));
  }
  return WavePlan(
    index: index,
    orders: builder.flush(),
    name: name,
    boss: bossWave,
    hpMultiplier: hpMultiplier,
  );
}
