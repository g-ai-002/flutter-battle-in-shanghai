import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/battle_config.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'settings_page.dart';
import 'widgets/entry_tile.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/preference_pickers.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// 上下留白保持对称，内容块在全屏窗口里严格居中。
  static const double _verticalPadding = 18;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final entries = _entries(context, settings, colors);
    // 入口与出战配置在宽窄布局里顺序一致，只换外层排列。
    final side = <Widget>[
      _EntryGrid(entries: entries),
      const SizedBox(height: 18),
      _Loadout(settings: settings),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF241A13), Color(0xFF0F0C08)]
                : const [Color(0xFFF7EFDF), Color(0xFFEADCC2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 宽屏改为「左侧主视觉 + 右侧入口」，一屏放下全部入口。
              final wide =
                  constraints.maxWidth >= 980 && constraints.maxHeight >= 620;
              final compact = constraints.maxWidth < 700;
              final horizontal = constraints.maxWidth >= 900 ? 40.0 : 20.0;
              final maxContent = wide ? 1180.0 : 760.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  _verticalPadding,
                  horizontal,
                  _verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      constraints.maxHeight - _verticalPadding * 2,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContent),
                      child: Column(
                        key: const ValueKey('home-content'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBar(darkMode: settings.darkMode),
                          const SizedBox(height: 20),
                          if (wide)
                            Row(
                              children: [
                                const Expanded(child: _Hero()),
                                const SizedBox(width: 44),
                                SizedBox(
                                  width: 500,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: side,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            // 窄屏先露出入口，避免玩家为了开局先滚一大段主视觉。
                            _Hero(compact: compact),
                            const SizedBox(height: 20),
                            ...side,
                          ],
                          const SizedBox(height: 16),
                          Text(
                            versionLine(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context, BattleMode mode) {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          mode: mode,
          difficulty: settings.difficulty,
          scene: settings.scene,
        ),
      ),
    );
  }

  /// 首页四个入口，宽屏两列、窄屏单列都复用同一份定义。
  List<Widget> _entries(
    BuildContext context,
    SettingsProvider settings,
    ColorScheme colors,
  ) => [
    EntryTile(
      leading: EntryBadge(
        icon: Icons.military_tech_rounded,
        accent: colors.primary,
      ),
      title: '战役模式',
      subtitle: '${settings.scene.label} · 五波敌军 · ${settings.difficulty.label}',
      onTap: () => _start(context, BattleMode.campaign),
    ),
    EntryTile(
      leading: const EntryBadge(
        icon: Icons.all_inclusive_rounded,
        accent: appGold,
      ),
      title: '无尽模式',
      subtitle: '${settings.scene.label} · 敌军无穷 · 挑战最高分',
      onTap: () => _start(context, BattleMode.endless),
    ),
    EntryTile(
      leading: EntryBadge(
        icon: Icons.menu_book_rounded,
        accent: colors.tertiary,
      ),
      title: '作战说明',
      subtitle: '操作 · 敌军 · 补给 · 计分',
      onTap: () => showRulesDialog(context),
    ),
    EntryTile(
      leading: EntryBadge(icon: Icons.tune_rounded, accent: colors.secondary),
      title: '设置',
      subtitle: '难度 · 刷新率 · 音效 · 日志',
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    ),
  ];
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return Row(
      children: [
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: darkMode ? '切换浅色' : '切换深色',
          onPressed: () => settings.setDarkMode(!darkMode),
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        // 圆形徽记代替实时缩略图：首屏更轻，也让标题成为视觉中心。
        Container(
          width: compact ? 92 : 118,
          height: compact ? 92 : 118,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.5),
              width: 1.4,
            ),
            gradient: RadialGradient(
              colors: [
                colors.primary.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
          child: Text(
            '战',
            style: TextStyle(
              fontSize: compact ? 38 : 48,
              height: 1,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          '血战上海滩',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 25 : 32,
            letterSpacing: compact ? 6 : 9,
            color: colors.onSurface,
          ),
        ),
        SizedBox(height: compact ? 7 : 10),
        Text(
          '一 九 三 七 · 上 海',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 2.4,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          '一条街，一座城；弹药有限，退路为零。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 出战配置：阵地、敌军强度与逻辑刷新率。
class _Loadout extends StatelessWidget {
  const _Loadout({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScenePicker(settings: settings),
          const SizedBox(height: 12),
          DifficultyPicker(settings: settings),
          const SizedBox(height: 12),
          LogicRatePicker(settings: settings),
        ],
      ),
    );
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<Widget> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 460;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in entries) SizedBox(width: width, child: entry),
          ],
        );
      },
    );
  }
}
