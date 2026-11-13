import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/battle_config.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../utils/formatters.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/preference_pickers.dart';
import 'widgets/section_card.dart';
import 'widgets/stat_row.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final records = settings.records;
    final logPath = LogService.logFilePath;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: '画面',
            icon: Icons.palette_outlined,
            children: [
              _SwitchRow(
                title: '深色模式',
                subtitle: '夜间作战时更省眼',
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '战斗',
            icon: Icons.sports_martial_arts_rounded,
            children: [
              DifficultyPicker(settings: settings),
              const SizedBox(height: 14),
              LogicRatePicker(settings: settings),
              const SizedBox(height: 10),
              Text(
                '逻辑刷新率决定战场模拟的步进频率，与屏幕刷新解耦；'
                '30Hz 省电，120Hz 更顺滑，低端设备建议 60Hz。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '声音与震动',
            icon: Icons.volume_up_outlined,
            children: [
              _SwitchRow(
                title: '音效',
                subtitle: '枪声、爆炸与拾取提示音',
                value: settings.soundEnabled,
                onChanged: settings.setSoundEnabled,
              ),
              _SwitchRow(
                title: '背景音乐',
                subtitle: '运行时合成的军鼓与号声',
                value: settings.musicEnabled,
                onChanged: settings.setMusicEnabled,
              ),
              _SwitchRow(
                title: '震动反馈',
                subtitle: '受伤、爆炸与头目出现时震动',
                value: settings.hapticsEnabled,
                onChanged: settings.setHapticsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '战绩',
            icon: Icons.emoji_events_outlined,
            children: [
              StatRow(label: '最高分', value: formatScore(records.bestScore)),
              StatRow(label: '最远波次', value: '第 ${records.bestWave} 波'),
              StatRow(label: '累计击杀', value: '${records.totalKills}'),
              StatRow(label: '出战次数', value: '${records.runs}'),
              StatRow(
                label: '通关次数',
                value:
                    '${records.victories}'
                    '${records.runs > 0 ? ' · 通关率 ${(records.winRate * 100).round()}%' : ''}',
              ),
              const SizedBox(height: 8),
              Text(
                '战绩保存在本机，卸载应用即清除。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '运行日志',
            icon: Icons.receipt_long_outlined,
            children: [
              Text(
                logPath.isEmpty
                    ? 'Web 端日志仅保留在当前页面内存中，刷新后清空。'
                    : logPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showLogDialog(
                      context,
                      LogService.getRecentLogs(300),
                    ),
                    icon: const Icon(Icons.subject_rounded, size: 18),
                    label: const Text('查看日志'),
                  ),
                  if (logPath.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          FileSystemService.instance.openLogFolder(),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('打开目录'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '关于',
            icon: Icons.info_outline_rounded,
            children: [
              Text(
                aboutLine(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '基于 Flutter + Flame 的本地单人射击游戏，不含任何联网功能。'
                '所有音效与背景音乐均在运行时合成。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: appFlame),
                  const SizedBox(width: 6),
                  Text(
                    '战场 3:4 · 军需补给 $kCampaignWaves 波战役',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
