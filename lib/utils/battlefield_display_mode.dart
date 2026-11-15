import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'battlefield_layout.dart';

/// 手机等窄屏设备是否值得为战场横屏全屏。
///
/// 战场是 3:4 的竖向矩形，横屏会把屏幕高度对折给战场，多数手机上战场反而
/// 更小，因此按实际可用的战场面积比较：横屏更大才旋转并隐藏系统栏，否则
/// 保持用户当前的竖屏方向。平板、桌面与 Web 从不改变方向。
bool shouldImmersiveLandscape(Size size) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  // 统一折算成竖屏尺寸再比较：横屏后宽高互换，判定结果必须保持不变，
  // 否则会在锁定与恢复之间来回旋转。
  final portrait = Size(
    math.min(size.width, size.height),
    math.max(size.width, size.height),
  );
  return portrait.shortestSide < 600 && fieldFitsBetterLandscape(portrait);
}

/// 战场页显示模式：满足 [shouldImmersiveLandscape] 时锁定横屏，
/// 离开后恢复自动旋转。系统栏由 Android 原生沉浸式统一隐藏，页面叠放时
/// 按引用计数只在最后一个退出时恢复方向。
class BattlefieldDisplayMode extends StatefulWidget {
  const BattlefieldDisplayMode({super.key, required this.child});

  final Widget child;

  @override
  State<BattlefieldDisplayMode> createState() =>
      _BattlefieldDisplayModeState();
}

class _BattlefieldDisplayModeState extends State<BattlefieldDisplayMode> {
  static int _holders = 0;

  bool _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wanted = shouldImmersiveLandscape(MediaQuery.sizeOf(context));
    if (wanted == _applied) return;
    _applied = wanted;
    if (wanted) {
      _holders++;
      if (_holders == 1) _enter();
    } else {
      _release();
    }
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _release() {
    if (_holders > 0) _holders--;
    if (_holders > 0) return;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    if (_applied) _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
