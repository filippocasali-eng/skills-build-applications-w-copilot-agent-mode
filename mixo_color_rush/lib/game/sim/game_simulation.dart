import '../ai/patterns.dart';
import '../ai/track_generator.dart';
import '../systems/color_system.dart';
import '../systems/score_system.dart';
import 'difficulty.dart';
import 'replay.dart';
import 'track.dart';

enum SimEventType {
  gateOk,
  gateFail,
  obstacleHit,
  jumpOver,
  drop,
  laneChange,
  jump,
  dive,
  comboTier,
  nearMiss,
  gameOver,
  finished,
}

enum ErrorType { wrongColor, wrongMix, obstacle }

/// Something that happened during a tick; consumed by rendering/audio.
/// Instances are pooled: copy what you need inside the callback.
class SimEvent {
  SimEventType type = SimEventType.gateOk;
  int lane = 0;
  GameColor color = GameColor.red;
  int value = 0;
}

/// Deterministic, render-independent game simulation at a fixed 60 Hz.
class GameSimulation {
  GameSimulation({
    required this.seed,
    required this.params,
    required PatternLibrary library,
    this.startColor = GameColor.red,
  }) : color = startColor,
       lane = params.laneCount ~/ 2 {
    _generator = TrackGenerator(
      seed: seed,
      params: params,
      library: library,
      startColor: startColor,
      liveSkill: _liveSkill,
    );
    _generator.fillUntil(viewDistance, _pool, rows);
  }

  /// Re-simulates [replay] to its end and returns the finished simulation.
  factory GameSimulation.fromReplay(
    Replay replay,
    PatternLibrary library, {
    int? untilTick,
  }) {
    final sim = GameSimulation(
      seed: replay.seed,
      params: replay.params,
      library: library,
      startColor: replay.startColor,
    );
    final end = untilTick ?? replay.endTick;
    var i = 0;
    while (!sim.isOver && sim.tick < end) {
      while (i < replay.inputs.length && replay.inputs[i].tick == sim.tick) {
        sim.input(replay.inputs[i].action);
        i++;
      }
      sim.step();
    }
    return sim;
  }

  static const int ticksPerSecond = 60;
  static const double dt = 1 / ticksPerSecond;
  static const double viewDistance = 90;
  static const int startHearts = 3;
  static const int inputBufferTicks = 7; // ~120 ms
  static const int invulnerableTicks = 60;
  static const int jumpTicks = 33;
  static const int diveTicks = 24;
  static const int rainbowTicks = 180;
  static const int nearMissTicks = 12;
  static const double diveSpeedFactor = 1.35;
  static const double reactionWindow = 40;
  static const int _outcomeWindow = 16;

  final int seed;
  final DifficultyParams params;
  final GameColor startColor;

  final List<TrackRow> rows = [];
  final RowPool _pool = RowPool(64);
  late final TrackGenerator _generator;
  final ScoreSystem score = ScoreSystem();

  int tick = 0;
  double distance = 0;
  double speed = 0;
  double _boost = 0;
  int lane;
  int _laneBefore = -1;
  int lastLaneChangeTick = -1000;
  GameColor color;
  int hearts = startHearts;
  int _invulnerableUntil = -1;
  int _jumpUntil = -1;
  int _diveUntil = -1;
  int _rainbowUntil = -1;
  bool _over = false;
  bool _completed = false;

  final List<int> _outcomes = List.filled(_outcomeWindow, 0);
  int _outcomeCount = 0;
  int _reactionSumTicks = 0;
  int _reactionSamples = 0;
  int obstaclesJumped = 0;
  int mixGatesOk = 0;
  int maxMultiplier = 1;

  int gatesOk = 0;
  int gatesFail = 0;
  int dropsTaken = 0;
  int nearMisses = 0;
  int failsWhileBrown = 0;

  /// Errors indexed by [ErrorType.index].
  final List<int> errorsByType = List.filled(ErrorType.values.length, 0);

  /// Failed gates indexed by the gate's [GameColor.index] (used by Coach).
  final List<int> failsByGateColor = List.filled(GameColor.values.length, 0);

  /// Good gates indexed by gate colour (missions: "pass 10 purple").
  final List<int> okByGateColor = List.filled(GameColor.values.length, 0);

  /// Every input, for replays.
  final List<InputCommand> inputs = [];
  final List<InputCommand> _pending = [];

