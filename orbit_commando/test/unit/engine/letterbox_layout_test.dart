import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/render/virtual_screen.dart';

void main() {
  group('LetterboxLayout', () {
    test('1920x1080 is an exact 3x scale with no bars', () {
      final l = LetterboxLayout.compute(const Size(1920, 1080));
      expect(l.scale, 3);
      expect(l.dest, const Rect.fromLTWH(0, 0, 1920, 1080));
    });

    test('1280x720 is an exact 2x, 2560x1440 an exact 4x', () {
      expect(LetterboxLayout.compute(const Size(1280, 720)).scale, 2);
      expect(LetterboxLayout.compute(const Size(2560, 1440)).scale, 4);
    });

    test('20:9 phone (2400x1080) uses integer 3x with side bars', () {
      final l = LetterboxLayout.compute(const Size(2400, 1080));
      expect(l.scale, 3);
      expect(l.dest.width, 1920);
      expect(l.dest.left, 240);
      expect(l.dest.top, 0);
    });

    test('odd size picks the largest integer that fits and centres', () {
      final l = LetterboxLayout.compute(const Size(1400, 800));
      expect(l.scale, 2);
      expect(l.dest, const Rect.fromLTWH(60, 40, 1280, 720));
    });

    test('fit mode fills the limiting axis', () {
      final l = LetterboxLayout.compute(
        const Size(1000, 600),
        mode: ScaleMode.fit,
      );
      expect(l.dest.width, closeTo(1000, 1e-9));
    });

    test('screens smaller than 640x360 fall back to fractional scale', () {
      final l = LetterboxLayout.compute(const Size(320, 180));
      expect(l.scale, 0.5);
    });

    test('toVirtual and toScreen are inverses', () {
      final l = LetterboxLayout.compute(const Size(2400, 1080));
      const p = Offset(1234, 567);
      final back = l.toScreen(l.toVirtual(p));
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
      expect(l.toVirtual(const Offset(240, 0)), Offset.zero);
    });
  });
}
