import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/pages/home_page.dart';
import 'package:battle_in_shanghai/providers/settings_provider.dart';
import 'package:battle_in_shanghai/services/storage_service.dart';
import 'package:battle_in_shanghai/theme/app_theme.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildDarkTheme(), home: const HomePage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  testWidgets('首页展示品牌、两个模式入口与设置', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('血战上海滩'), findsWidgets);
    expect(find.text('战役模式'), findsOneWidget);
    expect(find.text('无尽模式'), findsOneWidget);
    expect(find.text('作战说明'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
    expect(find.text('战场阵地'), findsOneWidget);
    expect(find.text('敌军强度'), findsOneWidget);
    expect(find.text('逻辑刷新率'), findsOneWidget);
    expect(find.text('闸北'), findsWidgets);
  });

  testWidgets('折叠屏宽度下入口排成两列', (tester) async {
    tester.view.physicalSize = const Size(673, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final campaign = tester.getTopLeft(find.text('战役模式'));
    final endless = tester.getTopLeft(find.text('无尽模式'));
    final rules = tester.getTopLeft(find.text('作战说明'));
    expect(endless.dy, closeTo(campaign.dy, 0.5));
    expect(endless.dx, greaterThan(campaign.dx));
    expect(rules.dy, greaterThan(campaign.dy));
  });

  testWidgets('作战说明弹窗包含操作与补给', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('作战说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('WASD'), findsOneWidget);
    expect(find.textContaining('急救包'), findsOneWidget);
    expect(
      find.textContaining('${BattleScene.values.length} 处阵地依次解锁'),
      findsOneWidget,
    );
    await tester.tap(find.text('明白了'));
    await tester.pumpAndSettle();
  });

  testWidgets('未通关的阵地带锁，点击给出提示', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(settings.scene, BattleScene.zhabei);
    await tester.ensureVisible(find.text('外滩'));
    await tester.tap(find.text('外滩'));
    await tester.pump();
    expect(find.textContaining('先通关「闸北」'), findsOneWidget);
    expect(settings.scene, BattleScene.zhabei);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('通关闸北后可以切换到外滩', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyClearedScenes: [BattleScene.zhabei.name],
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    await tester.ensureVisible(find.text('外滩'));
    await tester.tap(find.text('外滩'));
    await tester.pump();
    expect(settings.scene, BattleScene.bund);
  });

  testWidgets('切换深色/浅色会更新偏好', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(settings.darkMode, isTrue);
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pump();
    expect(settings.darkMode, isFalse);
  });

  testWidgets('横屏矮屏入口仍在首屏', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('战役模式'), findsOneWidget);
    expect(tester.getTopLeft(find.text('战役模式')).dy, lessThan(320));
  });

  testWidgets('窄屏下模式入口单列显示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final campaign = tester.getTopLeft(find.text('战役模式'));
    final endless = tester.getTopLeft(find.text('无尽模式'));
    expect(endless.dy, greaterThan(campaign.dy));
    expect(endless.dx, closeTo(campaign.dx, 1));
    // 窄屏把入口提到主视觉之后，开局按钮在首屏内可见。
    expect(campaign.dy, lessThan(560));
  });
}