  final List<SimEvent> _events = List.generate(64, (_) => SimEvent());
  int _eventCount = 0;

  bool get isOver => _over;

  /// True when the run ended by reaching [DifficultyParams.finishDistance].
  bool get isCompleted => _completed;

  TrackGenerator get generator => _generator;

  /// Average reaction time (ms) from a row becoming visible to the first
  /// lane change, over rows passed correctly. 0 if no samples.
  int get avgReactionMs => _reactionSamples == 0
      ? 0
      : _reactionSumTicks * 1000 ~/ (_reactionSamples * ticksPerSecond);

  /// Share of good outcomes (gates passed vs. gates/obstacles failed).
  double get successRate {
    final bad = gatesFail + errorsByType[ErrorType.obstacle.index];
    final total = gatesOk + bad;
    return total == 0 ? 1 : gatesOk / total;
  }

  /// Live skill signal in [-1, 1] for the generator: recent success rate
  /// relative to the 70–85 % flow zone.
  double _liveSkill() {
    final n = _outcomeCount < _outcomeWindow ? _outcomeCount : _outcomeWindow;
    if (n < 6) return 0;
    var ok = 0;
    for (var i = 0; i < n; i++) {
      ok += _outcomes[i];
    }
    final rate = ok / n;
    if (rate > 0.85) return ((rate - 0.85) / 0.15).clamp(0.0, 1.0);
    if (rate < 0.70) return -((0.70 - rate) / 0.3).clamp(0.0, 1.0);
    return 0;
  }

  void _outcome(bool good) {
    _outcomes[_outcomeCount % _outcomeWindow] = good ? 1 : 0;
    _outcomeCount++;
  }

  bool get isJumping => tick < _jumpUntil;
  bool get isDiving => tick < _diveUntil;
  bool get isRainbow => tick < _rainbowUntil;
  bool get isInvulnerable => tick < _invulnerableUntil;
  int get elapsedMs => tick * 1000 ~/ ticksPerSecond;

  /// 0..1 progress of the current jump (0 when on the ground).
  double get jumpPhase => isJumping ? 1 - (_jumpUntil - tick) / jumpTicks : 0;

  Replay toReplay() => Replay(
    seed: seed,
    params: params,
    startColor: startColor,
    inputs: List.of(inputs),
    endTick: tick,
  );

  /// Queues a player input; applied on the next [step].
  void input(InputAction action) {
    if (_over) return;
    final cmd = InputCommand(tick, action);
    inputs.add(cmd);
    _pending.add(cmd);
  }

  /// Calls [onEvent] for every event since the last drain.
  void drainEvents(void Function(SimEvent e) onEvent) {
    for (var i = 0; i < _eventCount; i++) {
      onEvent(_events[i]);
    }
    _eventCount = 0;
  }

  void _emit(
    SimEventType type, {
    int lane = 0,
    GameColor? color,
    int value = 0,
  }) {
    if (_eventCount >= _events.length) return;
    final e = _events[_eventCount++];
    e.type = type;
    e.lane = lane;
    e.color = color ?? this.color;
    e.value = value;
  }

  void step() {
    if (_over) return;
    _applyInputs();

    speed =
        params.speedAt(distance) * (isDiving ? diveSpeedFactor : 1) + _boost;
    _boost *= 0.985;
    distance += speed * dt;

    _generator.fillUntil(distance + viewDistance, _pool, rows);
    for (final row in rows) {
      if (row.visibleTick < 0 && row.d - distance <= reactionWindow) {
        row.visibleTick = tick;
      }
      if (row.d > distance) break;
      if (!row.resolved) {
        row.resolved = true;
        row.hitLane = lane;
        _resolve(row);
        if (_over) break;
      }
    }
    while (rows.isNotEmpty && rows.first.d < distance - 8) {
      _pool.release(rows.removeAt(0));
    }
    tick++;
    if (!_over &&
        params.finishDistance > 0 &&
        distance >= params.finishDistance) {
      _over = true;
      _completed = true;
      _emit(SimEventType.finished);
    }
  }

  void _applyInputs() {
    var w = 0;
    for (var i = 0; i < _pending.length; i++) {
      final cmd = _pending[i];
      if (tick - cmd.tick > inputBufferTicks) continue;
      if (!_apply(cmd.action)) _pending[w++] = cmd; // keep buffered
    }
    _pending.length = w;
  }

