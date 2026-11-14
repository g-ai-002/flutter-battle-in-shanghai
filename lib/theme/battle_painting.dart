/// 战场美术的统一出口：街景、阵地景物、地面单位与战斗特效各自成模块。
///
/// 所有模块都在「战场逻辑坐标」下作画（0..300 × 0..400），调用方先统一
/// 缩放，因此同一套画法在手机、桌面与 Web 上比例完全一致。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../utils/constants.dart';

export 'effect_art.dart';
export 'scene_props.dart';
export 'street_art.dart';
export 'unit_art.dart';

/// 波次提示文字的样式。
TextStyle battlefieldLabelStyle({
  required double fontSize,
  Color color = const Color(0xFFF6E4C6),
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.6,
}) => TextStyle(
  fontSize: fontSize,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: 1.1,
  // Web 的 CanvasKit 没有系统中文字体回退，Wave 提示必须显式指定字体。
  fontFamily: kIsWeb ? kWebFontFamily : null,
);
