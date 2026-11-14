import 'package:material_ui/material_ui.dart';

import '../../game/battle_config.dart';
import '../../game/battle_sim.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'battle_hud.dart';
import 'status_chip.dart';

/// 生命与护盾一行：数值 + 细长血条。
class HpLine extends StatelessWidget {
  const HpLine({super.key, required this.sim});

  final BattleSim sim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = HudScope.compactOf(context);
    final player = sim.player;
    final ratio = player.hpRatio;
    final color = ratio > 0.5
        ? const Color(0xFF7FBF6A)
        : ratio > 0.25
        ? const Color(0xFFE0A94A)
        : const Color(0xFFE2604A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sim.shieldActive ? Icons.shield_rounded : Icons.favorite_rounded,
          size: compact ? 12 : 14,
          color: sim.shieldActive ? const Color(0xFF7FC4E8) : color,
        ),
        const SizedBox(width: 5),
        Text(
          '${player.hp.round()}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: compact ? 10.5 : 12,
          ),
        ),
        const SizedBox(width: 6),
        // 侧栏较窄时血条自动收缩，不会把标题卡撑破。
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 74 : 96),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: colors.outline.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        if (sim.shieldActive) ...[
          const SizedBox(width: 5),
          Text(
            '${(player.shieldUntil - sim.time).ceil()}s',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: const Color(0xFF7FC4E8),
            ),
          ),
        ],
      ],
    );
  }
}

/// 当前武器与剩余时间。
class WeaponLine extends StatelessWidget {
  const WeaponLine({super.key, required this.sim});

  final BattleSim sim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = HudScope.compactOf(context);
    final weapon = sim.player.weapon;
    final spec = sim.player.weaponSpec;
    final seconds = sim.weaponSecondsLeft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          weapon == WeaponKind.pistol
              ? Icons.gps_fixed_rounded
              : weapon == WeaponKind.smg
              ? Icons.bolt_rounded
              : Icons.grain_rounded,
          size: compact ? 11 : 13,
          color: spec.color,
        ),
        const SizedBox(width: 4),
        Text(
          weapon.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: compact ? 9 : 10.5,
          ),
        ),
        if (seconds > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${seconds.ceil()}s',
            style: theme.textTheme.labelSmall?.copyWith(
              color: spec.color,
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// 得分与连击倍率：战场右侧/上方的计分卡。
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.sim});

  final BattleSim sim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = HudScope.compactOf(context);
    final multiplier = sim.comboMultiplier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: appGold,
            ),
            const SizedBox(width: 4),
            Text(
              formatScore(sim.score),
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Text(
          sim.combo >= 2
              ? '连击 ${sim.combo} · ${multiplier.toStringAsFixed(2)}x'
              : '累计得分',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: compact ? 8.5 : 9.5,
            color: sim.combo >= 2 ? appGold : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        WeaponLine(sim: sim),
      ],
    );
  }
}

/// 战况条：当前波次、剩余敌军与头目血条。
class BattleStatusBar extends StatelessWidget {
  const BattleStatusBar({super.key, required this.sim});

  final BattleSim sim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = HudScope.compactOf(context);
    final boss = sim.boss;
    final danger = sim.bossWarning || boss != null;
    final accent = danger ? const Color(0xFFE2604A) : colors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip(
              accent: accent,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 3 : 4,
              ),
              child: Text(
                sim.waveCount > 0
                    ? '第 ${sim.wave}/${sim.waveCount} 波'
                    : '第 ${sim.wave} 波',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 9.5 : 10.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (sim.sheltering) ...[
              StatusChip(
                accent: const Color(0xFF6FA8C8),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 2 : 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: compact ? 9 : 11,
                      color: const Color(0xFF6FA8C8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '掩体',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF6FA8C8),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 9 : 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                sim.brief,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 10 : 11.5,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (boss != null) ...[
          const SizedBox(height: 5),
          SizedBox(
            width: compact ? 150 : 210,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: boss.hpRatio,
                minHeight: 4,
                backgroundColor: colors.outline.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFE2604A)),
              ),
            ),
          ),
        ],
        if (compact) ...[
          const SizedBox(height: 4),
          WeaponLine(sim: sim),
        ],
      ],
    );
  }
}
