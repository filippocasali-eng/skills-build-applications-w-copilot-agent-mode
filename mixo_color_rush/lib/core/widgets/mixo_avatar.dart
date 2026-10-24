import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/render/mixo_painter.dart';
import '../../game/systems/color_system.dart';

/// Animated Mixo for menus (bounces and cycles through primaries).
class MixoAvatar extends StatefulWidget {
  const MixoAvatar({super.key, this.size = 160, this.cycleColors = true});

  final double size;
  final bool cycleColors;

  @override
  State<MixoAvatar> createState() => _MixoAvatarState();
}

class _MixoAvatarState extends State<MixoAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _MixoAvatarPainter(_c.value, widget.cycleColors),
        ),
      ),
    );
  }
}

class _MixoAvatarPainter extends CustomPainter {
  _MixoAvatarPainter(this.t, this.cycle);

  final double t;
  final bool cycle;
  static final MixoPaints _paints = MixoPaints();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = GameColor.primaries;
    final color = cycle ? colors[(t * 3).floor() % 3] : GameColor.red;
    final bounce = math.sin(t * math.pi * 12).abs();
    final r = size.width * 0.36;
    final c = Offset(size.width / 2, size.height * 0.62 - bounce * r * 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.62 + r * 0.95),
        width: r * (1.8 - bounce * 0.4),
        height: r * 0.3,
      ),
      _paints.shadow,
    );
    paintMixo(
      canvas,
      _paints,
      c,
      r,
      color: Color(color.argb),
      symbol: color.symbol,
      squish: (1 - bounce) * 0.5 - 0.2,
      lookX: math.sin(t * math.pi * 2),
      wobble: t * 40,
    );
  }

  @override
  bool shouldRepaint(_MixoAvatarPainter old) => old.t != t;
}
