import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../utils/battlefield_layout.dart';

/// 侧栏窄于该宽度时改用紧凑卡片：隐藏次要文字，操作只留图标。
const double _compactRailWidth = 196;

/// 两侧栏的最大宽度，超宽屏上让 HUD 贴着战场而不是甩到屏幕边缘。
const double _maxRailWidth = 300;

/// HUD 密度标记：紧凑模式下卡片只保留关键信息，把空间让给战场。
class HudScope extends InheritedWidget {
  const HudScope({super.key, required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HudScope>()?.compact ?? false;

  @override
  bool updateShouldNotify(HudScope oldWidget) => oldWidget.compact != compact;
}

/// 战斗页的悬浮骨架：战场居中，标题、战况与得分浮在战场上方与两侧，
/// 控制按钮浮在战场下方。
///
/// 上下两条边条按真实内容高度占位，战场只吃剩下的空间，所以提示信息再长、
/// 字号再大也不会盖到战场上；战况行高度固定，文字变长只在行内横向滑动。
class BattleHud extends StatelessWidget {
  const BattleHud({
    super.key,
    required this.field,
    this.topStart,
    this.topEnd,
    this.info,
    this.controls,
    this.maxFieldWidth = kFieldMaxWidth,
    this.padding = const EdgeInsets.all(kHudPadding),
    this.gap = kHudRowGap,
  });

  final Widget field;

  /// 左上角：返回与标题。
  final Widget? topStart;

  /// 右上角：得分与暂停。
  final Widget? topEnd;

  /// 战况、头目血条与武器状态：浮在战场上方或左侧。
  final Widget? info;

  /// 手雷、暂停、重开等控制按钮：浮在战场下方。
  final Widget? controls;

  final double maxFieldWidth;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : maxFieldWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : maxFieldWidth * 4 / 3,
        );
        final metrics = resolveHud(
          area,
          maxWidth: maxFieldWidth,
          textScale: _textScale(context),
        );
        final compact =
            metrics.compact ||
            (metrics.sideRail &&
                math.min(metrics.rail, _maxRailWidth) < _compactRailWidth);
        return Column(
          children: [
            Expanded(
              child: metrics.sideRail
                  ? _railBody(metrics, compact)
                  : _bandBody(context, compact),
            ),
            if (controls != null)
              Padding(
                padding: padding,
                child: Center(
                  child: HudScope(compact: compact, child: controls!),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 两侧栏：标题与战况挂在左栏，得分挂在右栏，战场在两侧栏之间居中。
  Widget _railBody(HudMetrics metrics, bool compact) {
    final railWidth = math.min(metrics.rail, _maxRailWidth);
    final inset = metrics.rail - railWidth;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = fieldFitSize(
                Size(
                  constraints.maxWidth - metrics.rail * 2,
                  constraints.maxHeight,
                ),
                maxFieldWidth,
              );
              return Center(child: SizedBox.fromSize(size: size, child: field));
            },
          ),
        ),
        if (topStart != null || info != null)
          Positioned(
            left: inset,
            top: 0,
            bottom: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topStart != null) _card(topStart!, compact),
                  if (info != null)
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: _card(info!, compact),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (topEnd != null)
          Positioned(
            right: inset,
            top: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topRight,
                child: _card(topEnd!, compact),
              ),
            ),
          ),
      ],
    );
  }

  /// 上下横条：标题与得分在上，战况紧随战场上方，战场吃剩下的高度。
  Widget _bandBody(BuildContext context, bool compact) {
    final hasTop = topStart != null || topEnd != null;
    return Column(
      children: [
        if (hasTop || info != null)
          Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTop) _topWrap(compact),
                if (hasTop && info != null) SizedBox(height: gap),
                if (info != null)
                  SizedBox(
                    height: _infoRowHeight(context, compact),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _card(info!, compact),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = fieldFitSize(constraints.biggest, maxFieldWidth);
              return Center(child: SizedBox.fromSize(size: size, child: field));
            },
          ),
        ),
      ],
    );
  }

  /// 标题与得分并排：放不下时后一个自动换到下一行，不会横向溢出。
  Widget _topWrap(bool compact) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (topStart != null) _card(topStart!, compact),
        if (topEnd != null) _card(topEnd!, compact),
      ],
    );
  }

  double _infoRowHeight(BuildContext context, bool compact) {
    final base = compact ? kHudCompactInfoRow : kHudInfoRow;
    return base * _textScale(context);
  }

  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  /// 悬浮卡片：半透明表面配细边与浅投影，紧贴战场边缘时也不抢视线。
  Widget _card(Widget child, bool compact) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return HudScope(
          compact: compact,
          child: Container(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.90 : 0.94),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
