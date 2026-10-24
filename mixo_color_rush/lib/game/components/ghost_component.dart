import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../mixo_game.dart';
import '../render/mixo_painter.dart';

/// Semi-transparent Mixo replaying the best run on the same track.
class GhostComponent extends Component with HasGameReference<MixoGame> {
  GhostComponent() : super(priority: 9);

  final MixoPaints _paints = MixoPaints();
  final Paint _layer = Paint()..color = const Color(0x73000000);
  double _visualLane = 1;

  @override
  void update(double dt) {
    final g = game.ghost;
    if (g == null) return;
    _visualLane += (g.lane - _visualLane) * (1 - math.exp(-dt * 22));
  }

  @override
  void render(Canvas canvas) {
    final g = game.ghost;
    if (g == null) return;
    final p = game.projection;
    final z = g.distance - game.sim.distance;
    if (z < -4 || z > 60) return;
    final s = p.scale(z);
    final r = p.laneWidth * 0.3 * s;
    final c = Offset(p.laneX(_visualLane, s), p.floorY(z) - r * 0.9);
    canvas.saveLayer(null, _layer);
    paintMixo(
      canvas,
      _paints,
      c,
      r,
      color: const Color(0xFFE0E0FF),
      expression: g.isOver ? MixoExpression.dizzy : MixoExpression.happy,
    );
    canvas.restore();
  }
}
