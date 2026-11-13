import 'package:battle_in_shanghai/utils/battlefield_layout.dart';
import 'package:battle_in_shanghai/utils/battlefield_display_mode.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('战场尺寸', () {
    test('按 3:4 宽高比在可用空间内取最大尺寸', () {
      final exact = fieldFitSize(const Size(600, 800));
      expect(exact.width, 600);
      expect(exact.height, 800);
    });

    test('高度受限时按高度反推宽度', () {
      final size = fieldFitSize(const Size(600, 600));
      expect(size.height, 600);
      expect(size.width, 450);
      expect(size.width / size.height, closeTo(Field.aspect, 1e-9));
    });

    test('限制最大宽度，避免超宽屏把战场拉长', () {
      final size = fieldFitSize(const Size(2000, 2000));
      expect(size.width, kFieldMaxWidth);
      expect(size.height, closeTo(kFieldMaxWidth * 4 / 3, 1e-9));
    });

    test('空间非法时返回零尺寸', () {
      expect(fieldFitSize(Size.zero), Size.zero);
      expect(fieldFitSize(const Size(-10, 100)), Size.zero);
    });
  });

  group('HUD 排版', () {
    test('左右留白足够时挂到战场两侧', () {
      final metrics = resolveHud(const Size(1280, 900));
      expect(metrics.sideRail, isTrue);
      expect(metrics.rail, greaterThanOrEqualTo(kHudRailWidth));
      expect(metrics.field.width, lessThanOrEqualTo(kFieldMaxWidth));
    });

    test('窄屏改为战场上方横条，且战场不吃满高度', () {
      final metrics = resolveHud(const Size(380, 700));
      expect(metrics.sideRail, isFalse);
      expect(metrics.compact, isFalse);
      expect(metrics.field.height, lessThan(700));
    });

    test('矮屏使用紧凑卡片', () {
      final metrics = resolveHud(const Size(380, 480));
      expect(metrics.compact, isTrue);
      expect(metrics.sideRail, isFalse);
    });

    test('字号放大后 HUD 预留空间随之增加', () {
      final normal = resolveHud(const Size(380, 700));
      final scaled = resolveHud(const Size(380, 700), textScale: 1.3);
      expect(scaled.field.height, lessThan(normal.field.height));
    });
  });

  group('横竖屏判定', () {
    test('手机竖屏下战场面积更大，不需要横屏', () {
      expect(fieldFitsBetterLandscape(const Size(400, 800)), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(shouldImmersiveLandscape(const Size(400, 800)), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    test('常见竖屏尺寸都不会误判为需要横屏', () {
      for (final size in [
        const Size(360, 640),
        const Size(390, 844),
        const Size(500, 900),
      ]) {
        expect(fieldFitsBetterLandscape(size), isFalse, reason: '$size');
      }
    });

    test('尺寸非法时不建议旋转', () {
      expect(fieldFitsBetterLandscape(Size.zero), isFalse);
    });
  });
}
