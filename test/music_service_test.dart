import 'package:battle_in_shanghai/services/music_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MusicService.reset);

  test('开关背景音乐会通知播放出口', () async {
    final states = <bool>[];
    MusicService.sink = states.add;
    await MusicService.setEnabled(true);
    await MusicService.setEnabled(false);
    expect(states, [true, false]);
  });

  test('关闭状态下重试不会播放', () {
    final states = <bool>[];
    MusicService.sink = states.add;
    MusicService.enabled = false;
    MusicService.retryOnInteraction();
    expect(states, isEmpty);
  });

  test('生命周期暂停后不再重试播放，恢复后重新请求', () {
    final states = <bool>[];
    MusicService.sink = states.add;
    MusicService.pauseForLifecycle();
    MusicService.retryOnInteraction();
    expect(states, isEmpty);
    MusicService.resumeForLifecycle();
    expect(states, [true]);
  });
}
