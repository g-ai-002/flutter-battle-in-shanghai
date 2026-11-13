import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../game/battle_config.dart';
import 'log_service.dart';
import 'tone_synth.dart';

/// 战斗音效与触感反馈。
///
/// 音效由 [synthesizeWav] 在运行时合成，不随包携带音频文件；合成好的 WAV
/// 交给 flutter_soloud 的内存音源播放，Android、Windows 与 Web 共用同一套
/// 实现，Web 的自动播放限制会在用户首次操作页面后解除。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(BattleCue cue)? sink;

  static final Map<BattleCue, AudioSource> _sources = {};
  static final Map<BattleCue, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;
  static DateTime _lastShotAt = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastHitAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 十二种提示音的配方：枪声短促，爆炸低沉，胜负用上下行音阶收束。
  static const Map<BattleCue, List<SynthNote>> _presets = {
    BattleCue.shot: [
      SynthNote(frequency: 1500, start: 0, duration: 0.045, gain: 0.34, noise: 0.5, damp: 6),
      SynthNote(frequency: 320, start: 0, duration: 0.07, gain: 0.42, noise: 0.12, damp: 5),
    ],
    BattleCue.enemyShot: [
      SynthNote(frequency: 980, start: 0, duration: 0.05, gain: 0.22, noise: 0.35, damp: 6),
      SynthNote(frequency: 240, start: 0, duration: 0.06, gain: 0.2, damp: 5),
    ],
    BattleCue.hit: [
      SynthNote(frequency: 1900, start: 0, duration: 0.04, gain: 0.3, noise: 0.25, damp: 8),
    ],
    BattleCue.explosion: [
      SynthNote(frequency: 120, start: 0, duration: 0.42, gain: 0.7, noise: 0.85, damp: 2.4),
      SynthNote(frequency: 62, start: 0, duration: 0.5, gain: 0.6, noise: 0.4, damp: 2.0),
      SynthNote(frequency: 340, start: 0.01, duration: 0.16, gain: 0.28, noise: 0.5, damp: 4),
    ],
    BattleCue.pickup: [
      SynthNote(frequency: 880, start: 0, duration: 0.1, gain: 0.4),
      SynthNote(frequency: 1320, start: 0.08, duration: 0.14, gain: 0.35),
    ],
    BattleCue.hurt: [
      SynthNote(frequency: 280, start: 0, duration: 0.16, noise: 0.3, damp: 3.4),
      SynthNote(frequency: 170, start: 0.02, duration: 0.22, gain: 0.45, damp: 3.0),
    ],
    BattleCue.wave: [
      SynthNote(frequency: 660, start: 0, duration: 0.14, gain: 0.34, damp: 2.6),
      SynthNote(frequency: 990, start: 0.12, duration: 0.2, gain: 0.3),
    ],
    BattleCue.boss: [
      SynthNote(frequency: 110, start: 0, duration: 0.5, gain: 0.55, noise: 0.35, damp: 1.4),
      SynthNote(frequency: 82, start: 0.18, duration: 0.5, noise: 0.3, damp: 1.2),
      SynthNote(frequency: 55, start: 0.36, duration: 0.6, damp: 1.0),
    ],
    BattleCue.cover: [
      SynthNote(frequency: 210, start: 0, duration: 0.09, gain: 0.34, noise: 0.45, damp: 7),
      SynthNote(frequency: 120, start: 0.03, duration: 0.14, gain: 0.4, noise: 0.3, damp: 5),
    ],
    BattleCue.airstrike: [
      SynthNote(frequency: 1560, start: 0, duration: 0.10, gain: 0.26, damp: 3),
      SynthNote(frequency: 1180, start: 0.09, duration: 0.10, gain: 0.26, damp: 3),
      SynthNote(frequency: 860, start: 0.18, duration: 0.12, gain: 0.28, damp: 2.8),
      SynthNote(frequency: 620, start: 0.28, duration: 0.14, gain: 0.3, damp: 2.6),
      SynthNote(frequency: 96, start: 0.34, duration: 0.4, gain: 0.4, noise: 0.3, damp: 1.8),
    ],
    BattleCue.victory: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.18, gain: 0.4),
      SynthNote(frequency: 659.25, start: 0.16, duration: 0.18, gain: 0.4),
      SynthNote(frequency: 783.99, start: 0.32, duration: 0.2, gain: 0.42),
      SynthNote(frequency: 1046.5, start: 0.5, duration: 0.5, gain: 0.45),
    ],
    BattleCue.defeat: [
      SynthNote(frequency: 392, start: 0, duration: 0.22, gain: 0.4),
      SynthNote(frequency: 311.13, start: 0.18, duration: 0.24, gain: 0.4),
      SynthNote(frequency: 261.63, start: 0.38, duration: 0.5, gain: 0.42),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响战斗。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      for (final cue in BattleCue.values) {
        _sources[cue] = await soloud.loadMem(
          'battle-${cue.name}.wav',
          clipOf(cue),
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 某个提示音对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(BattleCue cue) =>
      _clips.putIfAbsent(cue, () => synthesizeWav(_presets[cue]!));

  static void play(BattleCue cue) {
    if (!soundEnabled && !hapticsEnabled) return;
    // 连发武器一秒十几枪、霰弹一次多颗弹丸，重复触发同一音源只会变成噪声，
    // 也白白占用音频与触感通道，因此按最小间隔合并。
    final throttle = cue == BattleCue.shot || cue == BattleCue.hit;
    final now = DateTime.now();
    if (throttle) {
      final last = cue == BattleCue.shot ? _lastShotAt : _lastHitAt;
      final gap = cue == BattleCue.shot ? 45 : 60;
      if (now.difference(last).inMilliseconds < gap) return;
      if (cue == BattleCue.shot) {
        _lastShotAt = now;
      } else {
        _lastHitAt = now;
      }
    }
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(cue);
      } else {
        unawaited(_play(cue));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (cue) {
      BattleCue.hit => HapticFeedback.selectionClick,
      BattleCue.pickup => HapticFeedback.selectionClick,
      BattleCue.hurt => HapticFeedback.heavyImpact,
      BattleCue.explosion => HapticFeedback.mediumImpact,
      BattleCue.boss => HapticFeedback.heavyImpact,
      BattleCue.cover => HapticFeedback.lightImpact,
      BattleCue.airstrike => HapticFeedback.heavyImpact,
      BattleCue.victory => HapticFeedback.vibrate,
      BattleCue.defeat => HapticFeedback.vibrate,
      _ => null,
    };
    haptic?.call();
  }

  static Future<void> _play(BattleCue cue) async {
    try {
      await _ensureLoaded();
      final source = _sources[cue];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      soloud.play(source);
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
    _lastShotAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastHitAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
