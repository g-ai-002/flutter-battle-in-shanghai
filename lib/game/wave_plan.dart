import 'dart:math' as math;

import '../utils/constants.dart';
import 'battle_config.dart';

/// 单个刷怪指令：波次开始后 [at] 秒在 [x] 处出现。
class SpawnOrder {
  const SpawnOrder({required this.at, required this.kind, required this.x, this.holdY = 0});

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
  double get duration => orders.isEmpty
      ? 0
      : orders.map((order) => order.at).reduce(math.max) + 2;
}

/// 战役固定五波，难度只影响敌军生命与出怪节奏。
List<WavePlan> campaignWaves(Difficulty difficulty, {math.Random? random}) {
  final pace = difficulty.paceScale;
  final rng = random ?? math.Random(0x5A17);
  double hold(double min, double max) =>
      min + rng.nextDouble() * (max - min);

  SpawnOrder order(
    double at,
    EnemyKind kind,
    double x, {
    double holdY = 0,
  }) => SpawnOrder(at: at * pace, kind: kind, x: x, holdY: holdY);

  List<SpawnOrder> line(
    EnemyKind kind,
    int count,
    double start,
    double gap, {
    double fromX = 46,
    double toX = 254,
    double holdMin = 0,
    double holdMax = 0,
  }) {
    final orders = <SpawnOrder>[];
    for (var i = 0; i < count; i++) {
      final ratio = count == 1 ? 0.5 : i / (count - 1);
      final x = fromX + (toX - fromX) * ratio;
      final holdY = holdMax > 0 ? hold(holdMin, holdMax) : 0.0;
      orders.add(order(start + i * gap, kind, x, holdY: holdY));
    }
    return orders;
  }

  return [
    WavePlan(
      index: 1,
      name: '前哨试探',
      orders: line(EnemyKind.infantry, 6, 0.2, 0.55),
    ),
    WavePlan(
      index: 2,
      name: '两翼夹击',
      orders: [
        ...line(
          EnemyKind.infantry,
          3,
          0.2,
          0.5,
          fromX: 40,
          toX: 56,
        ),
        ...line(
          EnemyKind.infantry,
          3,
          0.45,
          0.5,
          fromX: 244,
          toX: 260,
        ),
        ...line(
          EnemyKind.rifleman,
          2,
          2.6,
          1.0,
          fromX: 110,
          toX: 190,
          holdMin: 80,
          holdMax: 140,
        ),
      ],
    ),
    WavePlan(
      index: 3,
      name: '火力压制',
      orders: [
        ...line(EnemyKind.infantry, 5, 0.6, 0.5, fromX: 60, toX: 240),
        ...line(
          EnemyKind.rifleman,
          4,
          0.3,
          0.8,
          fromX: 56,
          toX: 244,
          holdMin: 66,
          holdMax: 130,
        ),
        ...line(
          EnemyKind.grenadier,
          2,
          2.2,
          1.2,
          fromX: 96,
          toX: 204,
          holdMin: 100,
          holdMax: 150,
        ),
      ],
    ),
    WavePlan(
      index: 4,
      name: '装甲突袭',
      orders: [
        ...line(EnemyKind.infantry, 6, 0.2, 0.42),
        order(1.0, EnemyKind.armoredCar, 92, holdY: 82),
        order(2.4, EnemyKind.armoredCar, 208, holdY: 82),
        ...line(
          EnemyKind.rifleman,
          2,
          2.0,
          1.0,
          fromX: 60,
          toX: 240,
          holdMin: 72,
          holdMax: 120,
        ),
        ...line(
          EnemyKind.grenadier,
          2,
          3.4,
          1.3,
          fromX: 120,
          toX: 180,
          holdMin: 108,
          holdMax: 150,
        ),
      ],
    ),
    WavePlan(
      index: 5,
      name: '头目决战',
      boss: true,
      orders: [
        order(0.2, EnemyKind.infantry, 60),
        order(0.6, EnemyKind.rifleman, 240, holdY: 96),
        order(1.0, EnemyKind.infantry, 240),
        order(1.4, EnemyKind.grenadier, 190, holdY: 118),
        order(2.6, EnemyKind.boss, 150, holdY: 78),
      ],
    ),
  ];
}

/// 无尽模式的第 [index] 波：数量与强度逐波增长，每五波一个头目。
WavePlan endlessWave(int index, Difficulty difficulty, {math.Random? random}) {
  final rng = random ?? math.Random(index * 7919);
  final pace = difficulty.paceScale;
  final bossWave = index % kEndlessBossEvery == 0;
  final orders = <SpawnOrder>[];
  final baseScale = 1 + math.max(0, index - 1) * 0.07;
  final hpMultiplier = bossWave
      ? baseScale * (1 + (index ~/ kEndlessBossEvery - 1) * 0.5)
      : baseScale;
  const names = ['散兵冲击', '交叉火力', '炮兵掩护', '装甲纵队'];
  final name = bossWave ? '头目督战' : names[(index - 1) % names.length];

  double hold(double min, double max) =>
      min + rng.nextDouble() * (max - min);

  SpawnOrder push(EnemyKind kind, double at, double x, {double holdY = 0}) {
    final order = SpawnOrder(at: at * pace, kind: kind, x: x, holdY: holdY);
    orders.add(order);
    return order;
  }

  final infantry = math.min(4 + index, 14);
  for (var i = 0; i < infantry; i++) {
    push(EnemyKind.infantry, 0.2 + i * 0.42, 40 + rng.nextDouble() * 220);
  }
  final riflemen = math.min(1 + index ~/ 2, 6);
  for (var i = 0; i < riflemen; i++) {
    push(
      EnemyKind.rifleman,
      1.4 + i * 0.85,
      50 + rng.nextDouble() * 200,
      holdY: hold(70, 145),
    );
  }
  final grenadiers = math.min(index ~/ 3, 4);
  for (var i = 0; i < grenadiers; i++) {
    push(
      EnemyKind.grenadier,
      3.0 + i * 1.1,
      70 + rng.nextDouble() * 160,
      holdY: hold(95, 150),
    );
  }
  if (index >= 4) {
    final cars = 1 + (index - 4) ~/ 3;
    for (var i = 0; i < math.min(cars, 3); i++) {
      push(EnemyKind.armoredCar, 4.5 + i * 1.4, 90 + rng.nextDouble() * 120,
          holdY: hold(80, 115));
    }
  }
  // 奇数波追加两翼火力：从街口两侧压上来，逼玩家换位。
  if (!bossWave && index.isOdd && index >= 3) {
    for (final x in [44.0, Field.width - 44]) {
      push(EnemyKind.rifleman, 2.0 + rng.nextDouble(), x, holdY: hold(74, 120));
    }
  }
  if (bossWave) {
    push(
      EnemyKind.boss,
      1.2,
      150,
      holdY: 78,
    );
    push(EnemyKind.rifleman, 0.8, 70, holdY: hold(88, 110));
  }
  return WavePlan(
    index: index,
    orders: orders,
    name: name,
    boss: bossWave,
    hpMultiplier: hpMultiplier,
  );
}
