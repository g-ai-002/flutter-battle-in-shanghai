import 'package:material_ui/material_ui.dart';

import '../../game/battle_config.dart';
import '../../game/battle_scenes.dart';
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
  String? unlockedScene,
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
              won
                  ? '${result.scene.label}五波敌军尽数击退，'
                        '${result.scene.bossName}被摧毁，街垒仍在手中。'
                  : '${result.scene.label}的防线被突破，整备弹药再战一场。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (unlockedScene != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: appFlame.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: appFlame.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_rounded, size: 15, color: appFlame),
                    const SizedBox(width: 6),
                    Text(
                      '解锁新阵地 · $unlockedScene',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: appFlame,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            for (final (label, value) in [
              ('抵达波次', '第 ${result.wave} 波'),
              ('击破敌军', '${result.kills}'),
              ('最高连击', '${result.maxCombo}'),
              ('作战时长', _duration(result.seconds)),
            ])
              StatRow(
                label: label,
                value: value,
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
        child: Text(
          '· 拖动战场移动，火力自动朝正前方；桌面端用 WASD / 方向键，'
          '空格手雷、Q 工事、E 空袭。\n'
          '· 工事挡子弹、会被步兵挖开，站在后方减伤 '
          '${(kCoverShelterReduction * 100).round()}%；'
          '空袭轰炸敌军最密集处，落点先有预警圈。\n'
          '· 枪手与掷弹兵停下开火，刀锋兵冲锋快，盾牌兵挡正面子弹，'
          '装甲车皮厚，头目弹幕各不相同。\n'
          '· 急救包回血、弹药箱提供冲锋枪或霰弹枪、'
          '钢盔提供 $kPlayerMaxShieldSeconds 秒护盾。\n'
          '· ${BattleScene.values.length} 处阵地依次解锁：'
          '${BattleScene.values.map((scene) => scene.label).join('、')}；'
          '连击最高 3 倍，清波与击破头目都有额外奖励。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7),
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

String _duration(double seconds) {
  final total = seconds.round();
  final minutes = total ~/ 60;
  final rest = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
