/// Deterministic 32-bit PRNG (mulberry32).
///
/// Implemented with 16-bit half multiplications so that results are
/// bit-identical on the Dart VM and on the web (where ints are doubles).
/// Same seed => same sequence on every platform: required for the daily
/// challenge, ghost replays and future multiplayer.
class Rng {
  Rng(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  int get state => _state;

  static int _imul(int a, int b) {
    final aHi = (a >> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    final cross = ((aHi * bLo + aLo * bHi) & 0xFFFF) << 16;
    return (aLo * bLo + cross) & 0xFFFFFFFF;
  }

  /// Next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) => (nextDouble() * max).floor();

  bool chance(double p) => nextDouble() < p;

  /// Derives a stable seed from a string (e.g. "2026-10-24").
  static int seedFromString(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = _imul(h, 0x01000193);
    }
    return h;
  }
}
