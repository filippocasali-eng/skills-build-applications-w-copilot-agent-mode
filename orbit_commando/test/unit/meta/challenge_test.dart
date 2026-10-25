import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/social/challenge.dart';

void main() {
  const c = Challenge(
    levelIndex: 7,
    modifier: 3,
    seed: 40321,
    hero: 2,
    target: 123450,
  );

  test('round-trips through the code', () {
    final code = c.encode();
    expect(code, matches(RegExp(r'^OC-[0-9A-Z]{5}-[0-9A-Z]{5}$')));
    expect(Challenge.decode(code), c);
  });

  test('forgives case, spaces and look-alike characters', () {
    final code = c.encode();
    expect(Challenge.decode(code.toLowerCase()), c);
    expect(Challenge.decode(code.replaceAll('-', ' ')), c);
    expect(Challenge.decode(code.substring(3)), c);
    expect(Challenge.decode(code.replaceAll('0', 'O')), c);
    expect(Challenge.decode(code.replaceAll('1', 'I')), c);
  });

  test('a typo is rejected by the checksum', () {
    final code = c.encode();
    var rejected = 0;
    for (var i = 3; i < code.length; i++) {
      if (code[i] == '-') continue;
      final swapped = code[i] == 'A' ? 'B' : 'A';
      final bad = code.replaceRange(i, i + 1, swapped);
      if (Challenge.decode(bad) == null) rejected++;
    }
    // A 5-bit checksum catches nearly every single-character typo.
    expect(rejected, greaterThanOrEqualTo(9));
    expect(Challenge.decode('OC-HELLO-WORLD'), isNull);
    expect(Challenge.decode(''), isNull);
  });

  test('every level, modifier and hero survives the trip', () {
    for (var l = 0; l < 15; l++) {
      for (var m = 0; m < 5; m++) {
        for (var h = 0; h < 4; h++) {
          final x = Challenge(
            levelIndex: l,
            modifier: m,
            seed: l * 997 + m,
            hero: h,
            target: 9999990,
          );
          expect(Challenge.decode(x.encode()), x);
        }
      }
    }
  });

  test('the daily changes every day and stays a remix', () {
    final a = Daily.dayIndex(DateTime.utc(2026, 10, 25, 23, 59));
    final b = Daily.dayIndex(DateTime.utc(2026, 10, 26, 0, 1));
    expect(b, a + 1);
    for (var d = 0; d < 60; d++) {
      expect(Daily.levelSlot(d), isNot(Daily.levelSlot(d + 1)));
      expect(Daily.modifier(d), inInclusiveRange(1, 4));
    }
  });
}
