import 'dart:math' as math;

import '../sim/difficulty.dart';
import '../sim/track.dart';
import '../systems/color_system.dart';

/// Result of validating a chunk.
class ChunkCheck {
  bool ok = false;

  /// Colours Mixo may have at the end of the chunk without taking damage.
  int endMask = 0;

  /// Bitmask of entry colours that have a damage-free path.
  int survivingEntries = 0;
}

/// Proves that a chunk is solvable by exhaustively exploring every
/// (lane, colour, rainbow) state a player can reach without taking damage.
///
/// Lane changes are limited by a human swipe rate: between two rows the
/// player can move at most `gap / laneChangeSeconds` lanes.
class ChunkValidator {
  ChunkValidator(this.params, {this.baseColor = GameColor.red});

  /// Conservative time a player needs for one lane change.
  static const double laneChangeSeconds = 0.18;

  /// Rainbow lasts 3 s; measured in distance at the slowest possible speed.
  static const double rainbowSeconds = 2.9;

  final DifficultyParams params;
  final GameColor baseColor;

  // Scratch state sets: index = lane * 8 + colour, value = rainbow-until
  // distance (-1 = none). Dominance: a larger rainbow window is better.
  final List<double> _a = List.filled(TrackRow.maxLanes * 8, -2);
  final List<double> _b = List.filled(TrackRow.maxLanes * 8, -2);

  int maxMoves(double gapSeconds) =>
      math.max(1, (gapSeconds / laneChangeSeconds).floor());

  /// Validates `rows[0..count)`. [prevD] is the distance of the row before
  /// the chunk (the player can be in any lane there). [plan] must survive;
  /// in strict mode every colour of [entryMask] must survive too.
  void validate(
    List<TrackRow> rows,
    int count,
    double prevD,
    int entryMask,
    GameColor plan,
    ChunkCheck out,
  ) {
    out
      ..ok = false
      ..endMask = 0
      ..survivingEntries = 0;
    final mask = entryMask | (1 << plan.index);
    for (final c in GameColor.values) {
      if (mask & (1 << c.index) == 0) continue;
      final end = _run(rows, count, prevD, c);
      if (end != 0) {
        out
          ..survivingEntries |= 1 << c.index
          ..endMask |= end;
      }
    }
    final planOk = out.survivingEntries & (1 << plan.index) != 0;
    final allOk = (out.survivingEntries & mask) == mask;
    out.ok = planOk && (!params.strict || allOk) && out.endMask != 0;
  }

  /// Returns the mask of end colours reachable from [entry], 0 if none.
  int _run(List<TrackRow> rows, int count, double prevD, GameColor entry) {
    final lanes = params.laneCount;
    var cur = _a;
    var next = _b;
    cur.fillRange(0, cur.length, -2);
    for (var l = 0; l < lanes; l++) {
      cur[l * 8 + entry.index] = -1;
    }
    var lastD = prevD;
    for (var r = 0; r < count; r++) {
      final row = rows[r];
      final speed = params.speedAt(row.d);
      // Boosts only make the player faster: use 10 % margin.
      final gap = (row.d - lastD) / (speed * 1.1);
      final moves = maxMoves(gap);
      next.fillRange(0, next.length, -2);
      var any = false;
      for (var l = 0; l < lanes; l++) {
        for (var c = 0; c < 7; c++) {
          final rainbow = cur[l * 8 + c];
          if (rainbow < -1.5) continue;
          final lo = math.max(0, l - moves);
          final hi = math.min(lanes - 1, l + moves);
          for (var nl = lo; nl <= hi; nl++) {
            any |= _apply(row, nl, GameColor.values[c], rainbow, next);
          }
        }
      }
      if (!any) return 0;
      final t = cur;
      cur = next;
      next = t;
      lastD = row.d;
    }
    var end = 0;
    for (var i = 0; i < cur.length; i++) {
      if (cur[i] > -1.5) end |= 1 << (i % 8);
    }
    return end;
  }

  bool _apply(
    TrackRow row,
    int lane,
    GameColor c,
    double rainbow,
    List<double> next,
  ) {
    final cell = row.cells[lane];
    var color = c;
    var rb = rainbow >= row.d ? rainbow : -1.0;
    switch (cell.type) {
      case CellType.empty:
        break;
      case CellType.gate:
        if (rb < 0 && cell.color != color) return false;
      case CellType.obstacle:
        if (!(cell.low && params.jumpEnabled)) return false;
      case CellType.drop:
        switch (cell.dropKind) {
          case DropKind.color:
            color = ColorSystem.mix(color, cell.color, mixing: params.mixing);
          case DropKind.white:
            color = baseColor;
          case DropKind.invert:
            color = ColorSystem.complement(color);
          case DropKind.rainbow:
            rb = row.d + params.speedAt(row.d) * rainbowSeconds;
        }
    }
    final i = lane * 8 + color.index;
    if (rb > next[i]) next[i] = rb;
    return true;
  }
}
