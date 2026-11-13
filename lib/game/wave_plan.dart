import 'dart:math' as math;

import '../utils/constants.dart';
import 'battle_config.dart';

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
