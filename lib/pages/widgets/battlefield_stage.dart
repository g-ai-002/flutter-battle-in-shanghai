import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../../flame/battle_game.dart';
import '../../utils/battlefield_layout.dart';
import '../../utils/constants.dart';

/// 战场舞台：统一圆角、投影与 Flame 容器。
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
