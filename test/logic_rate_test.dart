import 'package:battle_in_shanghai/game/logic_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('逻辑速率枚举提供三档与对应步长', () {
    expect(LogicRate.values, hasLength(3));
    expect(LogicRate.hz30.step, closeTo(1 / 30, 1e-12));
    expect(LogicRate.hz60.step, closeTo(1 / 60, 1e-12));
    expect(LogicRate.hz120.step, closeTo(1 / 120, 1e-12));
    expect(LogicRate.byName(null), LogicRate.hz60);
    expect(LogicRate.byName('unknown'), LogicRate.hz60);
    expect(LogicRate.byName('hz120'), LogicRate.hz120);
  });

  test('固定步长累加器按步长推进', () {
    final clock = FixedStepClock(1 / 60);
    final spans = <double>[];
    final steps = clock.advance(1 / 20, spans.add);
    expect(steps, 3);
    expect(spans.single, closeTo(3 / 60, 1e-9));
  });

  test('不足一步时不推进，累计到下帧', () {
    final clock = FixedStepClock(1 / 60);
    var called = 0;
    expect(clock.advance(1 / 120, (_) => called++), 0);
    expect(called, 0);
    expect(clock.advance(1 / 120, (_) => called++), 1);
    expect(called, 1);
  });

  test('卡顿后的积压时间合并推进，且不超过最大步数', () {
    final clock = FixedStepClock(1 / 60);
    final spans = <double>[];
    final steps = clock.advance(1.0, spans.add);
    expect(steps, 4);
    expect(spans.single, greaterThanOrEqualTo(4 / 60));
    expect(spans.single, lessThan(1.2));
  });

  test('非正的时间增量直接忽略', () {
    final clock = FixedStepClock(1 / 60);
    var called = false;
    expect(clock.advance(0, (_) => called = true), 0);
    expect(clock.advance(-1, (_) => called = true), 0);
    expect(called, isFalse);
  });
}
