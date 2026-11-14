import 'package:material_ui/material_ui.dart';

import '../../game/battle_controller.dart';
import '../../game/entities.dart';
import '../../theme/app_theme.dart';
import 'battle_hud.dart';

/// 战斗页底部控制条：手雷、暂停、重开、音效。
///
/// 按钮浮在战场下方，紧凑模式下只留图标，避免挤占战场空间。
class BattleControls extends StatelessWidget {
  const BattleControls({
    super.key,
    required this.controller,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.onRestart,
    required this.onOpenPause,
  });

  final BattleController controller;
  final bool soundEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onRestart;
  final VoidCallback onOpenPause;

  @override
  Widget build(BuildContext context) {
    final sim = controller.sim;
    final running = sim.status == BattleStatus.running;
    final cooldown = sim.grenadeCooldownLeft;
    final ready = cooldown <= 0 && running;
    final coverCooldown = sim.coverCooldownLeft;
    final coverFull = sim.coverCount >= sim.coverLimit;
    final coverReady = coverCooldown <= 0 && !coverFull && running;
    final airstrikeCooldown = sim.airstrikeCooldownLeft;
    final airstrikeReady = airstrikeCooldown <= 0 && running;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 2,
      runSpacing: 2,
      children: [
        _ActionButton(
          icon: Icons.foundation_rounded,
          label: coverReady
              ? '工事'
              : coverFull
              ? '工事 ${sim.coverCount}/${sim.coverLimit}'
              : '${coverCooldown.ceil()}s',
          onPressed: coverReady ? () => controller.deployCover() : null,
        ),
        _ActionButton(
          icon: Icons.flight_rounded,
          label: airstrikeReady ? '空袭' : '${airstrikeCooldown.ceil()}s',
          accent: airstrikeReady ? appGold : null,
          onPressed: airstrikeReady ? () => controller.callAirstrike() : null,
        ),
        _ActionButton(
          icon: Icons.local_fire_department_rounded,
          label: ready ? '手雷' : '${cooldown.ceil()}s',
          accent: ready ? appFlame : null,
          onPressed: ready ? () => controller.throwGrenade() : null,
        ),
        _ActionButton(
          icon: sim.status == BattleStatus.paused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          label: sim.status == BattleStatus.paused ? '继续' : '暂停',
          onPressed: controller.finished ? null : onOpenPause,
        ),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: '重开',
          onPressed: onRestart,
        ),
        _ActionButton(
          icon: soundEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: soundEnabled ? '音效' : '静音',
          onPressed: onToggleSound,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;
    // 紧凑 HUD 里只留图标，一串按钮并排也不会把战场挤小。
    final compact = HudScope.compactOf(context);
    final color = accent ?? (enabled ? colors.onSurface : colors.onSurfaceVariant);
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(compact ? 38 : 54, compact ? 38 : 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 0 : 2,
        ),
        foregroundColor: color,
      ),
      child: compact
          ? Icon(icon, size: 21)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: color,
                  ),
                ),
              ],
            ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}
