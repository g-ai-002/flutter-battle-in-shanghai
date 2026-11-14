import 'dart:math' as math;

import 'battle_config.dart';
import 'battle_scenes.dart';
import 'campaign_waves.dart';
import 'wave_plan.dart';

/// 波次调度：选波、排队刷怪、集结倒计时与播报文案都在这里，
/// [BattleSim] 只负责按调度结果生成敌军。
class WaveDirector {
  WaveDirector({
    required this.mode,
    required this.difficulty,
    this.scene = BattleScene.zhabei,
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// 头目入场时的大字提示时长，渲染层按它换算提示淡出进度。
  static const double bossBreak = 2.4;

  /// 普通波次的集结时间。
  static const double waveBreakSeconds = 1.5;

  final BattleMode mode;
  final Difficulty difficulty;

  /// 战役关卡，决定波次表；无尽模式只用它的景物。
  final BattleScene scene;
  final math.Random _random;

  final List<SpawnOrder> _queue = [];
  final List<SpawnOrder> _due = [];
  int _nextSpawn = 0;
  double _spawnBase = 0;

  /// 战役波次表只依赖关卡与难度，开局排一次即可，不必每波重建。
  List<WavePlan>? _campaignPlans;

  WavePlan? plan;
  int wave = 0;
  double waveBreak = 0;
  double announceTimer = 0;

  /// 战役模式的总波数，无尽模式返回 0。
  int get waveCount => mode == BattleMode.campaign ? kCampaignWaves : 0;

  bool get boss => plan?.boss ?? false;

  /// 当前波次对敌军生命的额外倍率。
  double get hpMultiplier => plan?.hpMultiplier ?? 1;

  /// 尚未进场的敌军数量。
  int get pendingSpawns => _queue.length - _nextSpawn;

  bool get allSpawned => _nextSpawn >= _queue.length;

  bool get bossWarning => boss && waveBreak > 0;

  bool get announcing => announceTimer > 0;

  /// 集结阶段的提示淡出进度。
  double get announcementProgress => (waveBreak / bossBreak).clamp(0.0, 1.0);

  /// 当前波次的阵型名称。
  String get waveName => plan?.name ?? '';

  String get announcement {
    if (plan == null) return '';
    if (boss) return '警告 · ${scene.bossName} 接近';
    if (waveName.isEmpty) return '第 $wave 波 · 敌军逼近';
    return '第 $wave 波 · $waveName';
  }

  /// 集结期间战况条使用的短语。
  String get phaseBrief => boss ? '头目正在逼近' : '敌军集结中';

  /// 开始第 [index] 波，返回应当播放的提示音。
  BattleCue begin(int index, double now) {
    wave = index;
    plan = _planFor(index);
    _queue
      ..clear()
      ..addAll(plan!.orders)
      ..sort((a, b) => a.at.compareTo(b.at));
    _nextSpawn = 0;
    waveBreak = boss ? bossBreak : waveBreakSeconds;
    _spawnBase = now + waveBreak;
    announceTimer = waveBreak;
    return boss ? BattleCue.boss : BattleCue.wave;
  }

  WavePlan _planFor(int index) {
    if (mode == BattleMode.campaign) {
      final plans = _campaignPlans ??= sceneWaves(scene, difficulty);
      return plans[index - 1];
    }
    return endlessWave(index, difficulty, random: _random);
  }

  /// 推进集结倒计时。
  void tick(double dt) {
    if (waveBreak > 0) waveBreak -= dt;
  }

  /// 推进大字播报计时，与集结倒计时独立。
  void tickAnnouncement(double dt) {
    if (announceTimer > 0) announceTimer -= dt;
  }

  /// 取出当前逻辑时间应当出现的刷怪指令。
  ///
  /// 返回的列表在帧内即被消费，复用同一个缓冲即可，刷怪时不再分配新列表。
  List<SpawnOrder> takeDue(double now) {
    if (allSpawned) return const [];
    final elapsed = now - _spawnBase;
    var count = 0;
    while (_nextSpawn + count < _queue.length &&
        _queue[_nextSpawn + count].at <= elapsed) {
      count++;
    }
    if (count == 0) return const [];
    _due
      ..clear()
      ..addAll(_queue.getRange(_nextSpawn, _nextSpawn + count));
    _nextSpawn += count;
    return _due;
  }

  void reset() {
    _queue.clear();
    _due.clear();
    _nextSpawn = 0;
    _spawnBase = 0;
    plan = null;
    wave = 0;
    waveBreak = 0;
    announceTimer = 0;
  }
}
