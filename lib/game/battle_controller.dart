import 'package:flutter/foundation.dart';

import '../services/log_service.dart';
import '../services/sound_service.dart';
import 'battle_config.dart';
import 'battle_sim.dart';
import 'entities.dart';
import 'logic_rate.dart';

/// 键盘移动方向。
enum MoveAxis { left, right, up, down }

/// 战斗控制器：固定步长推进模拟、转交音效、按需刷新 HUD。
///
/// 渲染层每帧调用 [advance]，但只有状态真正变化时才 [notifyListeners]，
/// 因此 HUD 不会跟着 120Hz 的逻辑刷新一起重建。
class BattleController extends ChangeNotifier {
  BattleController({
    required this.mode,
    required this.difficulty,
    LogicRate logicRate = LogicRate.hz60,
    BattleSim? sim,
  }) : sim = sim ?? BattleSim(mode: mode, difficulty: difficulty),
       _stepper = FixedStepClock(logicRate.step);

  final BattleMode mode;
  final Difficulty difficulty;
  final BattleSim sim;
  final FixedStepClock _stepper;
  final Set<MoveAxis> _pressed = {};

  int _hudSignature = -1;
  bool _disposed = false;
  BattleStatus _lastStatus = BattleStatus.ready;

  BattleStatus get status => sim.status;
  bool get paused => sim.status == BattleStatus.paused;
  bool get finished => sim.finished;

  /// 拖动的灵敏度：手指移动 1px，角色跟随 1.15 个战场单位。
  static const double dragScale = 1.15;

  void start() {
    sim.start();
    _lastStatus = sim.status;
    _forceNotify();
  }

  void advance(double dt) {
    if (_disposed) return;
    _stepper.advance(dt, _step);
  }

  void _step(double span) {
    var dx = 0.0;
    var dy = 0.0;
    if (_pressed.contains(MoveAxis.left)) dx -= 1;
    if (_pressed.contains(MoveAxis.right)) dx += 1;
    if (_pressed.contains(MoveAxis.up)) dy -= 1;
    if (_pressed.contains(MoveAxis.down)) dy += 1;
    if (dx != 0 || dy != 0) {
      final norm = (dx != 0 && dy != 0)
          ? 0.7071067811865476
          : 1.0;
      sim.movePlayer(
        dx * norm * kPlayerSpeed * span,
        dy * norm * kPlayerSpeed * span,
      );
    }
    sim.update(span);
    _drainCues();
    _syncStatus();
    _notifyIfChanged();
  }

  void _drainCues() {
    if (sim.cues.isEmpty) return;
    final cues = List.of(sim.cues);
    sim.cues.clear();
    for (final cue in cues) {
      SoundService.play(cue);
    }
  }

  void _syncStatus() {
    if (sim.status == _lastStatus) return;
    _lastStatus = sim.status;
    switch (sim.status) {
      case BattleStatus.won:
        LogService.info(
          '战斗胜利: 得分 ${sim.score}, 击杀 ${sim.kills}, '
          '波次 ${sim.wave}, 用时 ${sim.time.toStringAsFixed(1)}s',
        );
      case BattleStatus.lost:
        LogService.info(
          '战斗失败: 得分 ${sim.score}, 击杀 ${sim.kills}, 波次 ${sim.wave}',
        );
      default:
        break;
    }
  }

  void setPressed(MoveAxis axis, bool pressed) {
    if (pressed) {
      _pressed.add(axis);
    } else {
      _pressed.remove(axis);
    }
  }

  void clearPressed() => _pressed.clear();

  /// 触屏 / 鼠标拖动：按下时记录起点，移动时按位移推进角色。
  void dragBy(double dx, double dy) {
    if (paused || finished) return;
    sim.movePlayer(dx * dragScale, dy * dragScale);
  }

  bool throwGrenade() {
    if (paused || finished) return false;
    final thrown = sim.throwGrenade();
    if (thrown) _forceNotify();
    return thrown;
  }

  void togglePause() {
    if (sim.status == BattleStatus.running) {
      sim.pause();
      clearPressed();
    } else if (sim.status == BattleStatus.paused) {
      sim.resume();
    }
    _forceNotify();
  }

  void pause() {
    if (sim.status != BattleStatus.running) return;
    sim.pause();
    clearPressed();
    _forceNotify();
  }

  void resume() {
    if (sim.status != BattleStatus.paused) return;
    sim.resume();
    _forceNotify();
  }

  void restart() {
    sim.restart();
    _pressed.clear();
    _lastStatus = sim.status;
    _forceNotify();
  }

  /// HUD 只在这些数值变化时重建。
  int _signature() {
    final boss = sim.boss;
    var hash = sim.status.index;
    hash = hash * 31 + sim.player.hp.round();
    hash = hash * 31 + sim.score;
    hash = hash * 31 + sim.combo;
    hash = hash * 31 + sim.wave;
    hash = hash * 31 + sim.player.weapon.index;
    hash = hash * 31 + sim.weaponSecondsLeft.ceil();
    hash = hash * 31 + sim.grenadeCooldownLeft.ceil();
    hash = hash * 31 + sim.remainingEnemies;
    hash = hash * 31 + sim.kills;
    hash = hash * 31 + (boss == null ? -1 : (boss.hpRatio * 100).round());
    return hash;
  }

  void _notifyIfChanged() {
    final signature = _signature();
    if (signature == _hudSignature) return;
    _hudSignature = signature;
    notifyListeners();
  }

  void _forceNotify() {
    _hudSignature = _signature();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pressed.clear();
    super.dispose();
  }
}
