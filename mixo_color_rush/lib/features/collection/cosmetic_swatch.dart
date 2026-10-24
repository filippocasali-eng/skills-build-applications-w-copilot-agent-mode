import 'package:flutter/material.dart';

import '../../core/models/cosmetics.dart';
import '../../core/widgets/mixo_avatar.dart';

/// Visual preview of any cosmetic item.
class CosmeticSwatch extends StatelessWidget {
  const CosmeticSwatch({super.key, required this.item});

  final CosmeticItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case CosmeticType.skin:
        return MixoAvatar(
          size: 90,
          accessory: item.accessory,
          cycleColors: false,
          animate: false,
        );
      case CosmeticType.trail:
        return TrailSwatch(kind: item.trail, size: 64);
      case CosmeticType.theme:
        final p = Catalog.paletteOf(item.id);
        return AspectRatio(
          aspectRatio: 0.8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(p.skyTop), Color(p.skyMid), Color(p.skyBottom)],
              ),
            ),
            child: Icon(
              Icons.blur_circular_rounded,
              size: 44,
              color: HSVColor.fromAHSV(1, p.ringHue, 0.7, 1).toColor(),
            ),
          ),
        );
      case CosmeticType.badge:
        return const Icon(
          Icons.workspace_premium_rounded,
          size: 64,
          color: Color(0xFFFFC107),
        );
    }
  }
}

class TrailSwatch extends StatelessWidget {
  const TrailSwatch({super.key, required this.kind, this.size = 64});

  final TrailKind kind;
  final double size;

  static const Map<TrailKind, (IconData, List<Color>)> _look = {
    TrailKind.none: (Icons.block_rounded, [Colors.white38]),
    TrailKind.sparkle: (
      Icons.auto_awesome_rounded,
      [Colors.white, Color(0xFFFFF59D)],
    ),
    TrailKind.bubbles: (Icons.bubble_chart_rounded, [Color(0xFF80D8FF)]),
    TrailKind.stars: (Icons.star_rounded, [Color(0xFFFFD21F)]),
    TrailKind.hearts: (Icons.favorite_rounded, [Color(0xFFFF4FA3)]),
    TrailKind.rainbow: (
      Icons.looks_rounded,
      [Color(0xFFFF3B47), Color(0xFFFFD21F), Color(0xFF2F7BFF)],
    ),
    TrailKind.fire: (
      Icons.local_fire_department_rounded,
      [Color(0xFFFF6D00), Color(0xFFFFC400)],
    ),
    TrailKind.notes: (Icons.music_note_rounded, [Color(0xFFB388FF)]),
    TrailKind.leaves: (Icons.eco_rounded, [Color(0xFF66BB6A)]),
    TrailKind.comet: (Icons.flare_rounded, [Color(0xFF84FFFF)]),
    TrailKind.candy: (
      Icons.cake_rounded,
      [Color(0xFFFF3B47), Color(0xFF2F7BFF)],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = _look[kind]!;
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(
        colors: colors.length == 1 ? [colors[0], colors[0]] : colors,
      ).createShader(r),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
