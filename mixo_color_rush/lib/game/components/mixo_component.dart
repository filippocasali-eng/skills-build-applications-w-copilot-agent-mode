import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../mixo_game.dart';
import '../render/mixo_painter.dart';

/// Renders Mixo from the simulation state, with purely visual smoothing
/// (lane interpolation, squish, jump arc, blinking).
class MixoComponent extends Component with HasGameReference<MixoGame> {
  MixoComponent() : super(priority: 10);

  final MixoPaints _paints = MixoPaints();
  double _visualLane = 1;
  double _squish = 0;
  double _surprised = 0;
  double _wobble = 0;

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
  }

  @override
  void render(Canvas canvas) {
    final sim = game.sim;
    final p = game.projection;
    if (sim.isInvulnerable && !sim.isOver && (sim.tick ~/ 5).isEven) return;

    final r = p.laneWidth * 0.3;
    final x = p.laneX(_visualLane, 1);
    final jump = math.sin(math.pi * sim.jumpPhase) * p.laneWidth * 0.7;
    final groundC = Offset(x, p.groundY - r * 0.9);

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
    final expression = sim.isOver
        ? MixoExpression.dizzy
        : _surprised > 0
        ? MixoExpression.surprised
        : MixoExpression.happy;
    final dive = sim.isDiving ? -0.6 : 0.0;
    paintMixo(
      canvas,
      _paints,
      groundC.translate(0, -jump),
      r,
      color: color,
      symbol: game.showSymbols ? sim.color.symbol : null,
      squish: _squish + dive,
      lookX: (sim.lane - _visualLane).clamp(-1, 1).toDouble(),
      expression: expression,
      wobble: _wobble,
    );
  }
}
