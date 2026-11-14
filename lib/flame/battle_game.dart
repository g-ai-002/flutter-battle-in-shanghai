import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../game/battle_controller.dart';
import 'battlefield_component.dart';

/// Flame 游戏入口：只有一个战场组件，逻辑推进也由它按固定步长驱动。
class BattleGame extends FlameGame {
  BattleGame({required this.controller});

  final BattleController controller;
  BattlefieldComponent? _field;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final field = BattlefieldComponent(controller: controller);
    _field = field;
    _fit(field);
    await add(field);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final field = _field;
    if (field != null) _fit(field);
  }

  /// 战场始终铺满游戏区域（外层已按 3:4 约束尺寸）。
  void _fit(BattlefieldComponent field) {
    field
      ..size = size.clone()
      ..position = Vector2.zero();
  }

  /// 进入后台或离开页面时停掉渲染循环，避免残留后台任务。
  void sleep() => pauseEngine();

  void wake() => resumeEngine();
}
