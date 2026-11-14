import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/battle_scenes.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/formatters.dart';
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
              StatRow(
                label: '已通关阵地',
                value:
                    '${settings.clearedScenes.length}/${BattleScene.values.length}',
              ),
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
                logPath.isEmpty ? 'Web 端日志输出到浏览器控制台，刷新后清空。' : logPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (logPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => FileSystemService.instance.openLogFolder(),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('打开日志目录'),
                ),
              ],
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

  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}