import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/models/cosmetics.dart';
import '../core/services/feedback.dart';
import 'ai/patterns.dart';
import 'components/effects_component.dart';
import 'components/ghost_component.dart';
import 'components/mixo_component.dart';
import 'components/particles_component.dart';
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
    this.ghostDelta,
    this.progress,
  });

  final int score;
  final int combo;
  final int multiplier;
  final int hearts;
  final GameColor color;

  /// Ghost score minus player score (null without ghost).
  final int? ghostDelta;

  /// 0..1 course progress (Academy), null otherwise.
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is HudData &&
      other.score == score &&
      other.combo == combo &&
      other.multiplier == multiplier &&
      other.hearts == hearts &&
      other.color == color &&
      other.ghostDelta == ghostDelta &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(
    score,
    combo,
    multiplier,
    hearts,
    color,
    ghostDelta,
    progress,
  );
}

/// Visual options (cosmetics and accessibility). Never affect gameplay.
class GameLook {
  const GameLook({
    this.accessory = Accessory.none,
    this.trail = TrailKind.none,
    this.palette = const ThemePalette(
      skyTop: 0xFF120A33,
      skyMid: 0xFF3B1C7A,
      skyBottom: 0xFF6A2BB0,
      floorFar: 0xFF1A0F40,
      floorNear: 0xFF2E1A66,
      ringHue: 200,
      ringSpread: 160,
    ),
    this.symbols = true,
    this.reduceEffects = false,
  });

  final Accessory accessory;
  final TrailKind trail;
  final ThemePalette palette;
  final bool symbols;
  final bool reduceEffects;
}

/// Localized texts drawn inside the game canvas.
class GameLabels {
  const GameLabels({this.nearMiss = 'NEAR MISS!', this.combo = 'COMBO'});

  final String nearMiss;
  final String combo;
}

/// Flame game: runs [GameSimulation] at a fixed 60 Hz step and renders it.
class MixoGame extends FlameGame {
  MixoGame({
    required this.library,
    required int seed,
    required DifficultyParams params,
    GameAudio? audio,
    Haptics? haptics,
    this.look = const GameLook(),
    this.labels = const GameLabels(),
    this.onGameOver,
  }) : audio = audio ?? SilentAudio(),
       haptics = haptics ?? (Haptics()..enabled = false),
       sim = GameSimulation(library: library, seed: seed, params: params);

  final PatternLibrary library;
  final GameAudio audio;
  final Haptics haptics;
  GameLook look;
  GameLabels labels;
  GameSimulation sim;
  final void Function(GameSimulation sim)? onGameOver;

  /// Optional ghost replaying [_ghostReplay] on the same track.
  GameSimulation? ghost;
  Replay? _ghostReplay;
  int _ghostInput = 0;

  final Projection projection = Projection();
  final ValueNotifier<HudData> hud = ValueNotifier(const HudData());

  late final MixoComponent _mixo;
  late final ParticlesComponent particles;
  late final EffectsComponent _effects;
  double _accumulator = 0;
  double time = 0;
  bool _gameOverSent = false;
  double _slowMo = 0;
  double _shake = 0;
  final math.Random _shakeRng = math.Random(1);

  /// Real seconds of play since the run started (excludes pauses).
  double playSeconds = 0;

  @override
  Color backgroundColor() => Color(look.palette.skyTop);

  @override
  Future<void> onLoad() async {
    _mixo = MixoComponent();
    particles = ParticlesComponent();
    _effects = EffectsComponent();
    await addAll([
      TrackComponent(near: false),
      GhostComponent(),
      _mixo,
      TrackComponent(near: true),
      particles,
      _effects,
    ]);
    _mixo.reset();
    audio.startMusic();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    projection.resize(size.x, size.y, sim.params.laneCount);
  }

  /// Starts a fresh run immediately (restart is < 1 frame).
  void startRun({
    required int seed,
    required DifficultyParams params,
    Replay? ghostReplay,
  }) {
    sim = GameSimulation(library: library, seed: seed, params: params);
    _ghostReplay = ghostReplay;
    _ghostInput = 0;
    ghost = ghostReplay == null
        ? null
        : GameSimulation(
            library: library,
            seed: ghostReplay.seed,
            params: ghostReplay.params,
            startColor: ghostReplay.startColor,
          );
    projection.resize(size.x, size.y, params.laneCount);
    _accumulator = 0;
    _gameOverSent = false;
    _shake = 0;
    _slowMo = 0;
    playSeconds = 0;
    if (isLoaded) {
      _mixo.reset();
      particles.clear();
      _effects.clear();
      audio.startMusic();
    }
    _publishHud();
    resumeEngine();
  }

  void input(InputAction action) => sim.input(action);

