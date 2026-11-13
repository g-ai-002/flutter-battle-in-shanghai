import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/battle_game.dart';
import '../../game/battle_config.dart';
import '../../theme/battle_painting.dart';
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
  const BattlefieldPreview({super.key, this.maxWidth = 320});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            height: width * Field.height / Field.width,
            child: const CustomPaint(painter: _PreviewPainter()),
          ),
        );
      },
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / Field.width;
    canvas.save();
    canvas.scale(scale);
    const field = Size(Field.width, Field.height);
    // 首页预览复用同一套战场画法：街道、两名推进中的敌军、守军与街垒。
    paintStreet(canvas, field, 0);
    paintSoldier(
      canvas,
      const Offset(96, 168),
      radius: 9,
      uniform: const Color(0xFF4A4438),
      helmet: const Color(0xFF33302A),
      aim: 1.5707963267948966,
      walk: 1.2,
      hostile: true,
    );
    paintSoldier(
      canvas,
      const Offset(206, 214),
      radius: 9,
      uniform: const Color(0xFF3F3B33),
      helmet: const Color(0xFF2B2925),
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
      uniform: const Color(0xFF6F7F5E),
      helmet: const Color(0xFF4A5540),
      accent: const Color(0xFFC2452F),
    );
    paintBarricade(canvas, field, 0);
    paintVignette(canvas, field);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => false;
}
