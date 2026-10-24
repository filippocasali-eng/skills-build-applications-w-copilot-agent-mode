import 'package:flutter/material.dart';

import '../../game/render/symbol_painter.dart';
import '../../game/systems/color_system.dart';

/// Round badge with a game colour and its accessibility symbol.
class ColorBadge extends StatelessWidget {
  const ColorBadge({super.key, required this.color, this.size = 44});

  final GameColor color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: color.name,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BadgePainter(color)),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.color);

  final GameColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas
      ..drawCircle(c, r, Paint()..color = Color(color.argb))
      ..drawCircle(
        c,
        r - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    paintSymbol(
      canvas,
      color.symbol,
      c,
      r * 0.5,
      Paint()..color = Colors.white,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.color != color;
}
