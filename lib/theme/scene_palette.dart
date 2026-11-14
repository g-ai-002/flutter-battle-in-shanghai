import 'package:flutter/material.dart';

import '../game/battle_scenes.dart';

/// 战场配色：街道、屋顶、路灯与探照灯的颜色。
///
/// 三种配色只在色相上区分阵地，明度与对比保持不变，敌军与弹道在任何
/// 背景下都同样醒目。
class ScenePalette {
  const ScenePalette({
    required this.id,
    required this.roadTop,
    required this.roadBottom,
    required this.walk,
    required this.curb,
    required this.roof,
    required this.roofEdge,
    required this.window,
    required this.lane,
    required this.beam,
    required this.ember,
    required this.rubble,
  });

  /// 渐变画笔缓存的键位，各套配色之间不会互相命中。
  final int id;

  final Color roadTop;
  final Color roadBottom;
  final Color walk;
  final Color curb;
  final Color roof;
  final Color roofEdge;

  /// 亮着的窗与路灯。
  final Color window;

  /// 车道虚线。
  final Color lane;

  /// 探照灯、准星线与环境光。
  final Color beam;

  /// 余烬与火星。
  final Color ember;

  /// 碎石与瓦砾。
  final Color rubble;

  static const ScenePalette zhabei = ScenePalette(
    id: 1,
    roadTop: Color(0xFF31261D),
    roadBottom: Color(0xFF191310),
    walk: Color(0xFF43362A),
    curb: Color(0xFF5E4C38),
    roof: Color(0xFF352B21),
    roofEdge: Color(0xFF4B3C2D),
    window: Color(0xFFCD8C4A),
    lane: Color(0xFF9C8A6A),
    beam: Color(0xFFFFD9A0),
    ember: Color(0xFFFFA24A),
    rubble: Color(0xFF4A3A2B),
  );
}

/// 阵地配色表：新增阵地只在这里补一行，不必再写分支。
const Map<BattleScene, ScenePalette> scenePalettes = {
  BattleScene.zhabei: ScenePalette.zhabei,
  BattleScene.bund: ScenePalette(
    id: 2,
    roadTop: Color(0xFF262A31),
    roadBottom: Color(0xFF13161A),
    walk: Color(0xFF333A42),
    curb: Color(0xFF525C66),
    roof: Color(0xFF2A2F36),
    roofEdge: Color(0xFF3F4852),
    window: Color(0xFFCBA46A),
    lane: Color(0xFF8B97A2),
    beam: Color(0xFFCFE4FF),
    ember: Color(0xFFFFB870),
    rubble: Color(0xFF3D444C),
  ),
  BattleScene.warehouse: ScenePalette(
    id: 3,
    roadTop: Color(0xFF3A2620),
    roadBottom: Color(0xFF1C1210),
    walk: Color(0xFF4A322A),
    curb: Color(0xFF6B4A3A),
    roof: Color(0xFF3C2A22),
    roofEdge: Color(0xFF55392D),
    window: Color(0xFFE0A05A),
    lane: Color(0xFF9C7E60),
    beam: Color(0xFFFFD2A0),
    ember: Color(0xFFFF8C4A),
    rubble: Color(0xFF52382C),
  ),
  BattleScene.suzhou: ScenePalette(
    id: 4,
    roadTop: Color(0xFF232C2D),
    roadBottom: Color(0xFF0F1516),
    walk: Color(0xFF303B3C),
    curb: Color(0xFF4C5B5C),
    roof: Color(0xFF273031),
    roofEdge: Color(0xFF3C4A4B),
    window: Color(0xFFD6A45E),
    lane: Color(0xFF8C9C98),
    beam: Color(0xFFD6EDF2),
    ember: Color(0xFFFFA65A),
    rubble: Color(0xFF374442),
  ),
};

ScenePalette paletteOf(BattleScene scene) => scenePalettes[scene]!;
