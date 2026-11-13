import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_controller.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/game/logic_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('控制器按刷新率推进逻辑，30Hz 与 120Hz 都能前进', () {
    for (final rate in LogicRate.values) {
      final controller = BattleController(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
        logicRate: rate,
      );
      controller.start();
      for (var i = 0; i < 120; i++) {
        controller.advance(1 / 60);
      }
      expect(controller.sim.time, greaterThan(1.6), reason: rate.name);
      controller.dispose();
    }
  });

  test('严重卡顿只推进有限跨度，不会把整秒压进战场', () {
    final controller = BattleController(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
    );
    controller.start();
    controller.advance(5);
    expect(
      controller.sim.time,
      lessThanOrEqualTo(BattleController.maxStepSpan + 1e-6),
    );
    controller.dispose();
  });

  test('暂停、继续与重开切换状态并通知界面', () {
    final controller = BattleController(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
    );
    var notified = 0;
    controller.addListener(() => notified++);
    controller.start();
    expect(controller.status, BattleStatus.running);
    controller.togglePause();
    expect(controller.paused, isTrue);
    controller.togglePause();
    expect(controller.status, BattleStatus.running);
    controller.advance(1 / 60);
    controller.restart();
    expect(controller.sim.wave, 1);
    expect(controller.sim.score, 0);
    expect(notified, greaterThan(0));
    controller.dispose();
  });

  test('拖动与手雷受暂停状态约束', () {
    final controller = BattleController(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
    );
    controller.start();
    final x = controller.sim.player.x;
    controller.dragBy(20, 0);
    expect(controller.sim.player.x, closeTo(x + 20 * BattleController.dragScale, 1e-9));
    expect(controller.throwGrenade(), isTrue);
    controller.pause();
    final afterPause = controller.sim.player.x;
    controller.dragBy(20, 0);
    expect(controller.sim.player.x, afterPause);
    expect(controller.throwGrenade(), isFalse);
    controller.dispose();
  });

  test('完成一局后不再推进时间', () {
    final sim = BattleSim(mode: BattleMode.campaign, difficulty: Difficulty.veteran)
      ..start();
    final controller = BattleController(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
      sim: sim,
    );
    sim.status = BattleStatus.lost;
    final time = sim.time;
    controller.advance(1);
    expect(sim.time, time);
    controller.dispose();
  });
}
