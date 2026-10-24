import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../mixo_game.dart';
import '../render/symbol_painter.dart';
import '../sim/game_simulation.dart';
import '../sim/track.dart';
import '../systems/color_system.dart';

/// Draws the tunnel and every track row (gates, drops, obstacles).
/// Rows closer than [splitZ] are drawn by [TrackComponent.near] on top of
/// Mixo so that gates pass "over" him.
class TrackComponent extends Component with HasGameReference<MixoGame> {
  TrackComponent({required this.near}) : super(priority: near ? 20 : 0);

  static const double splitZ = 0.4;
  static const double ringSpacing = 6;

  final bool near;

  final Paint _sky = Paint();
  final Paint _floor = Paint();
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _laneLine = Paint()..strokeWidth = 2;
  final Paint _gateStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _gateFill = Paint();
  final Paint _dropFill = Paint();
  final Paint _symbolFill = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _symbolStroke = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0x99000000);
  final Paint _obstacle = Paint();
  final Paint _obstacleTop = Paint();
  final Paint _shine = Paint()..color = const Color(0x55FFFFFF);
  final Path _arch = Path();
  final Path _floorPath = Path();
  Size _cached = Size.zero;

  Object? _cachedPalette;

  void _cacheShaders() {
    final p = game.projection;
    final pal = game.look.palette;
    _sky.shader = Gradient.linear(
      Offset.zero,
      Offset(0, p.height),
      [Color(pal.skyTop), Color(pal.skyMid), Color(pal.skyBottom)],
      const [0, 0.35, 1],
    );
    _floor.shader = Gradient.linear(
      Offset(0, p.horizonY),
      Offset(0, p.height),
      [Color(pal.floorFar), Color(pal.floorNear)],
    );
    _cached = Size(p.width, p.height);
    _cachedPalette = pal;
  }

  @override
  void render(Canvas canvas) {
    final p = game.projection;
    final sim = game.sim;
    if (_cached.width != p.width ||
        _cached.height != p.height ||
        !identical(_cachedPalette, game.look.palette)) {
      _cacheShaders();
    }
    if (!near) _renderTunnel(canvas, sim);

    // Rows sorted by d ascending: draw far to near.
    final rows = sim.rows;
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final z = row.d - sim.distance;
      if (z > GameSimulation.viewDistance || z < -6) continue;
      if (near != (z < splitZ)) continue;
      _renderRow(canvas, row, z);
    }
  }

  void _renderTunnel(Canvas canvas, GameSimulation sim) {
    final p = game.projection;
    canvas.drawRect(Rect.fromLTWH(0, 0, p.width, p.height), _sky);

    final halfFar =
        p.laneWidth * p.lanes / 2 * p.scale(GameSimulation.viewDistance);
    final halfNear = p.laneWidth * p.lanes / 2 * p.scale(-4) * 1.02;
    _floorPath
      ..reset()
      ..moveTo(p.centerX - halfFar, p.floorY(GameSimulation.viewDistance))
      ..lineTo(p.centerX + halfFar, p.floorY(GameSimulation.viewDistance))
      ..lineTo(p.centerX + halfNear, p.floorY(-4))
      ..lineTo(p.centerX - halfNear, p.floorY(-4))
      ..close();
    canvas.drawPath(_floorPath, _floor);

    // Rings scrolling towards the player.
    final pal = game.look.palette;
    final first = (sim.distance / ringSpacing).floor() * ringSpacing;
    for (
      var d = first + GameSimulation.viewDistance;
      d >= first;
      d -= ringSpacing
    ) {
      final z = d - sim.distance;
      if (z < -3) continue;
      final s = p.scale(z);
      final half = (p.laneWidth * p.lanes / 2 + p.laneWidth * 0.25) * s;
      final floor = p.floorY(z);
      final top = p.horizonY - (p.horizonY + p.height * 0.15) * s;
      final a = (1 - z / GameSimulation.viewDistance).clamp(0.0, 1.0);
      _ring
        ..strokeWidth = math.max(1, 5 * s)
        ..color = HSVColor.fromAHSV(
          a * 0.8,
          (pal.ringHue + math.sin(d * 0.05) * pal.ringSpread / 2 + 360) % 360,
          0.7,
          1,
        ).toColor();
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          p.centerX - half,
          top,
          p.centerX + half,
          floor,
          topLeft: Radius.circular(half * 0.9),
          topRight: Radius.circular(half * 0.9),
        ),
        _ring,
      );
    }

    // Lane separators.
    _laneLine.color = const Color(0x55FFFFFF);
    final sFar = p.scale(GameSimulation.viewDistance);
    final sNear = p.scale(-4);
    for (var l = 0; l <= p.lanes; l++) {
      final lane = l - 0.5;
      canvas.drawLine(
        Offset(p.laneX(lane, sFar), p.floorY(GameSimulation.viewDistance)),
        Offset(p.laneX(lane, sNear), p.floorY(-4)),
        _laneLine,
      );
    }
  }

  void _renderRow(Canvas canvas, TrackRow row, double z) {
    final p = game.projection;
    final s = p.scale(z);
    final floor = p.floorY(z);
    final lw = p.laneWidth * s;
    const far = GameSimulation.viewDistance;
    final alpha =
        ((far - z) / 18).clamp(0.0, 1.0) *
        (z < 0 ? (1 + z / 6).clamp(0.0, 1.0) : 1.0);
    if (alpha <= 0) return;
    for (var l = 0; l < p.lanes; l++) {
      final cell = row.cells[l];
      final x = p.laneX(l.toDouble(), s);
      switch (cell.type) {
        case CellType.empty:
          break;
        case CellType.gate:
          _renderGate(canvas, x, floor, lw, cell.color, alpha);
        case CellType.drop:
          if (row.resolved && row.hitLane == l) continue;
          _renderDrop(canvas, x, floor, lw, cell, alpha, z);
        case CellType.obstacle:
          _renderObstacle(canvas, x, floor, lw, cell.low, alpha);
      }
    }
  }

  void _renderGate(
    Canvas canvas,
    double x,
    double floor,
    double lw,
    GameColor color,
    double alpha,
  ) {
    final w = lw * 0.84;
    final h = lw * 1.2;
    final base = Color(color.argb);
    _arch
      ..reset()
      ..moveTo(x - w / 2, floor)
      ..lineTo(x - w / 2, floor - h + w / 2)
      ..arcToPoint(
        Offset(x + w / 2, floor - h + w / 2),
        radius: Radius.circular(w / 2),
      )
      ..lineTo(x + w / 2, floor);
    _gateFill.color = base.withValues(alpha: 0.28 * alpha);
    canvas.drawPath(_arch, _gateFill);
    _gateStroke
      ..strokeWidth = lw * 0.11
      ..color = base.withValues(alpha: alpha);
    canvas.drawPath(_arch, _gateStroke);
    _symbolFill.color = Color.fromRGBO(255, 255, 255, alpha);
    _symbolStroke
      ..strokeWidth = lw * 0.025
      ..color = Color.fromRGBO(0, 0, 0, 0.6 * alpha);
    paintSymbol(
      canvas,
      color.symbol,
      Offset(x, floor - h * 0.55),
      lw * 0.17,
      _symbolFill,
      _symbolStroke,
    );
  }

  void _renderDrop(
    Canvas canvas,
    double x,
    double floor,
    double lw,
    Cell cell,
    double alpha,
    double z,
  ) {
    final r = lw * 0.2;
    final bob = math.sin(game.time * 5 + z) * r * 0.25;
    final c = Offset(x, floor - lw * 0.42 + bob);
    _arch
      ..reset()
      ..moveTo(c.dx, c.dy - r * 1.9)
      ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * 0.6, c.dx + r, c.dy)
      ..arcToPoint(Offset(c.dx - r, c.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(c.dx - r * 1.1, c.dy - r * 0.6, c.dx, c.dy - r * 1.9);
    switch (cell.dropKind) {
      case DropKind.color:
        _dropFill.color = Color(cell.color.argb).withValues(alpha: alpha);
        canvas.drawPath(_arch, _dropFill);
        _symbolFill.color = Color.fromRGBO(255, 255, 255, alpha);
        _symbolStroke.strokeWidth = lw * 0.02;
        paintSymbol(
          canvas,
          cell.color.symbol,
          c.translate(0, r * 0.1),
          r * 0.5,
          _symbolFill,
          _symbolStroke,
        );
      case DropKind.white:
        _dropFill.color = Color.fromRGBO(255, 255, 255, alpha);
        canvas.drawPath(_arch, _dropFill);
        _ring
          ..strokeWidth = r * 0.18
          ..color = Color.fromRGBO(120, 120, 160, alpha);
        canvas.drawCircle(c.translate(0, r * 0.1), r * 0.42, _ring);
      case DropKind.rainbow:
        canvas.save();
        canvas.clipPath(_arch);
        for (var i = 0; i < 6; i++) {
          final col = GameColor.values[(i + (game.time * 6).floor()) % 6];
          _dropFill.color = Color(col.argb).withValues(alpha: alpha);
          canvas.drawRect(
            Rect.fromLTWH(
              c.dx - r * 1.2,
              c.dy - r * 2 + i * r * 0.55,
              r * 2.4,
              r * 0.56,
            ),
            _dropFill,
          );
        }
        canvas.restore();
      case DropKind.invert:
        canvas.save();
        canvas.clipPath(_arch);
        _dropFill.color = Color.fromRGBO(20, 20, 30, alpha);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - r * 1.2, c.dy - r * 2, r * 1.2, r * 3.2),
          _dropFill,
        );
        _dropFill.color = Color.fromRGBO(255, 255, 255, alpha);
        canvas.drawRect(
          Rect.fromLTWH(c.dx, c.dy - r * 2, r * 1.2, r * 3.2),
          _dropFill,
        );
        canvas.restore();
        _ring
          ..strokeWidth = r * 0.12
          ..color = Color.fromRGBO(255, 210, 31, alpha);
        canvas.drawPath(_arch, _ring);
    }
    canvas.drawCircle(c.translate(-r * 0.35, -r * 0.45), r * 0.22, _shine);
  }

  void _renderObstacle(
    Canvas canvas,
    double x,
    double floor,
    double lw,
    bool low,
    double alpha,
  ) {
    final w = lw * 0.78;
    final h = low ? lw * 0.32 : lw * 0.85;
    _obstacle.color = Color.fromRGBO(40, 30, 70, alpha);
    _obstacleTop.color = Color.fromRGBO(255, 90, 120, alpha);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - w / 2, floor - h, w, h),
      Radius.circular(lw * 0.08),
    );
    canvas.drawRRect(r, _obstacle);
    // Warning stripes on top.
    final stripeH = math.min(h * 0.3, lw * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w / 2, floor - h, w, stripeH),
        Radius.circular(lw * 0.08),
      ),
      _obstacleTop,
    );
  }
}
