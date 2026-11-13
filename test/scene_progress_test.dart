import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/scene_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('阵地链', () {
    test('第一处没有上一处，其余与 next 互为反向', () {
      expect(BattleScene.zhabei.previous, isNull);
      for (final scene in BattleScene.values) {
        final next = scene.next;
        if (next != null) expect(next.previous, scene);
      }
    });
  });

  group('阵地进度', () {
    test('初始只开放第一处，其余需要上一处通关', () {
      const progress = SceneProgress();
      expect(progress.isUnlocked(BattleScene.zhabei), isTrue);
      expect(progress.isUnlocked(BattleScene.bund), isFalse);
      expect(progress.isUnlocked(BattleScene.warehouse), isFalse);
      expect(progress.isCleared(BattleScene.zhabei), isFalse);
    });

    test('逐处通关后依次解锁，跳关不会解锁', () {
      const onlyBund = SceneProgress(cleared: {BattleScene.bund});
      expect(onlyBund.isUnlocked(BattleScene.warehouse), isTrue);
      expect(onlyBund.isUnlocked(BattleScene.bund), isFalse);

      const firstTwo = SceneProgress(
        cleared: {BattleScene.zhabei, BattleScene.bund},
      );
      expect(firstTwo.isUnlocked(BattleScene.bund), isTrue);
      expect(firstTwo.isUnlocked(BattleScene.warehouse), isTrue);
    });

    test('首次通关给出下一处作为奖励，重复通关不再提示', () {
      const progress = SceneProgress();
      expect(progress.firstClearReward(BattleScene.zhabei), BattleScene.bund);
      expect(
        progress.firstClearReward(BattleScene.warehouse),
        isNull,
        reason: '最后一处阵地没有下一处',
      );

      const cleared = SceneProgress(cleared: {BattleScene.zhabei});
      expect(
        cleared.firstClearReward(BattleScene.zhabei),
        isNull,
        reason: '再次通关同一处不应重复提示解锁',
      );
      expect(cleared.firstClearReward(BattleScene.bund), BattleScene.warehouse);
    });
  });
}
