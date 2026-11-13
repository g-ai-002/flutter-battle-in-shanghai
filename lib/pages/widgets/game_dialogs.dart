import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/battle_config.dart';
import '../../game/battle_sim.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'stat_row.dart';

/// 终局结算：得分、击杀、波次与最高分对比。
Future<void> showBattleResultDialog(
  BuildContext context, {
  required BattleResult result,
  required int bestScore,
  required bool newRecord,
  required VoidCallback onRestart,
  required VoidCallback onExit,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final won = result.won;
  final accent = won ? const Color(0xFF7FBF6A) : appFlame;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(
            won ? Icons.military_tech_rounded : Icons.local_fire_department,
            color: accent,
          ),
          const SizedBox(width: 8),
          Text(won ? '阵地守住了' : '阵地失守'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              won ? '五波敌军尽数击退，街垒仍在手中。' : '敌军突破了防线，整备弹药再战一场。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatScore(result.score),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: appGold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '分',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (newRecord)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: appGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: appGold.withValues(alpha: 0.6)),
                    ),
                    child: const Text(
                      '新纪录',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: appGold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '最高分 ${formatScore(bestScore)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            StatRow(
              label: '抵达波次',
              value: '第 ${result.wave} 波',
              padding: const EdgeInsets.symmetric(vertical: 3),
            ),
            StatRow(
              label: '击破敌军',
              value: '${result.kills}',
              padding: const EdgeInsets.symmetric(vertical: 3),
            ),
            StatRow(
              label: '最高连击',
              value: '${result.maxCombo}',
              padding: const EdgeInsets.symmetric(vertical: 3),
            ),
            StatRow(
              label: '作战时长',
              value: _duration(result.seconds),
              padding: const EdgeInsets.symmetric(vertical: 3),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onExit();
          },
          child: const Text('返回营地'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onRestart();
          },
          child: const Text('再来一局'),
        ),
      ],
    ),
  );
}

/// 暂停菜单的选择结果。
enum PauseAction { resume, restart, exit }

/// 暂停菜单：继续、重开或撤退。点外部关闭等同于继续。
Future<PauseAction> showPauseDialog(BuildContext context) async {
  final action = await showDialog<PauseAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('战斗暂停'),
      content: const Text('街垒暂歇，随时可以继续。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(PauseAction.exit),
          child: const Text('撤退'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(PauseAction.restart),
          child: const Text('重开'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(PauseAction.resume),
          child: const Text('继续'),
        ),
      ],
    ),
  );
  return action ?? PauseAction.resume;
}

/// 作战说明：操作、敌军与补给。
Future<void> showRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('作战说明'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleSection(
              title: '操作',
              lines: [
                '拖动战场任意位置移动士兵，火力自动朝正前方倾泻。',
                '桌面端可用 WASD / 方向键移动，空格投掷手雷，Q 布置工事，E 呼叫空袭。',
                '手雷有 ${kGrenadeCooldown.round()} 秒冷却，优先炸装甲车与头目。',
              ],
            ),
            _RuleSection(
              title: '工事与空袭',
              lines: [
                '工事是沙袋掩体，挡得住敌军子弹，却会被步兵一点点挖开，'
                    '${kCoverLife.round()} 秒后自然失效。',
                '站在工事后方的掩护范围内可减伤 ${(kCoverShelterReduction * 100).round()}%，'
                    '战况条会亮起「掩体」标记。',
                '空袭有 ${kAirstrikeCooldown.round()} 秒冷却，自动轰炸敌军最密集处，'
                    '落点先有预警圈。',
              ],
            ),
            const _RuleSection(
              title: '敌军',
              lines: [
                '步兵径直推进，靠近街垒会造成大量伤害。',
                '枪手与掷弹兵停下后开火，优先点掉。',
                '装甲车皮厚，霰弹枪与手雷更有效。',
                '每五波出现一次头目，留意扇形弹幕。',
              ],
            ),
            const _RuleSection(
              title: '补给',
              lines: [
                '急救包回复 30 点生命。',
                '弹药箱提供冲锋枪或霰弹枪，限时使用。',
                '钢盔提供 6 秒护盾，可以硬闯弹幕。',
              ],
            ),
            const _RuleSection(
              title: '计分',
              lines: [
                '连续击杀累积倍率，最高 3 倍。',
                '清空一波与击破头目都有额外奖励。',
                '战役通关需要击退全部五波敌军。',
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('明白了'),
        ),
      ],
    ),
  );
}

/// 日志查看：设置页使用，Web 端只展示内存日志。
Future<void> showLogDialog(BuildContext context, List<String> lines) {
  final colors = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('最近日志'),
      content: SizedBox(
        width: 560,
        height: math.min(380, MediaQuery.sizeOf(context).height * 0.5),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              lines.isEmpty ? '暂无日志' : lines.join('\n'),
              style: const TextStyle(fontSize: 10.5, height: 1.45),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(color: appFlame),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $line',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

String _duration(double seconds) {
  final total = seconds.round();
  final minutes = total ~/ 60;
  final rest = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
