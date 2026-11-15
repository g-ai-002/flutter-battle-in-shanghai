import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/logic_rate.dart';
import 'package:battle_in_shanghai/pages/game_page.dart';
import 'package:battle_in_shanghai/pages/widgets/control_bar.dart';
import 'package:battle_in_shanghai/providers/settings_provider.dart';
import 'package:battle_in_shanghai/services/storage_service.dart';
import 'package:battle_in_shanghai/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> pumpGame(
  WidgetTester tester, {
  BattleMode mode = BattleMode.campaign,
}) async {
  final storage = await StorageService.instance;
  final settings = SettingsProvider(storage);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: GamePage(mode: mode, difficulty: Difficulty.veteran),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return settings;
}

/// 从首页压入战斗页，便于验证退出战斗后确实回到上一页。
Future<SettingsProvider> pumpGameRoute(WidgetTester tester) async {
  final storage = await StorageService.instance;
  final settings = SettingsProvider(storage);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GamePage(
                      mode: BattleMode.campaign,
                      difficulty: Difficulty.veteran,
                    ),
                  ),
                ),
                child: const Text('开战'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('开战'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  testWidgets('战斗页没有应用栏，HUD 浮在战场四周', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('战役 · 闸北'), findsOneWidget);
    expect(find.text('累计得分'), findsOneWidget);
    expect(find.textContaining('第 1/5 波'), findsOneWidget);
    expect(find.text('手雷'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('重开'), findsOneWidget);
    expect(find.byKey(const ValueKey('battlefield')), findsOneWidget);

    final field = tester.getSize(find.byKey(const ValueKey('battlefield')));
    expect(field.width / field.height, closeTo(3 / 4, 0.01));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('投掷手雷后按钮进入冷却，重开恢复', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    await tester.tap(find.text('手雷'));
    await tester.pump();
    expect(find.text('手雷'), findsNothing);
    expect(find.textContaining('12s'), findsOneWidget);

    await tester.tap(find.text('重开'));
    await tester.pump();
    expect(find.text('手雷'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('工事按钮布置沙袋，达到上限后禁用', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    final controls = tester.widget<BattleControls>(
      find.byType(BattleControls),
    );
    expect(controls.controller.sim.covers, hasLength(2));
    expect(find.text('工事'), findsOneWidget);
    expect(find.byIcon(Icons.flight_rounded), findsOneWidget);

    await tester.tap(find.text('工事'));
    await tester.pump();
    expect(controls.controller.sim.covers, hasLength(3));
    expect(find.text('工事 3/3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('暂停菜单可以继续战斗', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('战斗暂停'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('战斗暂停'), findsNothing);
    expect(find.text('暂停'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('连续触发暂停只弹出一个菜单', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    final controls = tester.widget<BattleControls>(
      find.byType(BattleControls),
    );
    controls.onOpenPause();
    controls.onOpenPause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('战斗暂停'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('战斗暂停'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('小屏横屏使用紧凑 HUD，按钮只留图标', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    expect(find.text('重开'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('battlefield')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('超小屏竖屏下布局不溢出，战场保持 3:4', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGame(tester);
    final field = tester.getSize(find.byKey(const ValueKey('battlefield')));
    expect(field.width, greaterThan(0));
    expect(field.width / field.height, closeTo(3 / 4, 0.01));
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('战斗失败后返回营地会退出战斗页且不卡死', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGameRoute(tester);
    expect(find.byKey(const ValueKey('battlefield')), findsOneWidget);

    final controls = tester.widget<BattleControls>(
      find.byType(BattleControls),
    );
    final controller = controls.controller;
    controller.sim.player.hp = 0;
    for (var i = 0; i < 120 && !controller.finished; i++) {
      controller.sim.update(0.05);
    }
    expect(controller.finished, isTrue);
    controller.togglePause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('返回营地'), findsOneWidget);

    await tester.tap(find.text('返回营地'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GamePage), findsNothing);
    expect(find.text('开战'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('暂停菜单撤退会退出战斗页', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpGameRoute(tester);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(TextButton, '撤退'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GamePage), findsNothing);
    expect(find.text('开战'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无尽模式显示波次但不显示总波数，刷新率来自设置', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'logic_rate': LogicRate.hz30.name,
    });
    StorageService.resetForTests();
    await pumpGame(tester, mode: BattleMode.endless);

    expect(find.text('无尽 · 闸北'), findsOneWidget);
    expect(find.textContaining('第 1 波'), findsOneWidget);
    expect(find.textContaining('/5'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
