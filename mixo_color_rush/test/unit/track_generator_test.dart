import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/game/ai/chunk_validator.dart';
import 'package:mixo_color_rush/game/ai/patterns.dart';
import 'package:mixo_color_rush/game/ai/track_generator.dart';
import 'package:mixo_color_rush/game/sim/difficulty.dart';
import 'package:mixo_color_rush/game/sim/rng.dart';
import 'package:mixo_color_rush/game/sim/track.dart';
import 'package:mixo_color_rush/game/systems/color_system.dart';

import '../support/test_data.dart';

/// Independent brute force: depth-first search over lane choices, used to
/// double-check the validator. Returns true if some damage-free path exists
/// through [rows] starting with colour [entry] from any lane.
bool bruteForceSolvable(
  List<TrackRow> rows,
  double prevD,
  GameColor entry,
  DifficultyParams p,
) {
  bool go(int i, int lane, GameColor c, double rainbow, double lastD) {
    if (i == rows.length) return true;
    final row = rows[i];
    final gap = (row.d - lastD) / (p.speedAt(row.d) * 1.1);
    final moves = (gap / ChunkValidator.laneChangeSeconds).floor().clamp(1, 99);
    for (var nl = lane - moves; nl <= lane + moves; nl++) {
      if (nl < 0 || nl >= p.laneCount) continue;
      final cell = row.cells[nl];
      var color = c;
      var rb = rainbow >= row.d ? rainbow : -1.0;
      var ok = true;
      switch (cell.type) {
        case CellType.empty:
          break;
        case CellType.gate:
          ok = rb >= 0 || cell.color == color;
        case CellType.obstacle:
          ok = cell.low && p.jumpEnabled;
        case CellType.drop:
          switch (cell.dropKind) {
            case DropKind.color:
              color = ColorSystem.mix(color, cell.color, mixing: p.mixing);
            case DropKind.white:
              color = GameColor.red;
            case DropKind.invert:
              color = ColorSystem.complement(color);
            case DropKind.rainbow:
              rb = row.d + p.speedAt(row.d) * ChunkValidator.rainbowSeconds;
          }
      }
      if (ok && go(i + 1, nl, color, rb, row.d)) return true;
    }
    return false;
  }

  for (var l = 0; l < p.laneCount; l++) {
    if (go(0, l, entry, -1, prevD)) return true;
  }
  return false;
}

void main() {
  final lib = loadLibrary();
  final director = loadDirector();

  test('pattern library has at least 40 valid patterns', () {
    expect(lib.patterns.length, greaterThanOrEqualTo(40));
    expect(lib.patterns.map((p) => p.id).toSet().length, lib.patterns.length);
  });

  test('10,000 generated chunks are all solvable (brute-force check)', () {
    final rng = Rng(2024);
    var chunks = 0;
    var fallbacks = 0;
    var run = 0;
    while (chunks < 10000) {
      final rating = rng.nextDouble() * 1000;
      final params = director
          .paramsFor(rating, level: 1 + rng.nextInt(15))
          .copyWith(liveAdapt: false);
      final gen = TrackGenerator(seed: run++, params: params, library: lib);
      final pool = RowPool(512);
      final rows = <TrackRow>[];
      var prevD = 0.0;
      var lastChunkEnd = 0;
      // Plan colour at each chunk start = colour of the previous chunk end.
      var plan = gen.planColor;
      for (var c = 0; c < 60; c++) {
        final before = rows.length;
        gen.fillUntil(gen.nextD, pool, rows);
        final chunk = rows.sublist(before);
        if (chunk.length == 1 && chunk.first.patternId < 0) {
          fallbacks++;
        } else {
          expect(
            bruteForceSolvable(chunk, prevD, plan, params),
            isTrue,
            reason:
                'run $run chunk $c pattern ${lib.patterns[chunk.first.patternId].id}',
          );
        }
        plan = gen.planColor;
        prevD = rows.last.d;
        lastChunkEnd = rows.length;
        chunks++;
      }
      expect(lastChunkEnd, greaterThan(0));
    }
    // Fallback breathers must stay rare.
    expect(fallbacks / chunks, lessThan(0.05), reason: 'fallbacks $fallbacks');
  });

  test('every pattern is reachable at some difficulty', () {
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      final params = director
          .paramsFor((seed % 10) * 100.0, level: 12)
          .copyWith(liveAdapt: false);
      final gen = TrackGenerator(seed: seed, params: params, library: lib);
      final rows = <TrackRow>[];
      gen.fillUntil(3000, RowPool(1024), rows);
      for (final r in rows) {
        if (r.patternId >= 0) seen.add(lib.patterns[r.patternId].id);
      }
    }
    final missing = lib.patterns.map((p) => p.id).toSet().difference(seen);
    expect(missing, isEmpty);
  });

  test('same seed and params give the same track', () {
    final params = director.paramsFor(500, level: 6);
    List<String> track(int seed) {
      final gen = TrackGenerator(seed: seed, params: params, library: lib);
      final rows = <TrackRow>[];
      gen.fillUntil(2000, RowPool(1024), rows);
      return [
        for (final r in rows)
          '${r.d.toStringAsFixed(3)}:${[for (final c in r.cells) '${c.type.index}${c.color.index}${c.dropKind.index}'].join()}',
      ];
    }

    expect(track(7), track(7));
    expect(track(7), isNot(track(8)));
  });

  test('a validator rejects an impossible chunk', () {
    const params = DifficultyParams(mixing: true);
    final row = TrackRow()..d = 50;
    for (var l = 0; l < 3; l++) {
      row.cells[l]
        ..type = CellType.gate
        ..color = GameColor.blue;
    }
    final check = ChunkCheck();
    ChunkValidator(params)
        .validate([row], 1, 30, 1 << GameColor.red.index, GameColor.red, check);
    expect(check.ok, isFalse);
  });

  test('pattern tokens parse', () {
    expect(PatternToken.parse('T'), PatternToken.target);
    expect(() => PatternToken.parse('?'), throwsFormatException);
  });
}
