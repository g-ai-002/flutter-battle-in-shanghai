import 'package:flutter/foundation.dart';

/// Web 平台日志：没有可写目录，直接输出到浏览器控制台。
class LogService {
  LogService._();

  static Future<void> init({
    Future<Object?> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    debugPrint('[LogService] ==== LogService 已初始化, Web 控制台模式 ====');
  }

  static void reset() {}

  static String get logFilePath => '';

  static void info(String message) => _write('INFO', message);

  static void warning(String message) => _write('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    _write('ERROR', error != null ? '$message | $error' : message);
    if (stack != null) _write('ERROR', stack.toString());
  }

  static void _write(String level, String message) =>
      debugPrint('[LogService] $level $message');
}
