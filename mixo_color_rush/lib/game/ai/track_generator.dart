import '../sim/difficulty.dart';
import '../sim/rng.dart';
import '../sim/track.dart';
import '../systems/color_system.dart';

/// Procedural track generator.
///
/// The track depends only on (seed, params, startColor): never on how the
/// player plays. It tracks the set of colours Mixo *could* have at each
/// point (taking or skipping drops) and guarantees that every gate row is
/// passable for each of them, or leaves a free lane.
class TrackGenerator {
  TrackGenerator({
    required int seed,
    required this.params,
    this.startColor = GameColor.red,
  }) : _rng = Rng(seed),
       _reach = 1 << startColor.index;

  static const double firstRowDistance = 30;
  static const int introRows = 3;

  final DifficultyParams params;
  final GameColor startColor;
  final Rng _rng;

  double _nextD = firstRowDistance;
  int _reach;
  int _rowIndex = 0;
  int _rowsSinceGate = 0;

  /// Distance at which the next row will be placed.
  double get nextD => _nextD;

  /// Bitmask (by [GameColor.index]) of colours Mixo may have right now.
  int get reachableMask => _reach;

  void fillUntil(double maxD, RowPool pool, List<TrackRow> out) {
    while (_nextD <= maxD) {
      final row = pool.obtain();
      _build(row);
      out.add(row);
    }
  }

  void _build(TrackRow row) {
    row.d = _nextD;
    var gapMul = 1.0;
    final r = _rng.nextDouble();
    final intro = _rowIndex < introRows;
    if (intro ||
        _rowsSinceGate >= 2 ||
        r >= params.dropChance + params.obstacleChance) {
      _gateRow(row, forceEmpty: intro);
      _rowsSinceGate = 0;
    } else if (r < params.dropChance) {
      _dropRow(row);
      gapMul = 0.7;
      _rowsSinceGate++;
    } else {
      _obstacleRow(row);
      gapMul = 0.85;
      _rowsSinceGate++;
    }
    _rowIndex++;
    _nextD += params.gapAt(row.d) * params.speedAt(row.d) * gapMul;
  }

  List<GameColor> get _gatePalette => params.mixDepth >= 2
      ? const [...GameColor.primaries, ...GameColor.secondaries]
      : GameColor.primaries;

  GameColor _pick(List<GameColor> from) => from[_rng.nextInt(from.length)];

  List<int> _shuffledLanes() {
    final n = params.laneCount;
    final lanes = List<int>.generate(n, (i) => i);
    for (var i = n - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final t = lanes[i];
      lanes[i] = lanes[j];
      lanes[j] = t;
    }
    return lanes;
  }

  void _gateRow(TrackRow row, {bool forceEmpty = false}) {
    final n = params.laneCount;
    final hasBrown = _reach & (1 << GameColor.brown.index) != 0;
    final required = <GameColor>[
      for (final c in GameColor.values)
        if (c != GameColor.brown && _reach & (1 << c.index) != 0) c,
    ];
    final lanes = _shuffledLanes();
    final palette = _gatePalette;
    final useEmpty =
        forceEmpty ||
        hasBrown ||
        required.length > n ||
        _rng.chance(params.emptyLaneChance);

    var next = 0;
    if (useEmpty) {
      next = 1; // lanes[0] stays empty
      // Always offer at least one matching gate to keep the row meaningful.
      if (required.isNotEmpty && n > 1) {
        _setGate(row.cells[lanes[next++]], _pick(required));
      }
    } else {
      for (final c in required) {
        _setGate(row.cells[lanes[next++]], c);
      }
    }
    for (; next < n; next++) {
      final cell = row.cells[lanes[next]];
      if (params.obstacleChance > 0 && _rng.chance(params.obstacleChance)) {
        cell.type = CellType.obstacle;
        cell.low = params.jumpEnabled && _rng.chance(0.5);
      } else {
        _setGate(cell, _pick(palette));
      }
    }
  }

  void _setGate(Cell cell, GameColor color) {
    cell.type = CellType.gate;
    cell.color = color;
  }

  void _dropRow(TrackRow row) {
    final n = params.laneCount;
    final color = _pick(GameColor.primaries);
    final forced = _bitCount(_reach) > 2 || _rng.chance(0.4);
    if (forced) {
      for (var i = 0; i < n; i++) {
        final cell = row.cells[i];
        cell.type = CellType.drop;
        cell.color = color;
      }
      _reach = _mixMask(_reach, color);
    } else {
      final cell = row.cells[_rng.nextInt(n)];
      cell.type = CellType.drop;
      cell.color = color;
      _reach |= _mixMask(_reach, color);
    }
  }

  void _obstacleRow(TrackRow row) {
    final n = params.laneCount;
    final lanes = _shuffledLanes();
    final count = 1 + _rng.nextInt(n - 1);
    for (var i = 0; i < count; i++) {
      final cell = row.cells[lanes[i]];
      cell.type = CellType.obstacle;
      cell.low = params.jumpEnabled && _rng.chance(0.5);
    }
  }

  int _mixMask(int mask, GameColor drop) {
    var out = 0;
    for (final c in GameColor.values) {
      if (mask & (1 << c.index) != 0) {
        out |= 1 << ColorSystem.mix(c, drop, mixing: params.mixing).index;
      }
    }
    return out;
  }

  static int _bitCount(int v) {
    var c = 0;
    for (var x = v; x != 0; x &= x - 1) {
      c++;
    }
    return c;
  }
}
