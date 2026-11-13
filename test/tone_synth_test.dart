import 'dart:typed_data';

import 'package:battle_in_shanghai/services/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

int _u32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);

int _u16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint16(offset, Endian.little);

void main() {
  test('合成音效是合法的 16 位单声道 WAV', () {
    final bytes = synthesizeWav([
      const SynthNote(frequency: 880, start: 0, duration: 0.1),
      const SynthNote(frequency: 440, start: 0.05, duration: 0.1, noise: 0.3),
    ]);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    expect(_u16(bytes, 20), 1);
    expect(_u16(bytes, 22), 1);
    expect(_u32(bytes, 24), kSynthSampleRate);
    expect(_u16(bytes, 34), 16);
    expect(_u32(bytes, 40), bytes.length - 44);
    expect((bytes.length - 44) % 2, 0);
    expect(bytes.length, greaterThan(1000));
  });

  test('同样的配方生成完全一致的字节，可复现', () {
    final a = synthesizeWav([
      const SynthNote(frequency: 300, start: 0, duration: 0.08, noise: 0.4),
    ]);
    final b = synthesizeWav([
      const SynthNote(frequency: 300, start: 0, duration: 0.08, noise: 0.4),
    ]);
    expect(a, equals(b));
  });

  test('静音配方也能编码出合法文件', () {
    final bytes = synthesizeWav(const []);
    expect(bytes.length, 44);
    expect(_u32(bytes, 40), 0);
  });

  test('背景音乐是 8 秒循环的 WAV', () {
    final bytes = synthesizeMusicWav();
    final expected = 44 + (kMusicLoopSeconds * kMusicSampleRate).round() * 2;
    expect(bytes.length, expected);
    expect(_u32(bytes, 24), kMusicSampleRate);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  });

  test('背景音乐幅度经过归一化，不会削波', () {
    final bytes = synthesizeMusicWav();
    final data = ByteData.sublistView(bytes);
    var peak = 0;
    for (var offset = 44; offset < bytes.length; offset += 2) {
      final value = data.getInt16(offset, Endian.little).abs();
      if (value > peak) peak = value;
    }
    expect(peak, greaterThan(1000));
    expect(peak, lessThanOrEqualTo(32767));
  });
}
