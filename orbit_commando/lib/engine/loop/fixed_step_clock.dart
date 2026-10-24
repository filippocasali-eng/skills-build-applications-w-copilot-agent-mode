/// Converts variable frame times into a whole number of fixed 60 Hz ticks.
///
/// All simulation (physics, AI, weapons) runs in ticks so that the same inputs
/// always produce the same state: the basis for replays, ghosts and netcode.
class FixedStepClock {
  FixedStepClock({this.hz = 60, this.maxStepsPerFrame = 5});

  final int hz;

  /// Caps catch-up work after a long stall (e.g. app resumed) so the game
  /// slows down instead of spiralling.
  final int maxStepsPerFrame;

  double get step => 1 / hz;

  /// Ticks simulated since the clock was created.
  int get tick => _tick;
  int _tick = 0;

  double _accumulator = 0;

  /// How far into the next tick we are, in [0, 1). Useful for interpolation.
  double get alpha => _accumulator * hz;

  /// Adds [dt] seconds and returns how many ticks should be simulated now.
  int advance(double dt) {
    if (dt <= 0) return 0;
    _accumulator += dt;
    var steps = (_accumulator * hz).floor();
    if (steps > maxStepsPerFrame) {
      steps = maxStepsPerFrame;
      _accumulator = 0;
    } else {
      _accumulator -= steps / hz;
    }
    _tick += steps;
    return steps;
  }

  void reset() {
    _accumulator = 0;
    _tick = 0;
  }
}
