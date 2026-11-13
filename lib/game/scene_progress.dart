import 'battle_scenes.dart';

/// 阵地通关进度：只保留「哪些阵地已通关」这一份事实，
/// 解锁状态与首次通关的奖励都由它推导，界面不必各自算下标。
class SceneProgress {
  const SceneProgress({this.cleared = const {}});

  final Set<BattleScene> cleared;

  /// 第一处阵地默认开放，其余需要先通关上一处。
  bool isUnlocked(BattleScene scene) {
    final previous = scene.previous;
    return previous == null || cleared.contains(previous);
  }

  bool isCleared(BattleScene scene) => cleared.contains(scene);

  /// 首次通关 [scene] 时解锁的下一处阵地；重复通关或已是最后一处返回 null。
  BattleScene? firstClearReward(BattleScene scene) =>
      cleared.contains(scene) ? null : scene.next;
}
