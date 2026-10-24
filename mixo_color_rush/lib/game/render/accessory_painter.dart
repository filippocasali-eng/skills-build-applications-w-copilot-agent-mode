import 'dart:math' as math;
import 'dart:ui';

import '../../core/models/cosmetics.dart';

final Paint _fill = Paint()..isAntiAlias = true;
final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
final Path _p = Path();

void _col(int argb) => _fill.color = Color(argb);

void _tri(Offset a, Offset b, Offset c) {
  _p
    ..reset()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();
}

/// Paints [a] on a Mixo body of size [w]×[h] centred at [c].
/// [behind] is called before the body (wings, ears), otherwise after.
void paintAccessory(
  Canvas canvas,
  Accessory a,
  Offset c,
  double w,
  double h, {
  required bool behind,
}) {
  final top = c.dy - h / 2;
  final r = w / 2;
  _stroke.strokeWidth = r * 0.08;
  switch (a) {
    case Accessory.none:
      return;
    case Accessory.dragon:
      if (!behind) {
        _col(0xFFFFF2C2);
        _tri(
          Offset(c.dx - r * 0.45, top + h * 0.12),
          Offset(c.dx - r * 0.25, top + h * 0.14),
          Offset(c.dx - r * 0.4, top - h * 0.12),
        );
        canvas.drawPath(_p, _fill);
        _tri(
          Offset(c.dx + r * 0.45, top + h * 0.12),
          Offset(c.dx + r * 0.25, top + h * 0.14),
          Offset(c.dx + r * 0.4, top - h * 0.12),
        );
        canvas.drawPath(_p, _fill);
        return;
      }
      _col(0xFF7A3DD6);
      for (final s in const [-1.0, 1.0]) {
        _p
          ..reset()
          ..moveTo(c.dx + s * r * 0.7, c.dy - h * 0.1)
          ..lineTo(c.dx + s * r * 1.6, c.dy - h * 0.55)
          ..lineTo(c.dx + s * r * 1.4, c.dy - h * 0.1)
          ..lineTo(c.dx + s * r * 1.6, c.dy + h * 0.1)
          ..close();
        canvas.drawPath(_p, _fill);
      }
    case Accessory.bunny:
      if (!behind) return;
      for (final s in const [-1.0, 1.0]) {
        final ear = Rect.fromCenter(
          center: Offset(c.dx + s * r * 0.4, top - h * 0.25),
          width: r * 0.42,
          height: h * 0.75,
        );
        _col(0xFFFFFFFF);
        canvas.drawOval(ear, _fill);
        _col(0xFFFFB3D1);
        canvas.drawOval(ear.deflate(r * 0.09), _fill);
      }
    case Accessory.astro:
      if (behind) return;
      _col(0x33BFE8FF);
      canvas.drawCircle(c, r * 1.25, _fill);
      _stroke.color = const Color(0xCCFFFFFF);
      canvas.drawCircle(c, r * 1.25, _stroke);
      _col(0x88FFFFFF);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(-r * 0.6, -r * 0.7),
          width: r * 0.4,
          height: r * 0.2,
        ),
        _fill,
      );
    case Accessory.cap:
      if (behind) return;
      _col(0xFFE53935);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.2),
          width: w * 0.8,
          height: h * 0.45,
        ),
        math.pi,
        math.pi,
        true,
        _fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx, top + h * 0.15, w * 0.55, h * 0.08),
          Radius.circular(h * 0.04),
        ),
        _fill,
      );
    case Accessory.bow:
      if (behind) return;
      final bc = Offset(c.dx + r * 0.45, top + h * 0.06);
      _col(0xFFFF4FA3);
      _tri(
        bc,
        bc.translate(-r * 0.4, -r * 0.25),
        bc.translate(-r * 0.4, r * 0.25),
      );
      canvas.drawPath(_p, _fill);
      _tri(
        bc,
        bc.translate(r * 0.4, -r * 0.25),
        bc.translate(r * 0.4, r * 0.25),
      );
      canvas.drawPath(_p, _fill);
      canvas.drawCircle(bc, r * 0.11, _fill..color = const Color(0xFFD81B60));
    case Accessory.glasses:
      if (behind) return;
      _stroke.color = const Color(0xFF1B1035);
      final ey = c.dy - h * 0.08;
      canvas
        ..drawCircle(Offset(c.dx - w * 0.19, ey), r * 0.3, _stroke)
        ..drawCircle(Offset(c.dx + w * 0.19, ey), r * 0.3, _stroke)
        ..drawLine(
          Offset(c.dx - w * 0.06, ey),
          Offset(c.dx + w * 0.06, ey),
          _stroke,
        );
    case Accessory.headphones:
      if (behind) return;
      _stroke
        ..color = const Color(0xFF263238)
        ..strokeWidth = r * 0.12;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.35),
          width: w * 1.05,
          height: h * 0.8,
        ),
        math.pi,
        math.pi,
        false,
        _stroke,
      );
      _col(0xFF00BCD4);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx - r * 1.0, c.dy - h * 0.05),
              width: r * 0.3,
              height: h * 0.32,
            ),
            Radius.circular(r * 0.12),
          ),
          _fill,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx + r * 1.0, c.dy - h * 0.05),
              width: r * 0.3,
              height: h * 0.32,
            ),
            Radius.circular(r * 0.12),
          ),
          _fill,
        );
    case Accessory.crown:
    case Accessory.golden:
      if (behind) return;
      final cw = w * 0.6;
      final x0 = c.dx - cw / 2;
      final y0 = top + h * 0.06;
      _p
        ..reset()
        ..moveTo(x0, y0)
        ..lineTo(x0, y0 - h * 0.18)
        ..lineTo(x0 + cw * 0.25, y0 - h * 0.08)
        ..lineTo(x0 + cw * 0.5, y0 - h * 0.25)
        ..lineTo(x0 + cw * 0.75, y0 - h * 0.08)
        ..lineTo(x0 + cw, y0 - h * 0.18)
        ..lineTo(x0 + cw, y0)
        ..close();
      _col(a == Accessory.golden ? 0xFFFFC107 : 0xFFFFD21F);
      canvas.drawPath(_p, _fill);
      if (a == Accessory.golden) {
        _col(0xFFE91E63);
        canvas.drawCircle(Offset(c.dx, y0 - h * 0.06), r * 0.08, _fill);
        _col(0xFF2196F3);
        canvas
          ..drawCircle(Offset(x0 + cw * 0.22, y0 - h * 0.04), r * 0.06, _fill)
          ..drawCircle(Offset(x0 + cw * 0.78, y0 - h * 0.04), r * 0.06, _fill);
        _col(0xFFFFFFFF);
        canvas
          ..drawCircle(c.translate(r * 0.8, -h * 0.4), r * 0.07, _fill)
          ..drawCircle(c.translate(-r * 0.9, -h * 0.1), r * 0.05, _fill);
      }
    case Accessory.horns:
      if (behind) return;
      _col(0xFFF5F5F5);
      _tri(
        Offset(c.dx - r * 0.55, top + h * 0.15),
        Offset(c.dx - r * 0.25, top + h * 0.05),
        Offset(c.dx - r * 0.75, top - h * 0.18),
      );
      canvas.drawPath(_p, _fill);
      _tri(
        Offset(c.dx + r * 0.55, top + h * 0.15),
        Offset(c.dx + r * 0.25, top + h * 0.05),
        Offset(c.dx + r * 0.75, top - h * 0.18),
      );
      canvas.drawPath(_p, _fill);
    case Accessory.antenna:
    case Accessory.alien:
      if (behind) return;
      _stroke.color = const Color(0xFF263238);
      final ball = a == Accessory.alien ? 0xFF76FF03 : 0xFFFFD21F;
      for (final s in const [-1.0, 1.0]) {
        final base = Offset(c.dx + s * r * 0.3, top + h * 0.05);
        final tip = Offset(c.dx + s * r * 0.55, top - h * 0.28);
        canvas.drawLine(base, tip, _stroke);
        _col(ball);
        canvas.drawCircle(tip, r * 0.12, _fill);
      }
      if (a == Accessory.alien) {
        _col(0x5576FF03);
        canvas
          ..drawCircle(c.translate(-r * 0.5, h * 0.18), r * 0.09, _fill)
          ..drawCircle(c.translate(r * 0.55, h * 0.12), r * 0.07, _fill);
      }
    case Accessory.flower:
      if (behind) return;
      final fc = Offset(c.dx - r * 0.45, top + h * 0.08);
      _col(0xFFFFFFFF);
      for (var i = 0; i < 5; i++) {
        final ang = i * 2 * math.pi / 5;
        canvas.drawCircle(
          fc.translate(math.cos(ang) * r * 0.15, math.sin(ang) * r * 0.15),
          r * 0.12,
          _fill,
        );
      }
      _col(0xFFFFD21F);
      canvas.drawCircle(fc, r * 0.1, _fill);
    case Accessory.halo:
      if (behind) return;
      _stroke
        ..color = const Color(0xFFFFE57F)
        ..strokeWidth = r * 0.1;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, top - h * 0.12),
          width: w * 0.6,
          height: h * 0.15,
        ),
        _stroke,
      );
    case Accessory.wizard:
      if (behind) return;
      _col(0xFF5E35B1);
      _tri(
        Offset(c.dx - r * 0.55, top + h * 0.12),
        Offset(c.dx + r * 0.55, top + h * 0.12),
        Offset(c.dx + r * 0.15, top - h * 0.55),
      );
      canvas.drawPath(_p, _fill);
      _col(0xFFFFD21F);
      canvas.drawCircle(Offset(c.dx, top - h * 0.12), r * 0.08, _fill);
    case Accessory.ninja:
      if (behind) return;
      _col(0xFF212121);
      final by = c.dy - h * 0.3;
      canvas.drawRect(
        Rect.fromLTWH(c.dx - w * 0.47, by, w * 0.94, h * 0.1),
        _fill,
      );
      _tri(
        Offset(c.dx + w * 0.45, by),
        Offset(c.dx + w * 0.75, by - h * 0.1),
        Offset(c.dx + w * 0.7, by + h * 0.08),
      );
      canvas.drawPath(_p, _fill);
    case Accessory.pirate:
      if (behind) return;
      _col(0xFFD32F2F);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.16),
          width: w * 0.86,
          height: h * 0.36,
        ),
        math.pi,
        math.pi,
        true,
        _fill,
      );
      _col(0xFF212121);
      canvas.drawCircle(
        Offset(c.dx + w * 0.19, c.dy - h * 0.08),
        r * 0.27,
        _fill,
      );
      _stroke.color = const Color(0xFF212121);
      canvas.drawLine(
        Offset(c.dx - w * 0.45, c.dy - h * 0.3),
        Offset(c.dx + w * 0.45, c.dy - h * 0.0),
        _stroke,
      );
    case Accessory.chef:
      if (behind) return;
      _col(0xFFFFFFFF);
      final hy = top - h * 0.05;
      canvas
        ..drawCircle(Offset(c.dx - r * 0.3, hy), r * 0.28, _fill)
        ..drawCircle(Offset(c.dx + r * 0.3, hy), r * 0.28, _fill)
        ..drawCircle(Offset(c.dx, hy - r * 0.2), r * 0.32, _fill)
        ..drawRect(Rect.fromLTWH(c.dx - r * 0.5, hy, r, h * 0.16), _fill);
    case Accessory.dino:
    case Accessory.stego:
      if (behind) return;
      _col(a == Accessory.dino ? 0xFF2E7D32 : 0xFFFF8A1F);
      for (var i = -2; i <= 2; i++) {
        final x = c.dx + i * r * 0.32;
        final y = top + h * 0.06 + (i * i) * h * 0.025;
        final s = a == Accessory.dino ? r * 0.16 : r * 0.22;
        _tri(
          Offset(x - s, y + s * 0.6),
          Offset(x + s, y + s * 0.6),
          Offset(x, y - s * 1.3),
        );
        canvas.drawPath(_p, _fill);
      }
    case Accessory.robot:
      if (behind) return;
      _col(0xFF90A4AE);
      canvas
        ..drawCircle(Offset(c.dx - r * 0.98, c.dy), r * 0.14, _fill)
        ..drawCircle(Offset(c.dx + r * 0.98, c.dy), r * 0.14, _fill)
        ..drawRect(
          Rect.fromCenter(
            center: Offset(c.dx, top - h * 0.05),
            width: r * 0.1,
            height: h * 0.2,
          ),
          _fill,
        );
      _col(0xFFFF1744);
      canvas.drawCircle(Offset(c.dx, top - h * 0.17), r * 0.1, _fill);
    case Accessory.cupcake:
      if (behind) return;
      _col(0xFFFF8FC2);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.2),
          width: w * 0.95,
          height: h * 0.5,
        ),
        math.pi,
        math.pi,
        true,
        _fill,
      );
      const sprinkles = [0xFFFFD21F, 0xFF2BD66B, 0xFF2F7BFF, 0xFFFFFFFF];
      for (var i = 0; i < 6; i++) {
        _col(sprinkles[i % 4]);
        canvas.drawCircle(
          Offset(
            c.dx - r * 0.6 + i * r * 0.24,
            top + h * (0.08 + (i % 2) * 0.06),
          ),
          r * 0.04,
          _fill,
        );
      }
      _col(0xFFD50000);
      canvas.drawCircle(Offset(c.dx, top - h * 0.06), r * 0.13, _fill);
  }
}
