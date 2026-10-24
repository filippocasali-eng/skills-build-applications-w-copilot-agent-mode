import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../../core/models/cosmetics.dart';
import '../mixo_game.dart';
import '../render/mixo_painter.dart';
import 'particles_component.dart';

/// Renders Mixo from the simulation state, with purely visual smoothing
/// (lane interpolation, squish, jump arc, blinking) and his trail.
class MixoComponent extends Component with HasGameReference<MixoGame> {
  MixoComponent() : super(priority: 10);

  final MixoPaints _paints = MixoPaints();
  double _visualLane = 1;
  double _squish = 0;
  double _surprised = 0;
  double _wobble = 0;
  double _trailClock = 0;
  int _trailIndex = 0;

  /// Screen position of Mixo's centre (effects spawn here).
  Offset center = Offset.zero;

  void reset() {
    _visualLane = game.sim.lane.toDouble();
    _squish = 0;
    _surprised = 0;
  }

  void onLaneChange() => _squish = 1;
  void onHit() => _surprised = 0.6;

  @override
  void update(double dt) {
    final target = game.sim.lane.toDouble();
    _visualLane += (target - _visualLane) * (1 - math.exp(-dt * 22));
    _squish *= math.exp(-dt * 9);
    _surprised = math.max(0, _surprised - dt);
    _wobble += dt * (4 + game.sim.speed * 0.2);
    _emitTrail(dt);
  }

  void _emitTrail(double dt) {
    final kind = game.look.trail;
    if (kind == TrailKind.none || game.sim.isOver) return;
    _trailClock += dt;
    final interval = game.look.reduceEffects ? 0.09 : 0.035;
    if (_trailClock < interval) return;
    _trailClock = 0;
    _trailIndex++;
    final r = game.projection.laneWidth * 0.3;
    final x = center.dx;
    final y = center.dy + r * 0.8;
    final particles = game.particles;
    const primaries = [0xFFFF3B47, 0xFFFFD21F, 0xFF2F7BFF];
    switch (kind) {
      case TrailKind.none:
        break;
      case TrailKind.sparkle:
        particles.emit(
          x,
          y,
          _trailIndex.isEven ? 0xFFFFFFFF : 0xFFFFF59D,
          size: r * 0.1,
          shape: ParticlesComponent.diamond,
        );
      case TrailKind.bubbles:
        particles.emit(
          x,
          y,
          0xFF80D8FF,
          size: r * 0.14,
          vy: 120,
          life: 0.6,
          shape: ParticlesComponent.ring,
        );
      case TrailKind.stars:
        particles.emit(
          x,
          y,
          0xFFFFD21F,
          size: r * 0.14,
          shape: ParticlesComponent.diamond,
        );
      case TrailKind.hearts:
        particles.emit(
          x,
          y,
          0xFFFF4FA3,
          size: r * 0.15,
          shape: ParticlesComponent.diamond,
        );
      case TrailKind.rainbow:
        final c = HSVColor.fromAHSV(
          1,
          (_trailIndex * 30) % 360,
          0.8,
          1,
        ).toColor();
        particles.emit(x, y, c.toARGB32(), size: r * 0.16);
      case TrailKind.fire:
        particles.emit(
          x,
          y,
          _trailIndex.isEven ? 0xFFFF6D00 : 0xFFFFC400,
          size: r * 0.18,
          vy: 60,
          life: 0.35,
        );
      case TrailKind.notes:
        particles.emit(
          x,
          y,
          0xFFB388FF,
          size: r * 0.14,
          shape: ParticlesComponent.ring,
        );
      case TrailKind.leaves:
        particles.emit(
          x,
          y,
          _trailIndex.isEven ? 0xFF66BB6A : 0xFF9CCC65,
          size: r * 0.14,
          shape: ParticlesComponent.diamond,
        );
      case TrailKind.comet:
        particles.emit(x, y, 0xFF84FFFF, size: r * 0.2, life: 0.3, vy: 300);
      case TrailKind.candy:
        particles.emit(x, y, primaries[_trailIndex % 3], size: r * 0.12);
    }
  }

  @override
  void render(Canvas canvas) {
    final sim = game.sim;
    final p = game.projection;
    final r = p.laneWidth * 0.3;
    final x = p.laneX(_visualLane, 1);
    final jump = math.sin(math.pi * sim.jumpPhase) * p.laneWidth * 0.7;
    final groundC = Offset(x, p.groundY - r * 0.9);
    center = groundC.translate(0, -jump);
    if (sim.isInvulnerable && !sim.isOver && (sim.tick ~/ 5).isEven) return;

    // Shadow shrinks while jumping.
    final shadowW = r * 1.8 * (1 - sim.jumpPhase * 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, p.groundY),
        width: shadowW,
        height: r * 0.4,
      ),
      _paints.shadow,
    );

    final color = sim.isRainbow
        ? HSVColor.fromAHSV(1, (game.time * 400) % 360, 0.8, 1).toColor()
        : Color(sim.color.argb);
    final expression = sim.isOver && !sim.isCompleted
        ? MixoExpression.dizzy
        : _surprised > 0
        ? MixoExpression.surprised
        : MixoExpression.happy;
    final dive = sim.isDiving ? -0.6 : 0.0;
    paintMixo(
      canvas,
      _paints,
      center,
      r,
      color: color,
      symbol: game.look.symbols ? sim.color.symbol : null,
      squish: _squish + dive,
      lookX: (sim.lane - _visualLane).clamp(-1, 1).toDouble(),
      expression: expression,
      wobble: _wobble,
      accessory: game.look.accessory,
    );
  }
}
