import 'dart:io';

import 'package:battle_in_shanghai/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('battle_log_test');
    LogService.reset();
  });

  tearDown(() async {
    LogService.reset();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('初始化前的日志在初始化后补写进当天文件', () async {
    LogService.info('启动前日志');
    await LogService.init(
      logRoot: () async => dir,
      clock: () => DateTime(2026, 11, 14, 8, 30),
    );
    LogService.info('进入战斗');
    final file = File('${dir.path}/app_20261114.log');
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('启动前日志'));
    expect(content, contains('进入战斗'));
    expect(content, contains('[INFO]'));
    expect(LogService.logFilePath, file.path);
  });

  test('错误日志包含异常与堆栈', () async {
    await LogService.init(
      logRoot: () async => dir,
      clock: () => DateTime(2026),
    );
    LogService.error('测试错误', StateError('boom'), StackTrace.current);
    final content = await File('${dir.path}/app_20260101.log').readAsString();
    expect(content, contains('测试错误'));
    expect(content, contains('boom'));
    expect(content, contains('[ERROR]'));
  });

  test('日志目录不可用时降级为内存模式', () async {
    await LogService.init(
      logRoot: () async => throw StateError('no dir'),
    );
    LogService.warning('没有目录');
    expect(LogService.logFilePath, '');
  });
}
