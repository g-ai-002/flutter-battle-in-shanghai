import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/pages/widgets/battle_hud.dart';
import 'package:battle_in_shanghai/pages/widgets/hud_cards.dart';
import 'package:battle_in_shanghai/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BattleSim startedSim() {
  final sim = BattleSim(
    mode: BattleMode.campaign,
    difficulty: Difficulty.veteran,
    random: math.Random(3),
  )..start();
  for (var i = 0; i < 130; i++) {
    sim.update(1 / 60);
  }
  return sim;
}

Widget wrap(Widget child) => MaterialApp(
  theme: buildDarkTheme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: HudScope(compact: false, child: child),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('战况卡展示波次、剩余敌军与生命', (tester) async {
    final sim = startedSim();
    await tester.pumpWidget(
      wrap(Column(children: [HpLine(sim: sim), BattleStatusBar(sim: sim)])),
    );
    expect(find.text('第 1/5 波'), findsOneWidget);
    expect(find.textContaining('剩余敌军'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('得分卡支持千分位与连击倍率', (tester) async {
    final sim = startedSim()
      ..score = 12345
      ..combo = 8;
    await tester.pumpWidget(wrap(ScoreCard(sim: sim)));
    expect(find.text('12,345'), findsOneWidget);
    expect(find.textContaining('连击 8'), findsOneWidget);
    expect(find.text('1.50x'), findsNothing);
    expect(find.textContaining('1.50x'), findsOneWidget);
  });

  testWidgets('头目出现时展示血条', (tester) async {
    final sim = startedSim();
    sim.enemies.add(
      EnemyUnit(
        kind: EnemyKind.boss,
        x: 150,
        y: 80,
        hp: 500,
        maxHp: 500,
        holdY: 78,
      ),
    );
    await tester.pumpWidget(wrap(BattleStatusBar(sim: sim)));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('临时武器展示剩余时间', (tester) async {
    final sim = startedSim();
    sim.player.weapon = WeaponKind.smg;
    sim.player.weaponUntil = sim.time + 12;
    await tester.pumpWidget(wrap(WeaponLine(sim: sim)));
    expect(find.text('冲锋枪'), findsOneWidget);
    expect(find.text('12s'), findsOneWidget);
  });
}
