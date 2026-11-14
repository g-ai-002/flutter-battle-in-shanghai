import 'package:flutter/material.dart';

/// 状态胶囊：淡底细边的圆角标语，战况条与标签共用。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
  });

  final Color accent;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}
