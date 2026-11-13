import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/battle_scenes.dart';
import '../theme/battle_painting.dart';
import '../theme/scene_palette.dart';
import '../utils/constants.dart';

/// 静态图层的名字：预渲染、贴图与释放都按这张表走，增删图层不必改多处。
enum _Layer { base, roofs, props, vignette, glow, searchlight, barricade }

/// 战场静态图层缓存。
///
/// 路面渐变、屋顶瓦片、探照灯、前景街垒、阵地景物、工事与暗角在整局里
/// 几乎不变，预渲染成位图后每帧只做贴图，省掉重复构建渐变、Path、RRect 与
/// Paint 的开销。渲染设备不支持位图缓存时 [ready] 为 false，调用方回退到直接绘制。
class SceneCache {
  SceneCache({
    this.palette = ScenePalette.zhabei,
    this.scene = BattleScene.zhabei,
  });

  static const double _zoom = 2;
  static const double glowRadius = 138;

  /// 工事的磨损档位：血量 100% / 75% / 50% / 25% / 0%，各预渲染一张。
  static const int coverWearSteps = 5;

  static const Size fieldSize = Size(Field.width, Field.height);

  /// 当前阵地的配色与景物，整局不变。
  final ScenePalette palette;
  final BattleScene scene;

  final Map<_Layer, ui.Image> _images = {};
  final List<ui.Image?> _covers = List<ui.Image?>.filled(coverWearSteps, null);

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  bool _ready = false;
  bool _unavailable = false;
  int _layerBuilds = 0;

  bool get ready => _ready;
  bool get unavailable => _unavailable;

  /// 预渲染过的位图层数，测试用来确认稳态帧不再重复录制。
  @visibleForTesting
  int get layerBuilds => _layerBuilds;

  /// 全部预渲染位图的张数：七张整层位图加五档工事磨损图。
  static int get layerCount => _Layer.values.length + coverWearSteps;

  /// 懒加载：首帧创建，失败后不再重试。
  void ensure() {
    if (_ready || _unavailable) return;
    try {
      _images
        ..[_Layer.base] = _record(fieldSize, _zoom, (canvas) {
          paintStreetBase(canvas, fieldSize, palette);
        })
        ..[_Layer.roofs] = _record(
          const Size(Field.width, kRoofTileHeight),
          _zoom,
          (canvas) {
            paintRoofTile(canvas, fieldSize, palette);
          },
        )
        ..[_Layer.props] = _record(fieldSize, _zoom, (canvas) {
          paintSceneProps(canvas, fieldSize, scene, palette);
        })
        ..[_Layer.vignette] = _record(fieldSize, 1, (canvas) {
          paintVignette(canvas, fieldSize);
        })
        ..[_Layer.glow] = _record(
          const Size(glowRadius * 2, glowRadius * 2),
          1,
          (canvas) {
            canvas.translate(glowRadius, glowRadius);
            paintPlayerGlow(canvas, glowRadius, palette);
          },
        )
        // 探照灯的光柱只有极淡的渐变，1x 足够，省下一半位图内存。
        ..[_Layer.searchlight] = _record(
          const Size(kSearchlightWidth, kSearchlightHeight),
          1,
          (canvas) {
            canvas.translate(
              -(Field.width * 0.3 - kSearchlightWidth / 2),
              -kSearchlightTop,
            );
            paintSearchlightBeam(canvas, fieldSize, palette);
          },
        )
        ..[_Layer.barricade] = _record(
          const Size(Field.width, kBarricadeStripHeight),
          _zoom,
          (canvas) {
            canvas.translate(0, -(Field.height - kBarricadeStripHeight));
            paintBarricadeBase(canvas, fieldSize, palette);
          },
        );
      for (var i = 0; i < coverWearSteps; i++) {
        final hpRatio = 1 - i / (coverWearSteps - 1);
        _covers[i] = _record(
          const Size(kCoverArtWidth, kCoverArtHeight),
          _zoom,
          (canvas) {
            canvas.translate(-kCoverArtLeft, -kCoverArtTop);
            paintCoverWall(canvas, Offset.zero, hpRatio, 0, 0);
          },
        );
      }
      _ready = true;
    } catch (_) {
      _unavailable = true;
      _disposeImages();
    }
  }

