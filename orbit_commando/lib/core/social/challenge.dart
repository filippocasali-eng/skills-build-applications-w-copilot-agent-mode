/// Shareable challenge codes: "OC-7K2M9-QX4TB".
///
/// A code carries everything needed to replay the same run on another phone
/// (the simulation is deterministic): level, remix modifier, seed and hero,
/// plus the score to beat. 50 bits in 10 Crockford base-32 characters, with a
/// 5-bit checksum so typos are caught instead of starting a wrong level.
class Challenge {
  const Challenge({
    required this.levelIndex,
    required this.modifier,
    required this.seed,
    required this.hero,
    required this.target,
  });

  /// 0..14, campaign order.
  final int levelIndex;

  /// 0 = none, 1.. = `WeeklyModifier.values[modifier - 1]`.
  final int modifier;

  /// 0..65535.
  final int seed;

  /// Index in `Commando.values` (0..3).
  final int hero;

  /// Score to beat, stored in units of 10 (max ~10 million).
  final int target;

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static int _checksum(int v) {
    var c = 0x1F;
    for (var i = 0; i < 45; i += 5) {
      c = ((c * 31) ^ ((v >> i) & 0x1F)) & 0x1F;
    }
    return c;
  }

  int get _payload =>
      (levelIndex & 0xF) |
      ((modifier & 0x7) << 4) |
      ((seed & 0xFFFF) << 7) |
      ((hero & 0x3) << 23) |
      (((target ~/ 10).clamp(0, 0xFFFFF)) << 25);

  /// "OC-XXXXX-XXXXX".
  String encode() {
    final p = _payload;
    final v = p | (_checksum(p) << 45);
    final chars = List.generate(
      10,
      (i) => _alphabet[(v >> ((9 - i) * 5)) & 0x1F],
    );
    return 'OC-${chars.sublist(0, 5).join()}-${chars.sublist(5).join()}';
  }

  /// Parses a code typed or pasted by a player. Case, spaces, dashes and the
  /// usual look-alikes (O/0, I/L/1) are forgiven. Returns null if invalid.
  static Challenge? decode(String input) {
    var s = input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (s.startsWith('OC')) s = s.substring(2);
    if (s.length != 10) return null;
    var v = 0;
    for (final ch in s.split('')) {
      final c = switch (ch) {
        'O' => '0',
        'I' || 'L' => '1',
        'U' => 'V',
        _ => ch,
      };
      final d = _alphabet.indexOf(c);
      if (d < 0) return null;
      v = (v << 5) | d;
    }
    final p = v & ((1 << 45) - 1);
    if ((v >> 45) != _checksum(p)) return null;
    final c = Challenge(
      levelIndex: p & 0xF,
      modifier: (p >> 4) & 0x7,
      seed: (p >> 7) & 0xFFFF,
      hero: (p >> 23) & 0x3,
      target: ((p >> 25) & 0xFFFFF) * 10,
    );
    if (c.levelIndex > 14 || c.modifier > 4) return null;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      other is Challenge &&
      other.levelIndex == levelIndex &&
      other.modifier == modifier &&
      other.seed == seed &&
      other.hero == hero &&
      other.target == target;

  @override
  int get hashCode => Object.hash(levelIndex, modifier, seed, hero, target);
}

/// "Orbit of the Day": the same remix for everyone, changing at UTC midnight.
class Daily {
  static final _epoch = DateTime.utc(2026, 1, 1);

  static int dayIndex(DateTime now) => now.toUtc().difference(_epoch).inDays;

  static DateTime dayEnd(DateTime now) =>
      _epoch.add(Duration(days: dayIndex(now) + 1));

  /// Index among non-boss levels (12 of them), never the same two days running.
  static int levelSlot(int day) => (day * 5 + 1) % 12;

  /// 1..4 (always a remix: that is the point of the daily).
  static int modifier(int day) => 1 + (day * 3 + day ~/ 4) % 4;

  static int seed(int day) => 9000 + day % 50000;
}
