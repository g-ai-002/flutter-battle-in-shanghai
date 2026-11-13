/// 日志与界面的通用格式化工具。
library;

/// `2026-11-14 09:05:33.123` 形式的日志时间。
String formatLogLine(DateTime time, String level, String message) {
  final buffer = StringBuffer()
    ..write(time.year.toString().padLeft(4, '0'))
    ..write('-')
    ..write(time.month.toString().padLeft(2, '0'))
    ..write('-')
    ..write(time.day.toString().padLeft(2, '0'))
    ..write(' ')
    ..write(time.hour.toString().padLeft(2, '0'))
    ..write(':')
    ..write(time.minute.toString().padLeft(2, '0'))
    ..write(':')
    ..write(time.second.toString().padLeft(2, '0'))
    ..write('.')
    ..write(time.millisecond.toString().padLeft(3, '0'))
    ..write(' [')
    ..write(level)
    ..write('] ')
    ..write(message);
  return buffer.toString();
}

/// 日志文件名用的日期键：`20261114`。
String formatDateKey(DateTime time) {
  final year = time.year.toString().padLeft(4, '0');
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

/// 分数千分位：`12,340`。
String formatScore(int score) {
  final digits = score.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return score < 0 ? '-$buffer' : buffer.toString();
}

/// 秒数显示为 `m:ss`，不足一分钟只显示秒。
String formatDuration(double seconds) {
  final total = seconds <= 0 ? 0 : seconds.ceil();
  final minutes = total ~/ 60;
  final rest = total % 60;
  if (minutes == 0) return '${rest}s';
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
