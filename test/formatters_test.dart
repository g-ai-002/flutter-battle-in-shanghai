import 'package:battle_in_shanghai/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('日志行包含毫秒级时间与级别', () {
    final line = formatLogLine(
      DateTime(2026, 11, 14, 9, 5, 3, 7),
      'INFO',
      '开始战斗',
    );
    expect(line, '2026-11-14 09:05:03.007 [INFO] 开始战斗');
    expect(formatDateKey(DateTime(2026, 1, 2)), '20260102');
  });

  test('分数使用千分位', () {
    expect(formatScore(0), '0');
    expect(formatScore(999), '999');
    expect(formatScore(1234), '1,234');
    expect(formatScore(1234567), '1,234,567');
    expect(formatScore(-1234), '-1,234');
  });

  test('时长显示为分秒或秒', () {
    expect(formatDuration(0), '0s');
    expect(formatDuration(0.2), '1s');
    expect(formatDuration(65.2), '1:06');
    expect(formatDuration(600), '10:00');
  });
}
