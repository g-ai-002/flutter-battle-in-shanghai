/// 战役关卡：四处阵地各有自己的街景、波次编排与强度。
///
/// 顺序即解锁顺序：通关前一处才能进入下一处。
enum BattleScene {
  zhabei('闸北', '街巷', '断壁残垣间的正面巷战', 0x5A17, 1.0, '九七式指挥车'),
  bund('外滩', '江岸', '沿江开阔地，敌军从街口压上', 0x7B31, 1.15, '海军陆战队炮车'),
  warehouse('四行仓库', '仓库', '背水死守，退到仓库墙根', 0x9C4D, 1.3, '重型突击炮'),
  suzhou('苏州河', '铁桥', '跨过铁桥，就是最后的生路', 0xB25F, 1.45, '九四式装甲炮艇');

  const BattleScene(
    this.label,
    this.terrain,
    this.tagline,
    this.seed,
    this.hpScale,
    this.bossName,
  );

  final String label;

  /// 地形短语，例如「街巷」，与地名拼成「闸北 · 街巷」。
  final String terrain;

  final String tagline;

  /// 波次编排的固定随机种子，保证同一关每次阵型一致。
  final int seed;

  /// 该关敌军的额外生命倍率，越靠后的阵地越难打。
  final double hpScale;

  /// 该关头目的名字，播报、战况条与结算共用。
  final String bossName;

  String get title => '$label · $terrain';

  BattleScene? get next => index + 1 < values.length ? values[index + 1] : null;

  BattleScene? get previous => index > 0 ? values[index - 1] : null;

  static BattleScene byName(String? name) => values.firstWhere(
    (scene) => scene.name == name,
    orElse: () => BattleScene.zhabei,
  );
}