  void _stepGhost() {
    final g = ghost;
    final r = _ghostReplay;
    if (g == null || r == null || g.isOver) return;
    while (_ghostInput < r.inputs.length &&
        r.inputs[_ghostInput].tick == g.tick) {
      g.input(r.inputs[_ghostInput].action);
      _ghostInput++;
    }
    g.step();
    g.drainEvents(_ignore);
  }

  static void _ignore(SimEvent e) {}

  @override
  void update(double dt) {
    final real = math.min(dt, 0.1);
    final scaled = _slowMo > 0 ? real * 0.3 : real;
    _slowMo = math.max(0, _slowMo - real);
    time += scaled;
    if (!sim.isOver) playSeconds += real;
    _accumulator += scaled;
    var steps = 0;
    while (_accumulator >= GameSimulation.dt && steps < 6) {
      sim.step();
      _stepGhost();
      _accumulator -= GameSimulation.dt;
      steps++;
    }
    if (steps == 6) _accumulator = 0;
    sim.drainEvents(_onEvent);
    _shake = math.max(0, _shake - real * 3);

    // Dynamic FOV and music follow the speed.
    final speed = sim.speed;
    projection.focal =
        Projection.baseFocal - ((speed - 9) * 0.1).clamp(0.0, 1.8);
    final level = speed < 13
        ? 1
        : speed < 18
        ? 2
        : 3;
    audio.musicIntensity(
      level,
      (0.95 + (speed - 9) / 17 * 0.25).clamp(0.95, 1.2),
    );

    super.update(scaled);
    _publishHud();
    if (sim.isOver && !_gameOverSent) {
      _gameOverSent = true;
      audio.stopMusic();
      onGameOver?.call(sim);
    }
  }

  void _onEvent(SimEvent e) {
    final c = _mixo.center;
    final reduce = look.reduceEffects;
    switch (e.type) {
      case SimEventType.laneChange:
        _mixo.onLaneChange();
        audio.sfx(Sfx.lane);
      case SimEventType.gateOk:
        particles.burst(
          c.dx,
          c.dy,
          e.color.argb,
          count: reduce ? 6 : 16,
          speed: projection.laneWidth * 3,
        );
        audio.sfx(Sfx.gateOk);
      case SimEventType.gateFail:
      case SimEventType.obstacleHit:
        if (!reduce) _shake = 0.35;
        _mixo.onHit();
        particles.burst(
          c.dx,
          c.dy,
          0xFF9E9E9E,
          count: 10,
          speed: projection.laneWidth * 2,
        );
        audio.sfx(Sfx.gateFail);
        haptics.medium();
      case SimEventType.drop:
        particles.burst(
          c.dx,
          c.dy,
          sim.color.argb,
          count: reduce ? 4 : 10,
          speed: projection.laneWidth * 1.5,
        );
        audio.sfx(Sfx.drop);
      case SimEventType.jump:
        audio.sfx(Sfx.jump);
      case SimEventType.jumpOver:
        particles.burst(
          c.dx,
          c.dy + projection.laneWidth * 0.3,
          0xFFFFFFFF,
          count: 6,
        );
      case SimEventType.dive:
        audio.sfx(Sfx.lane);
      case SimEventType.comboTier:
        _effects.popup('${labels.combo} x${e.value}', const Color(0xFFFFD21F));
        audio.sfx(Sfx.combo);
        if (e.value >= 5) {
          if (!reduce) _slowMo = 0.3;
          haptics.heavy();
        }
      case SimEventType.nearMiss:
        _effects.popup(
          '${labels.nearMiss} +${e.value}',
          const Color(0xFF84FFFF),
        );
        audio.sfx(Sfx.nearMiss);
        haptics.light();
      case SimEventType.gameOver:
        audio.sfx(Sfx.gameOver);
        haptics.heavy();
      case SimEventType.finished:
        particles.burst(
          c.dx,
          c.dy,
          0xFFFFD21F,
          count: 40,
          speed: projection.laneWidth * 4,
        );
        audio.sfx(Sfx.record);
    }
  }

  void _publishHud() {
    final g = ghost;
    final next = HudData(
      score: sim.score.score,
      combo: sim.score.combo,
      multiplier: sim.score.multiplier,
      hearts: sim.hearts,
      color: sim.color,
      ghostDelta: g == null ? null : g.score.score - sim.score.score,
      progress: sim.params.finishDistance > 0
          ? (sim.distance / sim.params.finishDistance).clamp(0.0, 1.0)
          : null,
    );
    if (next != hud.value) hud.value = next;
  }

  @override
  void pauseEngine() {
    audio.stopMusic();
    super.pauseEngine();
  }

  @override
  void resumeEngine() {
    if (paused && !sim.isOver) audio.startMusic();
    super.resumeEngine();
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
    audio.stopMusic();
    hud.dispose();
    super.onRemove();
  }
}
