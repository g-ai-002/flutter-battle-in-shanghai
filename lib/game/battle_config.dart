import 'dart:ui';

/// 玩法模式：战役五波通关，无尽模式比拼得分。
enum BattleMode {
  campaign('战役', '五波敌军 · 击破头目'),
  endless('无尽', '敌军无穷 · 挑战高分');

  const BattleMode(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

/// 难度只影响敌军强度与刷怪节奏，不改变规则。
enum Difficulty {
  recruit('新兵', 0.75, 0.65, 1.15),
  veteran('老兵', 1.0, 1.0, 1.0),
  ace('王牌', 1.3, 1.35, 0.85);

  const Difficulty(this.label, this.hpScale, this.damageScale, this.paceScale);
  final String label;

  /// 敌军生命倍率。
  final double hpScale;

  /// 敌军伤害倍率。
  final double damageScale;

  /// 刷怪间隔倍率，越小越密集。
  final double paceScale;

  static Difficulty byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => Difficulty.veteran,
  );
}

/// 三档武器：手枪常驻，冲锋枪与霰弹枪由弹药箱临时提供。
enum WeaponKind {
  pistol('手枪'),
  smg('冲锋枪'),
  shotgun('霰弹枪');

  const WeaponKind(this.label);
  final String label;
}

class WeaponSpec {
  const WeaponSpec({
    required this.interval,
    required this.damage,
    required this.speed,
    required this.pellets,
    required this.spread,
    required this.duration,
    required this.color,
  });

  /// 两发之间的冷却（秒）。
  final double interval;
  final double damage;

  /// 子弹速度，单位/秒。
  final double speed;
  final int pellets;

  /// 弹道总散布角（弧度）。
  final double spread;

  /// 临时武器的持续时间，常驻武器为 0。
  final double duration;
  final Color color;

  static const Map<WeaponKind, WeaponSpec> specs = {
    WeaponKind.pistol: WeaponSpec(
      interval: 0.20,
      damage: 22,
      speed: 520,
      pellets: 1,
      spread: 0.02,
      duration: 0,
      color: Color(0xFFFFD79A),
    ),
    WeaponKind.smg: WeaponSpec(
      interval: 0.075,
      damage: 11,
      speed: 560,
      pellets: 1,
      spread: 0.09,
      duration: 20,
      color: Color(0xFFFFE27A),
    ),
    WeaponKind.shotgun: WeaponSpec(
      interval: 0.52,
      damage: 13,
      speed: 470,
      pellets: 5,
      spread: 0.36,
      duration: 16,
      color: Color(0xFFFFB86B),
    ),
  };
}

/// 敌军兵种。生命、速度都以战场逻辑坐标为单位。
enum EnemyKind {
  infantry('步兵'),
  rifleman('枪手'),
  grenadier('掷弹兵'),
  armoredCar('装甲车'),
  boss('敌军头目');

  const EnemyKind(this.label);
  final String label;
}

class EnemySpec {
  const EnemySpec({
    required this.hp,
    required this.speed,
    required this.radius,
    required this.score,
    required this.contactDamage,
    this.elite = false,
  });

  final double hp;
  final double speed;
  final double radius;
  final int score;
  final double contactDamage;

  /// 精英单位会显示血条并必掉补给。
  final bool elite;

  static const Map<EnemyKind, EnemySpec> specs = {
    EnemyKind.infantry: EnemySpec(
      hp: 34,
      speed: 28,
      radius: 9,
      score: 100,
      contactDamage: 14,
    ),
    EnemyKind.rifleman: EnemySpec(
      hp: 52,
      speed: 30,
      radius: 9,
      score: 150,
      contactDamage: 10,
    ),
    EnemyKind.grenadier: EnemySpec(
      hp: 66,
      speed: 24,
      radius: 10,
      score: 200,
      contactDamage: 12,
    ),
    EnemyKind.armoredCar: EnemySpec(
      hp: 320,
      speed: 18,
      radius: 20,
      score: 400,
      contactDamage: 20,
      elite: true,
    ),
    EnemyKind.boss: EnemySpec(
      hp: 900,
      speed: 12,
      radius: 30,
      score: 2000,
      contactDamage: 24,
      elite: true,
    ),
  };
}

/// 补给类型。
enum PickupKind {
  medkit('急救包'),
  ammo('弹药箱'),
  shield('钢盔');

  const PickupKind(this.label);
  final String label;
}

/// 战斗提示音类型，由控制器转给音效服务。
enum BattleCue {
  shot,
  enemyShot,
  hit,
  explosion,
  pickup,
  hurt,
  wave,
  boss,
  cover,
  airstrike,
  victory,
  defeat,
}

const double kPlayerMaxHp = 100;
const double kPlayerSpeed = 132;
const double kPlayerRadius = 8;
const int kPlayerMaxShieldSeconds = 6;
const double kGrenadeCooldown = 12;
const double kGrenadeDamage = 110;
const double kGrenadeRadius = 58;

/// 工事（沙袋掩体）：玩家布置的临时防线，挡住敌军弹雨但挡不住头顶的炮弹。
const int kCoverMax = 3;
const double kCoverCooldown = 14;
const double kCoverHp = 140;
const double kCoverLife = 22;
const double kCoverHalfWidth = 26;
const double kCoverHeight = 12;

/// 站在工事后方的减伤范围与比例。
const double kCoverShelterRange = 52;
const double kCoverShelterReduction = 0.4;

/// 步兵贴到工事后每秒造成的破坏。
const double kCoverGnawDamage = 12;

/// 空袭支援：一轮三枚炸弹覆盖敌军集群，落点有预警。
const double kAirstrikeCooldown = 30;
const double kAirstrikeInitialDelay = 8;
const double kAirstrikeDamage = 120;
const double kAirstrikeRadius = 62;
const int kAirstrikeBombs = 3;
const double kAirstrikeSpacing = 40;
const double kAirstrikeFuse = 1.2;

/// 战役固定五波，最后一波是头目。
const int kCampaignWaves = 5;

/// 无尽模式每 5 波出现一次头目。
const int kEndlessBossEvery = 5;

/// 连击每累计 [kComboStep] 次击杀提升一档倍率，最高 3 倍。
const int kComboStep = 4;
const double kComboStepBonus = 0.25;
const double kComboWindow = 2.6;
const double kMaxComboMultiplier = 3;

/// 击杀后掉落的补给存在时长。
const double kPickupLife = 9;
