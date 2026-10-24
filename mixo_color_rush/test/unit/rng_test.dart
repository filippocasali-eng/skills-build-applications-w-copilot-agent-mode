import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/game/sim/rng.dart';

void main() {
  test('matches the reference mulberry32 implementation', () {
    // Reference: JS mulberry32(1)() === 0.6270739405881613
    expect(Rng(1).nextDouble(), closeTo(0.6270739405881613, 1e-15));
  });

  test('same seed gives the same sequence', () {
    final a = Rng(42);
    final b = Rng(42);
    for (var i = 0; i < 1000; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
  });

  test('nextInt stays in range', () {
    final r = Rng(7);
    for (var i = 0; i < 10000; i++) {
      final v = r.nextInt(5);
      expect(v, inInclusiveRange(0, 4));
    }
  });

  test('seedFromString is stable', () {
    expect(Rng.seedFromString('2026-10-24'), Rng.seedFromString('2026-10-24'));
    expect(
      Rng.seedFromString('2026-10-24'),
      isNot(Rng.seedFromString('2026-10-25')),
    );
  });
}
