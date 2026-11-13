import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/battle_painting.dart';
import '../utils/constants.dart';

/// 战场静态图层缓存。
///
/// 路面渐变、屋顶瓦片、暗角与环境光在整局里几乎不变，预渲染成位图后每帧
/// 只做贴图，省掉重复构建渐变、Path 与 Paint 的开销。渲染设备不支持位图
/// 缓存时 [ready] 为 false，调用方回退到直接绘制。
class SceneCache {
  static const double _zoom = 2;
  static const double glowRadius = 138;

  static const Size fieldSize = Size(Field.width, Field.height);

  ui.Image? _base;
  ui.Image? _roofs;
  ui.Image? _vignette;
  ui.Image? _glow;

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  bool _ready = false;
  bool _unavailable = false;

  bool get ready => _ready;
  bool get unavailable => _unavailable;

  /// 懒加载：首帧创建，失败后不再重试。
  void ensure() {
    if (_ready || _unavailable) return;
    try {
      _base = _record(fieldSize, _zoom, (canvas) {
        paintStreetBase(canvas, fieldSize);
      });
      _roofs = _record(
        const Size(Field.width, kRoofTileHeight),
        _zoom,
        (canvas) {
          paintRoofTile(canvas, fieldSize);
        },
      );
      _vignette = _record(fieldSize, 1, (canvas) {
        paintVignette(canvas, fieldSize);
      });
      _glow = _record(
        const Size(glowRadius * 2, glowRadius * 2),
        1,
        (canvas) {
          canvas.translate(glowRadius, glowRadius);
          paintPlayerGlow(canvas, glowRadius);
        },
      );
      _ready = true;
    } catch (_) {
      _unavailable = true;
      _disposeImages();
    }
  }

  void drawBase(Canvas canvas) {
    final image = _base;
    if (image != null) {
      _draw(canvas, image, Offset.zero & fieldSize);
    }
  }

  void drawRoofs(Canvas canvas, double clock) {
    final image = _roofs;
    if (image == null) return;
    final shift = (clock * 46) % kRoofTileHeight;
    for (
      var y = shift - kRoofTileHeight;
      y < Field.height;
      y += kRoofTileHeight
    ) {
      _draw(
        canvas,
        image,
        Rect.fromLTWH(0, y, Field.width, kRoofTileHeight),
      );
    }
  }

  void drawVignette(Canvas canvas) {
    final image = _vignette;
    if (image != null) _draw(canvas, image, Offset.zero & fieldSize);
  }

  void drawGlow(Canvas canvas, Offset center) {
    final image = _glow;
    if (image == null) return;
    _draw(
      canvas,
      image,
      Rect.fromCircle(center: center, radius: glowRadius),
    );
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
    _base?.dispose();
    _roofs?.dispose();
    _vignette?.dispose();
    _glow?.dispose();
    _base = null;
    _roofs = null;
    _vignette = null;
    _glow = null;
  }
}
