import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.reset();
    SoundService.hapticsEnabled = false;
  });

  test('每种战斗提示都有可播放的合成音频', () {
    for (final cue in BattleCue.values) {
      final clip = SoundService.clipOf(cue);
      expect(clip.length, greaterThan(44), reason: cue.name);
      expect(String.fromCharCodes(clip.sublist(0, 4)), 'RIFF');
    }
  });

  test('音效开关关闭后不再输出', () {
    final played = <BattleCue>[];
    SoundService.sink = played.add;
    SoundService.configure(sound: false, haptics: false);
    SoundService.play(BattleCue.hit);
    expect(played, isEmpty);
    SoundService.configure(sound: true, haptics: false);
    SoundService.play(BattleCue.hit);
    expect(played, [BattleCue.hit]);
  });

  test('连发枪声按最小间隔合并，避免噪声', () {
    final played = <BattleCue>[];
    SoundService.sink = played.add;
    SoundService.configure(sound: true, haptics: false);
    SoundService.play(BattleCue.shot);
    SoundService.play(BattleCue.shot);
    SoundService.play(BattleCue.shot);
    expect(played.where((cue) => cue == BattleCue.shot), hasLength(1));
    SoundService.play(BattleCue.explosion);
    expect(played.last, BattleCue.explosion);
  });

  test('连续命中音效按最小间隔合并', () {
    final played = <BattleCue>[];
    SoundService.sink = played.add;
    SoundService.configure(sound: true, haptics: false);
    for (var i = 0; i < 5; i++) {
      SoundService.play(BattleCue.hit);
    }
    expect(played.where((cue) => cue == BattleCue.hit), hasLength(1));
  });

  test('重置后恢复默认开关', () {
    SoundService.configure(sound: false, haptics: false);
    SoundService.reset();
    expect(SoundService.soundEnabled, isTrue);
    expect(SoundService.hapticsEnabled, isTrue);
    expect(SoundService.sink, isNull);
  });
}
