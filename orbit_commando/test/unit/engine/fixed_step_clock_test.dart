import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/loop/fixed_step_clock.dart';

void main() {
  group('FixedStepClock', () {
    test('one 60 Hz frame = one tick', () {
      final c = FixedStepClock();
      var total = 0;
      for (var i = 0; i < 600; i++) {
        total += c.advance(1 / 60);
      }
      // Float accumulation may leave the last tick pending, never more.
      expect(total, inInclusiveRange(599, 600));
      expect(c.tick, total);
    });

    test('120 Hz display runs one tick every other frame', () {
      final c = FixedStepClock();
      var total = 0;
      for (var i = 0; i < 1200; i++) {
        total += c.advance(1 / 120);
      }
      expect(total, inInclusiveRange(599, 600));
    });

    test('30 Hz frames run two ticks each', () {
      final c = FixedStepClock();
      expect(c.advance(1 / 30 + 1e-9), 2);
    });

    test('long stalls are capped', () {
      final c = FixedStepClock(maxStepsPerFrame: 5);
      expect(c.advance(3.0), 5);
      expect(c.alpha, 0);
    });

    test('non-positive dt does nothing', () {
      final c = FixedStepClock();
      expect(c.advance(0), 0);
      expect(c.advance(-1), 0);
      expect(c.tick, 0);
    });
  });
}
