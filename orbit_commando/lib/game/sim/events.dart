/// Things that happened during a tick, for the renderer (FX), audio and
/// haptics. The simulation never reads them back, so dropping or reordering
/// them can't break determinism.
enum SimEventType {
  shot,
  enemyShot,
  hit,
  shieldHit,
  explosion,
  enemyDeath,
  playerHurt,
  playerDeath,
  playerRespawn,
  jump,
  land,
  dash,
  melee,
  grenadeThrow,
  pickup,
  weaponPickup,
  hostageFreed,
  cassette,
  checkpoint,
  combo,
  vehicleEnter,
  vehicleEject,
  bossPhase,
  bossDefeated,
  levelComplete,
  gameOver,
  oneUp,
  tell,

  /// Combo milestone; a = tier 1..4 (see [hypeTierFor]).
  hype,
}

class SimEvent {
  SimEventType type = SimEventType.hit;
  double x = 0, y = 0;

  /// Event-specific parameters (size, kind, amount...).
  int a = 0;
  double b = 0;
}

/// Fixed-capacity event buffer reused every tick (no allocations).
class EventQueue {
  EventQueue([int capacity = 256])
    : _items = List.generate(capacity, (_) => SimEvent());

  final List<SimEvent> _items;
  int _count = 0;

  int get length => _count;
  SimEvent operator [](int i) => _items[i];

  void add(SimEventType type, double x, double y, {int a = 0, double b = 0}) {
    if (_count >= _items.length) return; // drop: FX only
    _items[_count++]
      ..type = type
      ..x = x
      ..y = y
      ..a = a
      ..b = b;
  }

  void clear() => _count = 0;

  Iterable<SimEvent> get items sync* {
    for (var i = 0; i < _count; i++) {
      yield _items[i];
    }
  }
}
