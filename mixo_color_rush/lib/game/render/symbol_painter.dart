import 'dart:math' as math;
import 'dart:ui';

import '../systems/color_system.dart';

final Path _path = Path();

/// Draws the colour-blind accessibility [symbol] centred on [c].
/// Uses a shared [Path]: no allocation per call.
void paintSymbol(
  Canvas canvas,
  ColorSymbol symbol,
  Offset c,
  double r,
  Paint fill, [
  Paint? stroke,
]) {
  _path.reset();
  switch (symbol) {
    case ColorSymbol.circle:
      _path.addOval(Rect.fromCircle(center: c, radius: r * 0.8));
    case ColorSymbol.triangle:
      _polygon(c, r, 3, -math.pi / 2);
    case ColorSymbol.square:
      _path.addRect(Rect.fromCircle(center: c, radius: r * 0.72));
    case ColorSymbol.diamond:
      _polygon(c, r, 4, -math.pi / 2);
    case ColorSymbol.star:
      _star(c, r);
    case ColorSymbol.hexagon:
      _polygon(c, r * 0.95, 6, 0);
    case ColorSymbol.cross:
      final t = r * 0.32;
      _path
        ..addRect(Rect.fromCenter(center: c, width: r * 1.8, height: t * 2))
        ..addRect(Rect.fromCenter(center: c, width: t * 2, height: r * 1.8));
  }
  canvas.drawPath(_path, fill);
  if (stroke != null) canvas.drawPath(_path, stroke);
}

void _polygon(Offset c, double r, int n, double start) {
  for (var i = 0; i < n; i++) {
    final a = start + i * 2 * math.pi / n;
    final x = c.dx + r * math.cos(a);
    final y = c.dy + r * math.sin(a);
    i == 0 ? _path.moveTo(x, y) : _path.lineTo(x, y);
  }
  _path.close();
}

void _star(Offset c, double r) {
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final x = c.dx + rr * math.cos(a);
    final y = c.dy + rr * math.sin(a);
    i == 0 ? _path.moveTo(x, y) : _path.lineTo(x, y);
  }
  _path.close();
}
