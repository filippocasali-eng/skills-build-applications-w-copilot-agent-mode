import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/render/mixo_painter.dart';
import '../../game/systems/color_system.dart';
import '../models/cosmetics.dart';

/// Animated Mixo for menus (bounces and cycles through primaries).
class MixoAvatar extends StatefulWidget {
  const MixoAvatar({
    super.key,
    this.size = 160,
    this.cycleColors = true,
    this.accessory = Accessory.none,
    this.color = GameColor.red,
    this.animate = true,
  });

  final double size;
  final bool cycleColors;
  final Accessory accessory;
  final GameColor color;
  final bool animate;

  @override
  State<MixoAvatar> createState() => _MixoAvatarState();
}

class _MixoAvatarState extends State<MixoAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

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
          painter: MixoAvatarPainter(
            _c.value,
            cycle: widget.cycleColors,
            accessory: widget.accessory,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class MixoAvatarPainter extends CustomPainter {
  MixoAvatarPainter(
    this.t, {
    required this.cycle,
    required this.accessory,
    required this.color,
  });

  final double t;
  final bool cycle;
  final Accessory accessory;
  final GameColor color;
  static final MixoPaints _paints = MixoPaints();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = GameColor.primaries;
    final c0 = cycle ? colors[(t * 3).floor() % 3] : color;
    final bounce = math.sin(t * math.pi * 12).abs();
    final r = size.width * 0.3;
    final c = Offset(size.width / 2, size.height * 0.6 - bounce * r * 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.6 + r * 0.95),
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
      color: Color(c0.argb),
      symbol: c0.symbol,
      squish: (1 - bounce) * 0.5 - 0.2,
      lookX: math.sin(t * math.pi * 2),
      wobble: t * 40,
      accessory: accessory,
    );
  }

  @override
  bool shouldRepaint(MixoAvatarPainter old) =>
      old.t != t ||
      old.accessory != accessory ||
      old.color != color ||
      old.cycle != cycle;
}