  void drawBase(Canvas canvas) =>
      _drawLayer(canvas, _Layer.base, Offset.zero & fieldSize);

  /// 阵地景物：砖墙、江堤或仓库外墙，压在地面之上、单位之下。
  void drawProps(Canvas canvas) =>
      _drawLayer(canvas, _Layer.props, Offset.zero & fieldSize);

  void drawRoofs(Canvas canvas, double clock) {
    final image = _images[_Layer.roofs];
    if (image == null) return;
    final shift = (clock * 46) % kRoofTileHeight;
    for (
      var y = shift - kRoofTileHeight;
      y < Field.height;
      y += kRoofTileHeight
    ) {
      _draw(canvas, image, Rect.fromLTWH(0, y, Field.width, kRoofTileHeight));
    }
  }

  /// 探照灯：缓存里是零摆位的光柱，这里按时间左右平移贴图。
  void drawSearchlight(Canvas canvas, double clock) {
    final sway = math.sin(clock * 0.35) * 26;
    _drawLayer(
      canvas,
      _Layer.searchlight,
      Rect.fromLTWH(
        Field.width * 0.3 - kSearchlightWidth / 2 + sway,
        kSearchlightTop,
        kSearchlightWidth,
        kSearchlightHeight,
      ),
    );
  }

  /// 前景街垒：一条静态位图，余烬由调用方单独绘制。
  void drawBarricade(Canvas canvas) => _drawLayer(
    canvas,
    _Layer.barricade,
    const Rect.fromLTWH(
      0,
      Field.height - kBarricadeStripHeight,
      Field.width,
      kBarricadeStripHeight,
    ),
  );

  /// 工事：按磨损档位贴图，返回 false 表示缓存不可用。
  bool drawCover(
    Canvas canvas,
    Offset center,
    double hpRatio,
    double clock,
    double shake,
  ) {
    if (!_ready) return false;
    final index = ((1 - hpRatio) * (coverWearSteps - 1)).round().clamp(
      0,
      coverWearSteps - 1,
    );
    final image = _covers[index];
    if (image == null) return false;
    final jitter = shake > 0 ? math.sin(clock * 70) * shake * 1.6 : 0.0;
    _draw(
      canvas,
      image,
      Rect.fromLTWH(
        center.dx + kCoverArtLeft + jitter,
        center.dy + kCoverArtTop,
        kCoverArtWidth,
        kCoverArtHeight,
      ),
    );
    return true;
  }

  void drawVignette(Canvas canvas) =>
      _drawLayer(canvas, _Layer.vignette, Offset.zero & fieldSize);

  void drawGlow(Canvas canvas, Offset center) => _drawLayer(
    canvas,
    _Layer.glow,
    Rect.fromCircle(center: center, radius: glowRadius),
  );

  void _drawLayer(Canvas canvas, _Layer layer, Rect dst) {
    final image = _images[layer];
    if (image == null) return;
    _draw(canvas, image, dst);
  }

  void _draw(Canvas canvas, ui.Image image, Rect dst) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      _imagePaint,
    );
  }

  ui.Image _record(Size size, double zoom, void Function(Canvas) draw) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(zoom);
    draw(canvas);
    final picture = recorder.endRecording();
    try {
      _layerBuilds++;
      return picture.toImageSync(
        (size.width * zoom).ceil(),
        (size.height * zoom).ceil(),
      );
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    _disposeImages();
    _ready = false;
  }

  void _disposeImages() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    for (var i = 0; i < _covers.length; i++) {
      _covers[i]?.dispose();
      _covers[i] = null;
    }
  }
}
