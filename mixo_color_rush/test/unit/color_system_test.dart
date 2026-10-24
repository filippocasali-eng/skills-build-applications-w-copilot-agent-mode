import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/game/systems/color_system.dart';

void main() {
  const r = GameColor.red;
  const y = GameColor.yellow;
  const b = GameColor.blue;
  const o = GameColor.orange;
  const g = GameColor.green;
  const p = GameColor.purple;
  const m = GameColor.brown;

  test('primary + primary = secondary (both orders)', () {
    expect(ColorSystem.mix(r, y), o);
    expect(ColorSystem.mix(y, r), o);
    expect(ColorSystem.mix(y, b), g);
    expect(ColorSystem.mix(b, y), g);
    expect(ColorSystem.mix(r, b), p);
    expect(ColorSystem.mix(b, r), p);
  });

  test('same colour does not change', () {
    for (final c in GameColor.values) {
      expect(ColorSystem.mix(c, c), c, reason: c.name);
    }
  });

  test('secondary + own primary is unchanged', () {
    expect(ColorSystem.mix(o, r), o);
    expect(ColorSystem.mix(o, y), o);
    expect(ColorSystem.mix(g, y), g);
    expect(ColorSystem.mix(g, b), g);
    expect(ColorSystem.mix(p, r), p);
    expect(ColorSystem.mix(p, b), p);
  });

  test('secondary + missing primary = brown', () {
    expect(ColorSystem.mix(o, b), m);
    expect(ColorSystem.mix(g, r), m);
    expect(ColorSystem.mix(p, y), m);
  });

  test('brown stays brown with any drop', () {
    for (final c in GameColor.values) {
      expect(ColorSystem.mix(m, c), m);
    }
  });

  test('full mixing table is closed and deterministic', () {
    for (final a in GameColor.values) {
      for (final c in GameColor.primaries) {
        final out = ColorSystem.mix(a, c);
        expect(GameColor.values, contains(out));
        expect(ColorSystem.mix(a, c), out);
      }
    }
  });

  test('without mixing the drop replaces the colour', () {
    for (final a in GameColor.values) {
      for (final c in GameColor.primaries) {
        expect(ColorSystem.mix(a, c, mixing: false), c);
      }
    }
  });

  test('complement is an involution on non-brown colours', () {
    expect(ColorSystem.complement(r), g);
    expect(ColorSystem.complement(y), p);
    expect(ColorSystem.complement(b), o);
    for (final c in GameColor.values) {
      expect(ColorSystem.complement(ColorSystem.complement(c)), c);
    }
  });

  test('every colour has a unique symbol', () {
    final symbols = GameColor.values.map((c) => c.symbol).toSet();
    expect(symbols.length, GameColor.values.length);
  });
}
