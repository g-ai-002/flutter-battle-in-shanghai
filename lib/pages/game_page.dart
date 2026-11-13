import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../flame/battle_game.dart';
import '../game/battle_config.dart';
import '../game/battle_controller.dart';
import '../game/battle_scenes.dart';
import '../game/battle_sim.dart';
import '../game/entities.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../utils/battlefield_display_mode.dart';
import 'widgets/battle_hud.dart';
import 'widgets/battlefield_stage.dart';
import 'widgets/control_bar.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/hud_cards.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.mode,
    required this.difficulty,
    this.scene = BattleScene.zhabei,
  });

  final BattleMode mode;
  final Difficulty difficulty;
  final BattleScene scene;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final BattleController _controller;
  late final BattleGame _game;
  final FocusNode _focusNode = FocusNode(debugLabel: 'battle');

  bool _resultShown = false;
  bool _recorded = false;
  bool _allowPop = false;
  bool _pausedByLifecycle = false;
  bool _pauseDialogOpen = false;
  int _bestBefore = 0;
  String? _unlockedScene;
  Timer? _settleTimer;

  /// 结算特效播完后的静置时长，之后停掉渲染循环。
  static const Duration _settleDelay = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = context.read<SettingsProvider>();
    _bestBefore = settings.records.bestScore;
    _controller = BattleController(
      mode: widget.mode,
      difficulty: widget.difficulty,
      scene: widget.scene,
      logicRate: settings.logicRate,
    );
    _game = BattleGame(controller: _controller);
    _controller.addListener(_onControllerChanged);
    LogService.info(
      '开始战斗: ${widget.mode.label}, 阵地 ${widget.scene.label}, '
      '难度 ${widget.difficulty.label}, 逻辑 ${settings.logicRate.label}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // 切后台立即暂停并停掉渲染循环，回来时不会白跑一局。
        if (_controller.status == BattleStatus.running) {
          _pausedByLifecycle = true;
          _controller.pause();
          _game.sleep();
        }
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          _game.wake();
          // 回到前台补一次暂停菜单，避免玩家还没准备好就被敌军包围。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller.status == BattleStatus.paused) {
              unawaited(_openPause());
            }
          });
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final status = _controller.status;
    if (status != BattleStatus.won && status != BattleStatus.lost) return;
    if (_resultShown) return;
    _resultShown = true;
    final result = _controller.sim.result;
    _recordRun(result);
    // 让击破与失败特效播完，再把战场停住，避免结算弹窗背后空转渲染。
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () {
      if (mounted) _game.sleep();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showBattleResultDialog(
        context,
        result: result,
        bestScore: result.score > _bestBefore ? result.score : _bestBefore,
        newRecord: result.score > _bestBefore,
        unlockedScene: _unlockedScene,
        onRestart: _restart,
        onExit: _exit,
      );
    });
  }

  void _recordRun(BattleResult result) {
    if (_recorded) return;
    _recorded = true;
    final settings = context.read<SettingsProvider>();
    unawaited(settings.recordRun(result));
    // 战役通关解锁下一处阵地；首次通关才在结算里提示。
    if (result.won && widget.mode == BattleMode.campaign) {
      final next = widget.scene.next;
      if (next != null && !settings.clearedScenes.contains(widget.scene)) {
        _unlockedScene = next.label;
      }
      unawaited(settings.markSceneCleared(widget.scene));
    }
    LogService.info(
      '本局结算: ${widget.scene.label}, ${result.won ? '胜利' : '失利'}, '
      '得分 ${result.score}, 击杀 ${result.kills}, 第 ${result.wave} 波',
    );
  }

  void _restart() {
    _settleTimer?.cancel();
    setState(() {
      _resultShown = false;
      _recorded = false;
      _unlockedScene = null;
      _bestBefore = context.read<SettingsProvider>().records.bestScore;
    });
    _controller.restart();
    _game.wake();
    _focusNode.requestFocus();
  }

  void _exit() {
    _allowPop = true;
    Navigator.of(context).maybePop();
  }

  /// 顶部返回：用暂停菜单接管，避免误触丢局。
  Future<void> _handleBack() async {
    if (_controller.finished) {
      _exit();
      return;
    }
    await _openPause();
  }

  Future<void> _openPause() async {
    if (_pauseDialogOpen || _controller.finished) return;
    _pauseDialogOpen = true;
    final wasRunning = _controller.status == BattleStatus.running;
    if (wasRunning) {
      _controller.pause();
      _game.sleep();
    }
    try {
      final action = await showPauseDialog(context);
      if (!mounted) return;
      switch (action) {
        case PauseAction.resume:
          _controller.resume();
          _game.wake();
          _focusNode.requestFocus();
        case PauseAction.restart:
          _restart();
        case PauseAction.exit:
          final sim = _controller.sim;
          // 刚开局就撤退不必污染战绩。
          if (sim.score > 0 || sim.kills > 0) _recordRun(sim.result);
          _exit();
      }
    } finally {
      _pauseDialogOpen = false;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _controller.throwGrenade();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) _controller.deployCover();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      if (event is KeyDownEvent) _controller.callAirstrike();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) unawaited(_openPause());
      return KeyEventResult.handled;
    }
    final axis = _axisOf(key);
    if (axis == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _controller.setPressed(axis, true);
    } else if (event is KeyUpEvent) {
      _controller.setPressed(axis, false);
    }
    return KeyEventResult.handled;
  }

  MoveAxis? _axisOf(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowLeft ||
    LogicalKeyboardKey.keyA => MoveAxis.left,
    LogicalKeyboardKey.arrowRight ||
    LogicalKeyboardKey.keyD => MoveAxis.right,
    LogicalKeyboardKey.arrowUp ||
    LogicalKeyboardKey.keyW => MoveAxis.up,
    LogicalKeyboardKey.arrowDown ||
    LogicalKeyboardKey.keyS => MoveAxis.down,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // 没有 AppBar 与上下状态条，战场居中；战况浮在战场上方或左侧，
    // 控制按钮统一浮在战场下方。
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: BattlefieldDisplayMode(
        child: Scaffold(
          body: SafeArea(
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _onKey,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, field) => BattleHud(
                  field: field!,
                  topStart: _buildTitle(),
                  topEnd: ScoreCard(sim: _controller.sim),
                  info: BattleStatusBar(sim: _controller.sim),
                  controls: BattleControls(
                    controller: _controller,
                    soundEnabled: settings.soundEnabled,
                    onToggleSound: () =>
                        settings.setSoundEnabled(!settings.soundEnabled),
                    onRestart: _restart,
                    onOpenPause: _openPause,
                  ),
                ),
                child: _buildField(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 标题卡：返回 + 模式与难度 + 生命条。
  Widget _buildTitle() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = HudScope.compactOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.mode.label} · ${widget.scene.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (!compact)
                Text(
                  widget.mode == BattleMode.campaign
                      ? '${widget.difficulty.label} · 守住街垒 · 击退五波敌军'
                      : '${widget.difficulty.label} · 敌军无穷 · 尽量活得更久',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              HpLine(sim: _controller.sim),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField() => RepaintBoundary(
    child: BattlefieldStage(
      game: _game,
      gameKey: const ValueKey('battlefield'),
      onDragBy: _controller.dragBy,
    ),
  );
}
