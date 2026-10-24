import 'package:flame/components.dart';

/// A game that drives [FixedTick] components at a fixed rate.
abstract interface class TickHost {
  void registerTick(FixedTick c);
  void unregisterTick(FixedTick c);
}

/// Components that take part in the deterministic simulation implement
/// [fixedUpdate] instead of (or in addition to) `update(dt)`.
///
/// Ticks are dispatched in mount order, which is itself deterministic.
mixin FixedTick on Component {
  void fixedUpdate(int tick);

  TickHost? _host;

  @override
  void onMount() {
    super.onMount();
    final game = findGame();
    if (game is TickHost) {
      _host = game as TickHost;
      _host!.registerTick(this);
    }
  }

  @override
  void onRemove() {
    _host?.unregisterTick(this);
    _host = null;
    super.onRemove();
  }
}
