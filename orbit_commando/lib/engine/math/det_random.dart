/// Deterministic PRNG (xorshift32). Same seed => same sequence on every
/// platform, unlike dart:math Random. Use it for everything that affects the
/// simulation (spawns, drops, weekly-challenge remixes).
class DetRandom {
  DetRandom(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _state;

  int get state => _state;

  /// Next unsigned 32-bit integer.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x;
    return x;
  }

  /// Integer in [0, max).
  int nextInt(int max) => nextUint32() % max;

  /// Double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;
}
