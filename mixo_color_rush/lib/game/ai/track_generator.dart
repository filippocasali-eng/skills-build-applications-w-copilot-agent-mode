import '../sim/difficulty.dart';
import '../sim/rng.dart';
import '../sim/track.dart';
import '../systems/color_system.dart';
import 'chunk_validator.dart';
import 'patterns.dart';

/// Procedural track generator working in chunks (~3 s) built from
/// hand-authored [Pattern]s.
///
/// The track depends only on (seed, params, startColor, library) and — when
/// live adaptation is on — on the player's recorded outcomes, so replays
/// reproduce it exactly. Every chunk is proved solvable by
/// [ChunkValidator] before being committed; impossible instantiations are
/// discarded and retried.
class TrackGenerator {
  TrackGenerator({
    required int seed,
    required this.params,
    required this.library,
    this.startColor = GameColor.red,
    this.liveSkill,
  }) : _rng = Rng(seed),
       _plan = startColor,
       _mask = 1 << startColor.index,
       _validator = ChunkValidator(params, baseColor: startColor) {
    _eligible = [
      for (var i = 0; i < library.patterns.length; i++)
        if (_allowed(library.patterns[i])) i,
    ];
  }

  static const double firstRowDistance = 30;
  static const int introChunks = 2;
  static const int maxAttempts = 10;

  final DifficultyParams params;
  final PatternLibrary library;
  final GameColor startColor;

  /// Live skill signal in [-1, 1] (negative: struggling). Optional.
  final double Function()? liveSkill;

  final Rng _rng;
  final ChunkValidator _validator;
  final ChunkCheck _check = ChunkCheck();
  late final List<int> _eligible;
  final List<TrackRow> _scratch = List.generate(8, (_) => TrackRow());

  double _nextD = firstRowDistance;
  double _lastRowD = 0;
  GameColor _plan;
  int _mask;
  int _chunkIndex = 0;
  int _lastPattern = -1;

  /// Stats (debug / tests).
  int chunksGenerated = 0;
  int fallbacks = 0;

  double get nextD => _nextD;
  int get reachableMask => _mask;
  GameColor get planColor => _plan;

  bool _allowed(Pattern p) {
    if (p.tier > params.maxTier) return false;
    for (final f in p.requires) {
      final ok = switch (f) {
        PatternFeature.drops => params.drops,
        PatternFeature.obstacles => params.obstacles,
        PatternFeature.mix => params.mixing,
        PatternFeature.special => params.specials,
        PatternFeature.jump => params.jumpEnabled,
      };
      if (!ok) return false;
    }
    return true;
  }

  void fillUntil(double maxD, RowPool pool, List<TrackRow> out) {
    while (_nextD <= maxD) {
      _generateChunk(pool, out);
    }
  }