  /// Returns false if the input should stay buffered.
  bool _apply(InputAction action) {
    switch (action) {
      case InputAction.left:
      case InputAction.right:
        final target = lane + (action == InputAction.left ? -1 : 1);
        if (target < 0 || target >= params.laneCount) return true;
        _laneBefore = lane;
        lane = target;
        lastLaneChangeTick = tick;
        for (final row in rows) {
          if (row.resolved || row.visibleTick < 0) continue;
          if (row.reactTick < 0) row.reactTick = tick;
        }
        _emit(SimEventType.laneChange, lane: lane);
        return true;
      case InputAction.jump:
        if (!params.jumpEnabled) return true;
        if (isJumping) return false;
        _jumpUntil = tick + jumpTicks;
        _emit(SimEventType.jump, lane: lane);
        return true;
      case InputAction.dive:
        if (!params.diveEnabled) return true;
        if (isDiving || isJumping) return false;
        _diveUntil = tick + diveTicks;
        _emit(SimEventType.dive, lane: lane);
        return true;
    }
  }

  /// Whether [cell] would hurt Mixo with its current state.
  bool _hurts(Cell cell) => switch (cell.type) {
    CellType.gate => !isRainbow && cell.color != color,
    CellType.obstacle => !(cell.low && isJumping),
    _ => false,
  };

  void _resolve(TrackRow row) {
    final cell = row.cells[lane];
    final hurt = _hurts(cell);
    if (!hurt &&
        tick - lastLaneChangeTick <= nearMissTicks &&
        _laneBefore >= 0 &&
        _hurts(row.cells[_laneBefore])) {
      nearMisses++;
      score.add(ScoreSystem.nearMissPoints);
      _emit(
        SimEventType.nearMiss,
        lane: lane,
        value: ScoreSystem.nearMissPoints,
      );
    }
    switch (cell.type) {
      case CellType.empty:
        break;
      case CellType.gate:
        if (!hurt) {
          gatesOk++;
          okByGateColor[cell.color.index]++;
          if (cell.color.isSecondary) mixGatesOk++;
          _outcome(true);
          if (row.reactTick >= 0) {
            _reactionSumTicks += row.reactTick - row.visibleTick;
            _reactionSamples++;
          }
          final tierUp = score.gatePassed();
          if (score.multiplier > maxMultiplier) {
            maxMultiplier = score.multiplier;
          }
          _boost += 0.6;
          _emit(SimEventType.gateOk, lane: lane, color: cell.color);
          if (tierUp) {
            _emit(SimEventType.comboTier, value: score.multiplier);
          }
        } else {
          gatesFail++;
          if (color == GameColor.brown) failsWhileBrown++;
          _outcome(false);
          failsByGateColor[cell.color.index]++;
          final mixError = !cell.color.isPrimary || !color.isPrimary;
          _damage(mixError ? ErrorType.wrongMix : ErrorType.wrongColor);
          _emit(SimEventType.gateFail, lane: lane, color: cell.color);
        }
      case CellType.obstacle:
        if (hurt) {
          _outcome(false);
          _damage(ErrorType.obstacle);
          _emit(SimEventType.obstacleHit, lane: lane);
        } else {
          obstaclesJumped++;
          score.add(ScoreSystem.jumpPoints);
          _emit(SimEventType.jumpOver, lane: lane);
        }
      case CellType.drop:
        dropsTaken++;
        _absorb(cell);
        score.add(ScoreSystem.dropPoints);
        _emit(SimEventType.drop, lane: lane, value: cell.dropKind.index);
    }
  }

  void _absorb(Cell cell) {
    switch (cell.dropKind) {
      case DropKind.color:
        color = ColorSystem.mix(color, cell.color, mixing: params.mixing);
      case DropKind.white:
        color = startColor;
      case DropKind.rainbow:
        _rainbowUntil = tick + rainbowTicks;
      case DropKind.invert:
        color = ColorSystem.complement(color);
    }
  }

  void _damage(ErrorType type) {
    errorsByType[type.index]++;
    score.breakCombo();
    _boost = 0;
    if (isInvulnerable) return;
    hearts--;
    _invulnerableUntil = tick + invulnerableTicks;
    if (hearts <= 0) {
      hearts = 0;
      _over = true;
      _emit(SimEventType.gameOver);
    }
  }
}
