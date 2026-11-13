import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/battle_controller.dart';
import '../game/battle_sim.dart';
import '../utils/constants.dart';
import 'battle_scene_painter.dart';

/// 战场渲染组件：只负责推进逻辑、缩放与镜头抖动，作画交给 [BattleScenePainter]。
///
/// 战场坐标固定为 300 × 400，组件按自身尺寸整体缩放；棋子、弹道、爆炸
/// 与背景全部由 Canvas 程序化绘制，仓库不携带图片资源。
class BattlefieldComponent extends PositionComponent {
  BattlefieldComponent({required this.controller})
    : _painter = BattleScenePainter(sim: controller.sim),
      super(priority: 0);

  final BattleController controller;
  final BattleScenePainter _painter;
  BattleSim get _sim => controller.sim;

  final math.Random _shakeRandom = math.Random(7);

  double _clock = 0;
  double _shakeX = 0;
  double _shakeY = 0;

  @override
  Future<void> onLoad() async {
    _painter.prepare();
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    controller.advance(dt);
    final shake = _sim.shake;
    if (shake > 0.2) {
      _shakeX = (_shakeRandom.nextDouble() * 2 - 1) * shake * 0.35;
      _shakeY = (_shakeRandom.nextDouble() * 2 - 1) * shake * 0.35;
    } else {
      _shakeX = 0;
      _shakeY = 0;
    }
  }

  @override
  void onRemove() {
    _painter.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final scale = size.x / Field.width;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(_shakeX, _shakeY);
    _painter.paint(canvas, _clock);
    canvas.restore();
  }
}