  void _generateChunk(RowPool pool, List<TrackRow> out) {
    final live = (params.liveAdapt && liveSkill != null)
        ? liveSkill!().clamp(-1.0, 1.0)
        : 0.0;
    final intro = _chunkIndex < introChunks;
    final targetTier = intro
        ? 0.0
        : (params.targetTier + live * 1.5).clamp(
            0.0,
            params.maxTier.toDouble(),
          );
    final gapMul = 1 - 0.12 * live;
    final brownRisk =
        _mask & (1 << GameColor.brown.index) != 0 ||
        (params.mixing && _bitCount(_mask) > 3);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final pIndex = _pick(attempt >= 6 || intro ? 0 : targetTier);
      if (pIndex < 0) break;
      final count = _instantiate(
        library.patterns[pIndex],
        gapMul,
        rescueWhite: brownRisk && params.mixing,
      );
      _validator.validate(
        _scratch,
        count,
        _lastRowD,
        _mask,
        _startPlan,
        _check,
      );
      if (_check.ok) {
        _commit(count, pIndex, pool, out);
        _lastPattern = pIndex;
        return;
      }
    }
    // Fallback: a breather row (always valid, keeps the state).
    fallbacks++;
    final row = pool.obtain()
      ..d = _nextD
      ..patternId = -1;
    out.add(row);
    _lastRowD = _nextD;
    _nextD += params.gapAt(_nextD) * params.speedAt(_nextD);
    _chunkIndex++;
  }

  int _pick(double targetTier) {
    var total = 0.0;
    for (final i in _eligible) {
      total += _weight(i, targetTier);
    }
    if (total <= 0) return -1;
    var r = _rng.nextDouble() * total;
    for (final i in _eligible) {
      r -= _weight(i, targetTier);
      if (r <= 0) return i;
    }
    return _eligible.last;
  }

  double _weight(int i, double targetTier) {
    final p = library.patterns[i];
    if (targetTier == 0 && p.tier > 0) return 0;
    final w = 1 / (1 + (p.tier - targetTier).abs() * 1.5);
    return i == _lastPattern ? w * 0.2 : w;
  }

  late GameColor _startPlan;
  GameColor _endPlan = GameColor.red;

  /// Fills `_scratch` from [p]; returns the number of rows.
  int _instantiate(Pattern p, double gapMul, {required bool rescueWhite}) {
    _startPlan = _plan;
    var plan = _plan;
    final lanes = params.laneCount;
    final mirror = _rng.chance(0.5);
    final offset = lanes > Pattern.lanes
        ? _rng.nextInt(lanes - Pattern.lanes + 1)
        : 0;
    var d = _nextD;
    var n = 0;
    var first = true;

    if (rescueWhite) {
      final row = _scratch[n++]..reset();
      row.d = d;
      for (var l = 0; l < lanes; l++) {
        row.cells[l]
          ..type = CellType.drop
          ..dropKind = DropKind.white
          ..color = startColor;
      }
      plan = startColor;
      first = false;
    }

    for (final pr in p.rows) {
      final row = _scratch[n++]..reset();
      if (!first) d += params.gapAt(d) * params.speedAt(d) * pr.gap * gapMul;
      first = false;
      row.d = d;

      // Per-row drop colours.
      final dropColor = _mixDropColor(plan);
      final badColor = _badDropColor(plan, dropColor);
      final rowHasGate = pr.tokens.any(
        (t) => t == PatternToken.target || t == PatternToken.decoy,
      );
      final rowHasObstacle = pr.tokens.any(
        (t) => t == PatternToken.obstacle || t == PatternToken.lowObstacle,
      );
      var nextPlan = plan;

      for (var l = 0; l < lanes; l++) {
        final pl = l - offset;
        final PatternToken token;
        if (pl < 0 || pl >= Pattern.lanes) {
          token = rowHasGate
              ? PatternToken.decoy
              : rowHasObstacle && _rng.chance(0.5)
              ? PatternToken.obstacle
              : PatternToken.empty;
        } else {
          token = pr.tokens[mirror ? Pattern.lanes - 1 - pl : pl];
        }
        final cell = row.cells[l];
        switch (token) {
          case PatternToken.empty:
            break;
          case PatternToken.target:
            cell
              ..type = CellType.gate
              ..color = plan;
          case PatternToken.decoy:
            cell
              ..type = CellType.gate
              ..color = _decoy(plan);
          case PatternToken.obstacle:
            cell.type = CellType.obstacle;
          case PatternToken.lowObstacle:
            cell
              ..type = CellType.obstacle
              ..low = true;
          case PatternToken.mixDrop:
            cell
              ..type = CellType.drop
              ..color = dropColor;
            nextPlan = ColorSystem.mix(plan, dropColor, mixing: params.mixing);
          case PatternToken.badDrop:
            cell
              ..type = CellType.drop
              ..color = badColor;
          case PatternToken.white:
            cell
              ..type = CellType.drop
              ..dropKind = DropKind.white
              ..color = startColor;
            nextPlan = startColor;
          case PatternToken.rainbow:
            cell
              ..type = CellType.drop
              ..dropKind = DropKind.rainbow;
          case PatternToken.invert:
            cell
              ..type = CellType.drop
              ..dropKind = DropKind.invert;
            nextPlan = ColorSystem.complement(plan);
        }
      }
      plan = nextPlan;
    }
    _endPlan = plan;
    return n;
  }

  GameColor _mixDropColor(GameColor plan) {
    if (!params.mixing) {
      // Replace mode: a different primary.
      final options = [
        for (final c in GameColor.primaries)
          if (c != plan) c,
      ];
      return options[_rng.nextInt(options.length)];
    }
    if (plan.isPrimary) {
      final options = [
        for (final c in GameColor.primaries)
          if (c != plan) c,
      ];
      return options[_rng.nextInt(options.length)];
    }
    // Secondary (or brown): a component keeps the colour unchanged.
    final comps = [
      for (final c in GameColor.primaries)
        if (plan.components & c.components != 0) c,
    ];
    return comps[_rng.nextInt(comps.length)];
  }

  GameColor _badDropColor(GameColor plan, GameColor good) {
    if (params.mixing && plan.isSecondary) {
      // The missing primary: turns Mixo brown.
      return GameColor.primaries.firstWhere(
        (c) => plan.components & c.components == 0,
      );
    }
    final options = [
      for (final c in GameColor.primaries)
        if (c != plan && c != good) c,
    ];
    return options.isEmpty ? good : options[_rng.nextInt(options.length)];
  }

  GameColor _decoy(GameColor plan) {
    // In strict mode, decoys often match another colour Mixo may have:
    // this keeps rows passable for players who skipped a drop.
    if (params.strict && _rng.chance(0.5)) {
      for (final c in GameColor.values) {
        if (c != plan && c != GameColor.brown && _mask & (1 << c.index) != 0) {
          return c;
        }
      }
    }
    final palette = params.mixDepth >= 2 || !plan.isPrimary
        ? const [...GameColor.primaries, ...GameColor.secondaries]
        : GameColor.primaries;
    while (true) {
      final c = palette[_rng.nextInt(palette.length)];
      if (c != plan) return c;
    }
  }

  void _commit(int count, int patternId, RowPool pool, List<TrackRow> out) {
    for (var i = 0; i < count; i++) {
      final src = _scratch[i];
      final row = pool.obtain()
        ..d = src.d
        ..patternId = patternId;
      for (var l = 0; l < TrackRow.maxLanes; l++) {
        row.cells[l].copyFrom(src.cells[l]);
      }
      out.add(row);
    }
    final last = _scratch[count - 1].d;
    _lastRowD = last;
    _nextD = last + params.gapAt(last) * params.speedAt(last) * 1.25;
    _plan = _endPlan;
    _mask = _check.endMask | (1 << _plan.index);
    _chunkIndex++;
    chunksGenerated++;
  }

  static int _bitCount(int v) {
    var c = 0;
    for (var x = v; x != 0; x &= x - 1) {
      c++;
    }
    return c;
  }
}
