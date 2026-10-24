import '../systems/color_system.dart';

enum CellType { empty, gate, drop, obstacle }

/// Kind of drop. [color] drops mix their colour into Mixo.
enum DropKind { color, white, rainbow, invert }

/// One lane slot of a track row. Mutable so rows can be pooled.
class Cell {
  CellType type = CellType.empty;
  GameColor color = GameColor.red;
  DropKind dropKind = DropKind.color;

  /// Low obstacles can be jumped over.
  bool low = false;

  void clear() {
    type = CellType.empty;
    color = GameColor.red;
    dropKind = DropKind.color;
    low = false;
  }

  void copyFrom(Cell o) {
    type = o.type;
    color = o.color;
    dropKind = o.dropKind;
    low = o.low;
  }
}

/// A row of cells at track distance [d]. Every lane is resolved when Mixo
/// crosses [d].
class TrackRow {
  TrackRow() : cells = List.generate(maxLanes, (_) => Cell(), growable: false);

  static const int maxLanes = 5;

  double d = 0;
  final List<Cell> cells;
  bool resolved = false;

  /// Lane Mixo was in when the row was resolved (-1 if not yet).
  int hitLane = -1;

  /// Index of the chunk/pattern that produced this row (debug + coach).
  int patternId = -1;

  bool get hasGate => cells.any((c) => c.type == CellType.gate);

  void reset() {
    d = 0;
    resolved = false;
    hitLane = -1;
    patternId = -1;
    for (final c in cells) {
      c.clear();
    }
  }
}

/// Fixed-capacity pool of rows: no allocation during a run.
class RowPool {
  RowPool(int capacity) : _free = List.generate(capacity, (_) => TrackRow());

  final List<TrackRow> _free;

  TrackRow obtain() {
    final row = _free.isEmpty ? TrackRow() : _free.removeLast();
    row.reset();
    return row;
  }

  void release(TrackRow row) => _free.add(row);
}
