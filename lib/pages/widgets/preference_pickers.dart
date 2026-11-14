import 'package:material_ui/material_ui.dart';

import '../../game/battle_config.dart';
import '../../game/battle_scenes.dart';
import '../../game/logic_rate.dart';
import '../../providers/settings_provider.dart';
import 'choice_pill.dart';

/// 阵地选择：首页与设置页共用，未通关的阵地带锁。
class ScenePicker extends StatelessWidget {
  const ScenePicker({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PickerGroup(
      label: '战场阵地',
      hint: '${settings.scene.title} · ${settings.scene.tagline}',
      children: [
        for (final scene in BattleScene.values)
          ChoicePill(
            label: scene.label,
            selected: settings.scene == scene,
            accent: colors.primary,
            locked: !settings.isSceneUnlocked(scene),
            onTap: () => _select(context, scene),
          ),
      ],
    );
  }

  void _select(BuildContext context, BattleScene scene) {
    if (!settings.isSceneUnlocked(scene)) {
      // 未解锁的阵地一定不是第一处，提示只差上一处的名字。
      final previous = scene.previous!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('先通关「${previous.label}」，才能进入${scene.label}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    settings.setScene(scene);
  }
}

/// 难度选择：首页与设置页共用。
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.settings,
    this.label = '敌军强度',
  });

  final SettingsProvider settings;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PickerGroup(
      label: label,
      children: [
        for (final difficulty in Difficulty.values)
          ChoicePill(
            label: difficulty.label,
            selected: settings.difficulty == difficulty,
            accent: colors.primary,
            onTap: () => settings.setDifficulty(difficulty),
          ),
      ],
    );
  }
}

/// 战场逻辑速率选择：设置页使用，默认 60Hz。
class LogicRatePicker extends StatelessWidget {
  const LogicRatePicker({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return _PickerGroup(
      label: '逻辑刷新率',
      children: [
        for (final rate in LogicRate.values)
          ChoicePill(
            label: rate.label,
            selected: settings.logicRate == rate,
            accent: Theme.of(context).colorScheme.primary,
            onTap: () => settings.setLogicRate(rate),
          ),
      ],
    );
  }
}

/// 偏好选择器的统一骨架：小标题 + 一行可换行的胶囊选项。
class _PickerGroup extends StatelessWidget {
  const _PickerGroup({required this.label, required this.children, this.hint});

  final String label;
  final List<Widget> children;

  /// 选项下方的补充说明，例如当前阵地的地形短语。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
