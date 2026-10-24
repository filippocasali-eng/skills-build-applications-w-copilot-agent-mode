import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'ai/patterns.dart';
import 'components/mixo_component.dart';
import 'components/track_component.dart';
import 'render/projection.dart';
import 'sim/difficulty.dart';
import 'sim/game_simulation.dart';
import 'sim/replay.dart';
import 'systems/color_system.dart';

/// Snapshot of what the Flutter HUD shows. Rebuilt only when it changes.
@immutable
class HudData {
  const HudData({
    this.score = 0,
    this.combo = 0,
    this.multiplier = 1,
    this.hearts = GameSimulation.startHearts,
    this.color = GameColor.red,
  });

  final int score;
  final int combo;
  final int multiplier;
  final int hearts;
  final GameColor color;

  @override
  bool operator ==(Object other) =>
      other is HudData &&
      other.score == score &&
      other.combo == combo &&
      other.multiplier == multiplier &&
      other.hearts == hearts &&
      other.color == color;

  @override
  int get hashCode => Object.hash(score, combo, multiplier, hearts, color);
}

/// Flame game: runs [GameSimulation] at a fixed 60 Hz step and renders it.
class MixoGame extends FlameGame {
  MixoGame({
    required this.library,
    required int seed,
    required DifficultyParams params,
    this.onGameOver,
    this.showSymbols = true,
  }) : sim = GameSimulation(library: library, seed: seed, params: params);

  final PatternLibrary library;
  GameSimulation sim;
  final void Function(GameSimulation sim)? onGameOver;
  bool showSymbols;

  final Projection projection = Projection();
  final ValueNotifier<HudData> hud = ValueNotifier(const HudData());

  late final MixoComponent _mixo;
  double _accumulator = 0;
  double time = 0;
  bool _gameOverSent = false;

  double _shake = 0;
  final math.Random _shakeRng = math.Random(1);

  @override
  Color backgroundColor() => const Color(0xFF120A33);

  @override
  Future<void> onLoad() async {
    _mixo = MixoComponent();
    await addAll([
      TrackComponent(near: false),
      _mixo,
      TrackComponent(near: true),
    ]);
    _mixo.reset();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    projection.resize(size.x, size.y, sim.params.laneCount);
  }

  /// Starts a fresh run immediately (restart is < 1 frame).
  void startRun({required int seed, required DifficultyParams params}) {
    sim = GameSimulation(library: library, seed: seed, params: params);
    projection.resize(size.x, size.y, params.laneCount);
    _accumulator = 0;
    _gameOverSent = false;
    _shake = 0;
    if (isLoaded) _mixo.reset();
    _publishHud();
    resumeEngine();
  }

  void input(InputAction action) => sim.input(action);

  @override
  void update(double dt) {
    final clamped = math.min(dt, 0.1);
    time += clamped;
    _accumulator += clamped;
    var steps = 0;
    while (_accumulator >= GameSimulation.dt && steps < 6) {
      sim.step();
      _accumulator -= GameSimulation.dt;
      steps++;
    }
    if (steps == 6) _accumulator = 0;
    sim.drainEvents(_onEvent);
    _shake = math.max(0, _shake - clamped * 3);
    super.update(clamped);
    _publishHud();
    if (sim.isOver && !_gameOverSent) {
      _gameOverSent = true;
      onGameOver?.call(sim);
    }
  }

  void _onEvent(SimEvent e) {
    switch (e.type) {
      case SimEventType.laneChange:
        _mixo.onLaneChange();
      case SimEventType.gateFail:
      case SimEventType.obstacleHit:
        _shake = 0.35;
        _mixo.onHit();
      default:
        break;
    }
  }

  void _publishHud() {
    final next = HudData(
      score: sim.score.score,
      combo: sim.score.combo,
      multiplier: sim.score.multiplier,
      hearts: sim.hearts,
      color: sim.color,
    );
    if (next != hud.value) hud.value = next;
  }

  @override
  void render(Canvas canvas) {
    if (_shake > 0) {
      final m = _shake * projection.laneWidth * 0.08;
      canvas
        ..save()
        ..translate(
          (_shakeRng.nextDouble() * 2 - 1) * m,
          (_shakeRng.nextDouble() * 2 - 1) * m,
        );
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  @override
  void onRemove() {
    hud.dispose();
    super.onRemove();
  }
}
