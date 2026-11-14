import 'package:battle_in_shanghai/flame/label_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('相同文字与样式命中同一支画笔', () {
    final cache = BattleLabelCache();
    final first = cache.painter('+120', 10, const Color(0xFFFFD166));
    final second = cache.painter('+120', 10, const Color(0xFFFFD166));
    expect(identical(first, second), isTrue);
    expect(cache.length, 1);
    cache.dispose();
  });

  test('字号、颜色、字重与字距各自区分缓存', () {
    final cache = BattleLabelCache();
    cache.painter('警告', 19, const Color(0xFFFF7A52));
    cache.painter('警告', 20, const Color(0xFFFF7A52));
    cache.painter('警告', 19, const Color(0xFFF6E4C6));
    cache.painter('警告', 19, const Color(0xFFFF7A52), weight: FontWeight.w500);
    cache.painter('警告', 19, const Color(0xFFFF7A52), spacing: 2.4);
    expect(cache.length, 5);
    cache.dispose();
  });

  test('透明度量化到十档，动画淡出也能复用', () {
    final color = const Color(0xFFFFD166).withValues(alpha: 0.83);
    final steady = BattleLabelCache.steady(color);
    expect((steady.a * BattleLabelCache.alphaSteps).round(), closeTo(8, 0.5));

    final cache = BattleLabelCache();
    final first = cache.painter('+30', 10, BattleLabelCache.steady(color));
    final second = cache.painter(
      '+30',
      10,
      BattleLabelCache.steady(const Color(0xFFFFD166).withValues(alpha: 0.84)),
    );
    expect(identical(first, second), isTrue);
    expect(cache.length, 1);
    cache.dispose();
  });

  test('超出上限时淘汰最久未使用的一条，再次使用会重新排版', () {
    final cache = BattleLabelCache();
    TextPainter? evictedEarlier;
    for (var i = 0; i < BattleLabelCache.maxEntries; i++) {
      final painter = cache.painter('$i', 10, const Color(0xFFFFFFFF));
      if (i == 1) evictedEarlier = painter;
    }
    expect(cache.length, BattleLabelCache.maxEntries);

    // 重新取用 0 号，把 1 号挤成最旧的一条。
    final refreshed = cache.painter('0', 10, const Color(0xFFFFFFFF));
    expect(identical(refreshed, evictedEarlier), isFalse);

    cache.painter('new', 10, const Color(0xFFFFFFFF));
    expect(cache.length, BattleLabelCache.maxEntries);
    // 1 号已被淘汰：再次取用会新建实例。
    final recreated = cache.painter('1', 10, const Color(0xFFFFFFFF));
    expect(identical(recreated, evictedEarlier), isFalse);
    cache.dispose();
  });

  test('释放后缓存清空，可继续使用', () {
    final cache = BattleLabelCache();
    cache.painter('第一波', 19, const Color(0xFFF6E4C6));
    cache.dispose();
    expect(cache.length, 0);
    final painter = cache.painter('第一波', 19, const Color(0xFFF6E4C6));
    expect(painter.width, greaterThan(0));
    cache.dispose();
  });
}
