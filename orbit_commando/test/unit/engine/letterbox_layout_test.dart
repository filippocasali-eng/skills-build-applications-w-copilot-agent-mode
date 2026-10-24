import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/render/virtual_screen.dart';

void main() {
  group('LetterboxLayout', () {
    test('1920x1080 is an exact 5x scale with no bars', () {
      final l = LetterboxLayout.compute(const Size(1920, 1080));
      expect(l.scale, 5);
      expect(l.dest, const Rect.fromLTWH(0, 0, 1920, 1080));
    });

    test('20:9 phone (2400x1080) uses integer 5x with side bars', () {
      final l = LetterboxLayout.compute(const Size(2400, 1080));
      expect(l.scale, 5);
      expect(l.dest.width, 1920);
      expect(l.dest.left, 240);
      expect(l.dest.top, 0);
    });

    test('odd size picks the largest integer that fits and centres', () {
      final l = LetterboxLayout.compute(const Size(1000, 600));
      expect(l.scale, 2);
      expect(l.dest, const Rect.fromLTWH(116, 84, 768, 432));
    });

    test('fit mode fills the limiting axis', () {
      final l = LetterboxLayout.compute(
        const Size(1000, 600),
        mode: ScaleMode.fit,
      );
      expect(l.dest.width, closeTo(1000, 1e-9));
    });

    test('screens smaller than 384x216 fall back to fractional scale', () {
      final l = LetterboxLayout.compute(const Size(192, 108));
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
