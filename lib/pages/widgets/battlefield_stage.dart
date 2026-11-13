import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/battle_game.dart';
import '../../game/battle_config.dart';
import '../../game/battle_scenes.dart';
import '../../theme/battle_painting.dart';
import '../../theme/scene_palette.dart';
import '../../utils/battlefield_layout.dart';
import '../../utils/constants.dart';

/// 战场舞台：统一圆角、投影与 Flame 容器，战斗页与首页预览共用。
///
/// 战场保持 3:4 的宽高比，按可用空间取最大尺寸。
class BattlefieldStage extends StatelessWidget {
  const BattlefieldStage({
    super.key,
    required this.game,
    required this.gameKey,
    this.maxWidth = kFieldMaxWidth,
    this.onDragBy,
  });

  final BattleGame game;
  final Key gameKey;
  final double maxWidth;

  /// 拖动回调，位移已换算成战场逻辑坐标。
  final void Function(double dx, double dy)? onDragBy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = fieldFitSize(constraints.biggest, maxWidth);
        return Center(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2F25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: onDragBy == null || size.width <= 0
                  ? null
                  : (details) {
                      final scale = Field.width / size.width;
                      onDragBy!(
                        details.delta.dx * scale,
                        details.delta.dy * scale,
                      );
                    },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GameWidget<BattleGame>(key: gameKey, game: game),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 战场的静态缩略图：首页主视觉用，不需要启动 Flame。
class BattlefieldPreview extends StatelessWidget {
  const BattlefieldPreview({
    super.key,
    this.maxWidth = 320,
    this.scene = BattleScene.zhabei,
  });

  final double maxWidth;

  /// 首页预览跟随当前选择的阵地，换关时街景随之变化。
  final BattleScene scene;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            height: width * Field.height / Field.width,
            // 首页预览是静态画，单独成层后滚动页面不会反复重绘。
            child: RepaintBoundary(
              child: CustomPaint(painter: _PreviewPainter(scene)),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.scene);

  final BattleScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / Field.width;
    canvas.save();
    canvas.scale(scale);
    const field = Size(Field.width, Field.height);
    final palette = paletteOf(scene);
    // 首页预览复用同一套战场画法：街道、阵地景物、两名推进中的敌军、守军与街垒。
    paintStreet(canvas, field, 0, palette);
    paintSceneProps(canvas, field, scene, palette);
    paintSoldier(
      canvas,
      const Offset(96, 168),
      radius: 9,
      uniform: const Color(0xFF595142),
      helmet: const Color(0xFF403A30),
      aim: 1.5707963267948966,
      walk: 1.2,
      hostile: true,
    );
    paintSoldier(
      canvas,
      const Offset(206, 214),
      radius: 9,
      uniform: const Color(0xFF4C473C),
      helmet: const Color(0xFF363229),
      accent: const Color(0xFF7A2A20),
      aim: 1.9,
      hostile: true,
    );
    paintPickup(
      canvas,
      const Offset(244, 288),
      PickupKind.ammo,
      0,
    );
    paintSoldier(
      canvas,
      const Offset(150, 330),
      radius: 9,
      uniform: const Color(0xFF80916A),
      helmet: const Color(0xFF56674A),
      accent: const Color(0xFFC2452F),
    );
    paintBarricade(canvas, field, 0, palette);
    paintVignette(canvas, field);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.scene != scene;
}
