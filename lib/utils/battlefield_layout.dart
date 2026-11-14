import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'constants.dart';

/// 战场与 HUD 的几何规则：对局页排版、战场舞台与横竖屏判定共用一份计算。
///
/// 战场是 3:4 的竖向矩形，手机上竖屏能拿到的面积几乎总是更大，所以默认
/// 竖屏；只有横屏确实能让战场更大时才值得旋转并隐藏系统栏。

/// 战场显示的最大宽度，再宽只会拉长视线，不增加有效面积。
const double kFieldMaxWidth = 640;

/// 左右留白达到该宽度才把悬浮卡片挂到战场两侧，否则排到上方。
const double kHudRailWidth = 126;

/// 窄于该宽度时标题与战况预计要上下两行（只用于战场尺寸估算）。
const double kHudStackedWidth = 520;

/// 可用高度不足该值时改用紧凑卡片。
const double kHudCompactHeight = 560;

const double kHudPadding = 8;

const double kHudTitleRow = 58;
const double kHudInfoRow = 46;
const double kHudCompactTitleRow = 54;
const double kHudCompactInfoRow = 40;
const double kHudRowGap = 8;
const double kHudBottomRow = 66;
const double kHudCompactBottomRow = 56;

/// 战场按 3:4 宽高比在可用空间内取最大尺寸。
Size fieldFitSize(Size available, [double maxWidth = kFieldMaxWidth]) {
  final limit = math.max(0.0, available.width);
  final ceiling = math.max(0.0, available.height);
  if (limit <= 0 || ceiling <= 0) return Size.zero;
  var width = math.min(limit, maxWidth);
  var height = width / Field.aspect;
  if (height > ceiling) {
    height = ceiling;
    width = height * Field.aspect;
  }
  return Size(width, height);
}

class HudMetrics {
  const HudMetrics({
    required this.field,
    required this.rail,
    required this.compact,
    required this.sideRail,
  });

  final Size field;
  final double rail;
  final bool compact;
  final bool sideRail;
}

/// 计算对局页的排版决策：操作按钮固定在下方，左右留白够宽时标题、战况与
/// 得分挂到战场两侧，否则排到战场上方。
HudMetrics resolveHud(
  Size area, {
  double maxWidth = kFieldMaxWidth,
  double textScale = 1,
}) {
  final scale = _scale(textScale);
  final compact = area.height < kHudCompactHeight;
  final bottom = _bottomReserve(compact, scale);
  final railField = fieldFitSize(
    Size(area.width, math.max(0, area.height - bottom)),
    maxWidth,
  );
  final rail = math.max(0.0, (area.width - railField.width) / 2);
  if (rail >= kHudRailWidth) {
    return HudMetrics(
      field: railField,
      rail: rail,
      compact: compact,
      sideRail: true,
    );
  }
  final top = _topReserve(area.width < kHudStackedWidth, compact, scale);
  return HudMetrics(
    field: fieldFitSize(
      Size(area.width, math.max(0, area.height - top - bottom)),
      maxWidth,
    ),
    rail: rail,
    compact: compact,
    sideRail: false,
  );
}

/// 横屏是否给战场带来更大的显示面积。
bool fieldFitsBetterLandscape(
  Size area, {
  double maxWidth = kFieldMaxWidth,
  double textScale = 1,
}) {
  if (area.width <= 0 || area.height <= 0) return false;
  final portrait = resolveHud(
    area,
    maxWidth: maxWidth,
    textScale: textScale,
  ).field;
  final landscape = resolveHud(
    Size(area.height, area.width),
    maxWidth: maxWidth,
    textScale: textScale,
  ).field;
  return landscape.width * landscape.height >
      portrait.width * portrait.height;
}

double _scale(double textScale) => textScale.clamp(1.0, 1.35).toDouble();

double _topReserve(bool stacked, bool compact, double scale) {
  final title = compact ? kHudCompactTitleRow : kHudTitleRow;
  final info = compact ? kHudCompactInfoRow : kHudInfoRow;
  final rows = stacked ? 2.0 : 1.0;
  return kHudPadding * 2 + (rows * (title + kHudRowGap) + info) * scale;
}

double _bottomReserve(bool compact, double scale) =>
    (compact ? kHudCompactBottomRow : kHudBottomRow) * scale;
