import 'dart:math' as math;
import 'dart:ui';

import '../systems/color_system.dart';
import 'symbol_painter.dart';

enum MixoExpression { happy, surprised, dizzy }

/// Reusable paints for drawing Mixo (no per-frame allocation).
class MixoPaints {
  final Paint body = Paint()..isAntiAlias = true;
  final Paint outline = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0x55000000);
  final Paint highlight = Paint()..color = const Color(0x66FFFFFF);
  final Paint white = Paint()..color = const Color(0xFFFFFFFF);
  final Paint pupil = Paint()..color = const Color(0xFF1B1035);
  final Paint mouth = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF1B1035);
  final Paint symbol = Paint()..color = const Color(0xE6FFFFFF);
  final Paint symbolStroke = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0x66000000);
  final Paint shadow = Paint()..color = const Color(0x44000000);
}

final Path _mouth = Path();

/// Draws Mixo, a jelly blob, centred at [c] with radius [r].
///
/// [squish] > 0 stretches horizontally (lane change), < 0 vertically.
void paintMixo(
  Canvas canvas,
  MixoPaints p,
  Offset c,
  double r, {
  required Color color,
  ColorSymbol? symbol,
  double squish = 0,
  double lookX = 0,
  MixoExpression expression = MixoExpression.happy,
  double wobble = 0,
}) {
  final sx = 1 + squish * 0.28 + math.sin(wobble) * 0.03;
  final sy = 1 - squish * 0.22 - math.sin(wobble) * 0.03;
  final w = r * 2 * sx;
  final h = r * 1.85 * sy;
  final rect = Rect.fromCenter(center: c, width: w, height: h);

  p.body.color = color;
  p.outline.strokeWidth = r * 0.08;
  final rr = RRect.fromRectAndCorners(
    rect,
    topLeft: Radius.elliptical(w / 2, h * 0.62),
    topRight: Radius.elliptical(w / 2, h * 0.62),
    bottomLeft: Radius.elliptical(w * 0.32, h * 0.32),
    bottomRight: Radius.elliptical(w * 0.32, h * 0.32),
  );
  canvas
    ..drawRRect(rr, p.body)
    ..drawRRect(rr, p.outline)
    ..drawOval(
      Rect.fromCenter(
        center: c.translate(-w * 0.22, -h * 0.26),
        width: w * 0.26,
        height: h * 0.16,
      ),
      p.highlight,
    );

  // Eyes.
  final eyeY = c.dy - h * 0.08;
  final eyeDx = w * 0.19;
  final eyeR = r * 0.24;
  for (final side in const [-1.0, 1.0]) {
    final ec = Offset(c.dx + side * eyeDx, eyeY);
    if (expression == MixoExpression.dizzy) {
      p.mouth.strokeWidth = r * 0.09;
      final d = eyeR * 0.6;
      canvas
        ..drawLine(ec.translate(-d, -d), ec.translate(d, d), p.mouth)
        ..drawLine(ec.translate(-d, d), ec.translate(d, -d), p.mouth);
      continue;
    }
    final er = expression == MixoExpression.surprised ? eyeR * 1.2 : eyeR;
    canvas
      ..drawCircle(ec, er, p.white)
      ..drawCircle(ec.translate(lookX * er * 0.4, er * 0.1), er * 0.55, p.pupil)
      ..drawCircle(ec.translate(-er * 0.2, -er * 0.3), er * 0.18, p.white);
  }

  // Mouth.
  p.mouth.strokeWidth = r * 0.08;
  final my = c.dy + h * 0.16;
  _mouth.reset();
  switch (expression) {
    case MixoExpression.happy:
      _mouth
        ..moveTo(c.dx - r * 0.22, my)
        ..quadraticBezierTo(c.dx, my + r * 0.22, c.dx + r * 0.22, my);
      canvas.drawPath(_mouth, p.mouth);
    case MixoExpression.surprised:
      canvas.drawCircle(Offset(c.dx, my + r * 0.05), r * 0.1, p.pupil);
    case MixoExpression.dizzy:
      _mouth
        ..moveTo(c.dx - r * 0.2, my + r * 0.06)
        ..quadraticBezierTo(c.dx - r * 0.1, my - r * 0.04, c.dx, my + r * 0.06)
        ..quadraticBezierTo(c.dx + r * 0.1, my + r * 0.16, c.dx + r * 0.2, my);
      canvas.drawPath(_mouth, p.mouth);
  }

  if (symbol != null) {
    p.symbolStroke.strokeWidth = r * 0.04;
    paintSymbol(
      canvas,
      symbol,
      Offset(c.dx, c.dy + h * 0.36),
      r * 0.16,
      p.symbol,
      p.symbolStroke,
    );
  }
}
