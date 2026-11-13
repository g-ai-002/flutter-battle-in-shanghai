import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'services/logging_init.dart';
import 'services/music_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';
import 'utils/window_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('Flutter 异常', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('未捕获异常', error, stack);
    return true;
  };

  await setupDesktopWindow();
  await initLogging();

  final storage = await StorageService.instance;
  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');
  MusicService.enabled = storage.musicEnabled;
  runApp(BattleApp(storage: storage));

  // 音频合成与引擎初始化放在首帧之后：首屏绘制不必和音效加载抢主线程。
  // Web 需要用户手势才能播放，首次点击页面时由 App 的监听器启动。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(SoundService.init());
    if (MusicService.enabled && !kIsWeb) unawaited(MusicService.start());
  });
}
