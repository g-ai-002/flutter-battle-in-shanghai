import 'dart:math' as math;
import 'dart:typed_data';

/// 音效采样率：短促的枪声与爆炸用 22.05 kHz 足够，数据量只有 44.1 kHz 的一半。
const int kSynthSampleRate = 22050;

/// 单枚乐音：正弦基频叠加二、三次谐波，可混入噪声模拟枪火与爆炸。
class SynthNote {
  const SynthNote({
    required this.frequency,
    required this.start,
    required this.duration,
    this.gain = 0.5,
    this.noise = 0,
    this.damp = 3.2,
  });

  final double frequency;
  final double start;
  final double duration;
  final double gain;
  final double noise;

  /// 指数衰减速度，越大衰减越快。
  final double damp;
}

/// 纯 Dart 音效合成：把若干乐音渲染成 16 位单声道 WAV 字节。
///
/// 全部在运行时生成，代码仓库与安装包都不携带音频文件。
Uint8List synthesizeWav(
  List<SynthNote> notes, {
  int sampleRate = kSynthSampleRate,
}) {
  if (notes.isEmpty) {
    final empty = Float64List(0);
    return _encodePcm(empty, sampleRate);
  }
  const tailSeconds = 0.05;
  final seconds = notes.fold<double>(
    0,
    (longest, note) => math.max(longest, note.start + note.duration),
  );
  final totalSamples = ((seconds + tailSeconds) * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(1937);

  for (final note in notes) {
    final offset = (note.start * sampleRate).round();
    final count = math.min(
      (note.duration * sampleRate).round(),
      totalSamples - offset,
    );
    if (count <= 0) continue;
    final attack = math.max(1, (0.002 * sampleRate).round());
    final release = math.max(1, (0.006 * sampleRate).round());
    final gain = note.gain / 1.44;
    for (var i = 0; i < count; i++) {
      final index = offset + i;
      if (index >= totalSamples) break;
      final progress = i / count;
      final envelope =
          math.min(1, i / attack) *
          math.min(1, (count - i) / release) *
          math.exp(-note.damp * progress);
      final phase = 2 * math.pi * note.frequency * (i / sampleRate);
      final tone =
          math.sin(phase) +
          0.32 * math.sin(2 * phase) +
          0.12 * math.sin(3 * phase);
      final hit = note.noise * (random.nextDouble() * 2 - 1);
      mix[index] += envelope * (tone * gain + hit);
    }
  }

  return _encodePcm(mix, sampleRate);
}

/// 背景音乐采样率与循环长度：军鼓与低音号，8 秒一循环。
const int kMusicSampleRate = 16000;
const double kMusicLoopSeconds = 8;

/// D 小调五声音阶，适合表现紧张的巷战气氛。
const List<double> _pentatonic = [146.83, 174.61, 196.0, 220.0, 261.63];

/// 合成背景音乐：军鼓 + 低音 + 五声音阶号声，首尾淡入淡出后无缝循环。
Uint8List synthesizeMusicWav({int sampleRate = kMusicSampleRate}) {
  final totalSamples = (kMusicLoopSeconds * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(1937);

  // 军鼓：每 0.5 秒一记，重音落在奇数拍。
  for (var beat = 0; beat < kMusicLoopSeconds * 2; beat++) {
    final start = beat * 0.5;
    final offset = (start * sampleRate).round();
    final accent = beat.isOdd ? 0.5 : 0.28;
    final length = (0.18 * sampleRate).round();
    for (var i = 0; i < length && offset + i < totalSamples; i++) {
      final t = i / sampleRate;
      final env = math.exp(-26 * t) * accent;
      final body = math.sin(2 * math.pi * 92 * t) * math.exp(-16 * t) * 0.35;
      final snap = (random.nextDouble() * 2 - 1) * math.exp(-48 * t) * 0.6;
      mix[offset + i] += env * (body + snap);
    }
  }

  // 低音号：两拍一个长音，撑起行军节奏。
  for (var bar = 0; bar < 4; bar++) {
    final start = bar * 2.0;
    final index = (bar.isEven ? 0 : 2);
    final frequency = _pentatonic[index] / 2;
    final offset = (start * sampleRate).round();
    final count = math.min(
      (1.9 * sampleRate).round(),
      totalSamples - offset,
    );
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final env = math.min(1, i / (0.05 * sampleRate)) * math.exp(-1.1 * t);
      final phase = 2 * math.pi * frequency * t;
      mix[offset + i] += env * 0.16 * (math.sin(phase) + 0.4 * math.sin(2 * phase));
    }
  }

  // 号声旋律：每半秒一个音，重复两遍并收在高八度。
  const melody = [4, 2, 3, 2, 4, 3, 1, 2, 4, 2, 3, 2, 0, 1, 2, 3];
  for (var i = 0; i < melody.length; i++) {
    final start = i * 0.5;
    final frequency = _pentatonic[melody[i]] * 2;
    final offset = (start * sampleRate).round();
    final count = math.min((0.46 * sampleRate).round(), totalSamples - offset);
    for (var s = 0; s < count; s++) {
      final t = s / sampleRate;
      final env = math.min(1, s / (0.01 * sampleRate)) * math.exp(-3.4 * t);
      final phase = 2 * math.pi * frequency * t;
      final tone =
          math.sin(phase) +
          0.28 * math.sin(2.004 * phase) +
          0.12 * math.sin(3.01 * phase);
      mix[offset + s] += env * 0.12 * tone;
    }
  }

  var peak = 0.0;
  for (final value in mix) {
    final magnitude = value.abs();
    if (magnitude > peak) peak = magnitude;
  }
  final scale = peak > 0 ? 0.76 / peak : 1.0;
  final edge = (0.02 * sampleRate).round();
  for (var i = 0; i < totalSamples; i++) {
    final fadeIn = i < edge ? i / edge : 1.0;
    final fadeOut = i >= totalSamples - edge ? (totalSamples - i) / edge : 1.0;
    mix[i] *= scale * fadeIn * fadeOut;
  }
  return _encodePcm(mix, sampleRate);
}

/// 把 [-1,1] 的浮点混音编码为 16 位单声道 WAV。
Uint8List _encodePcm(Float64List mix, int sampleRate) {
  final totalSamples = mix.length;
  final data = ByteData(44 + totalSamples * 2);
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + totalSamples * 2, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, totalSamples * 2, Endian.little);

  for (var i = 0; i < totalSamples; i++) {
    final sample = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    data.setUint8(offset + i, text.codeUnitAt(i));
  }
}
