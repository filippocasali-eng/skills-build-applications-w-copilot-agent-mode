import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/math/det_random.dart';

void main() {
  test('same seed gives the same sequence', () {
    final a = DetRandom(1994);
    final b = DetRandom(1994);
    for (var i = 0; i < 10000; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
  });

  test('known xorshift32 values (guards against accidental changes)', () {
    final r = DetRandom(1);
    expect(
      [r.nextUint32(), r.nextUint32(), r.nextUint32()],
      [270369, 67634689, 2647435461],
    );
  });

  test('nextDouble stays in [0,1) and is roughly uniform', () {
    final r = DetRandom(42);
    final buckets = List<int>.filled(10, 0);
    for (var i = 0; i < 100000; i++) {
      final d = r.nextDouble();
      expect(d, greaterThanOrEqualTo(0));
      expect(d, lessThan(1));
      buckets[(d * 10).floor()]++;
    }
    for (final b in buckets) {
      expect(b, inInclusiveRange(9500, 10500));
    }
  });

  test('zero seed is remapped (xorshift would stick at 0)', () {
    expect(DetRandom(0).nextUint32(), isNot(0));
  });
}
