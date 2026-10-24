import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/color_badge.dart';
import '../../game/ai/adaptive_director.dart';
import '../../game/ai/coach.dart';
import '../../game/systems/color_system.dart';
import '../../l10n/generated/app_localizations.dart';

String mechanicText(AppLocalizations l, Mechanic m) => switch (m) {
  Mechanic.drops => l.mechDrops,
  Mechanic.obstacles => l.mechObstacles,
  Mechanic.mixing => l.mechMixing,
  Mechanic.secondaryGates => l.mechSecondary,
  Mechanic.specials => l.mechSpecials,
  Mechanic.fiveLanes => l.mechFiveLanes,
  Mechanic.jump => l.mechJump,
  Mechanic.dive => l.mechDive,
};

String coachText(AppLocalizations l, CoachTip t) => switch (t.kind) {
  CoachTipKind.mixRecipe => l.tipMix,
  CoachTipKind.brownNeedsWhite => l.tipBrown,
  CoachTipKind.matchSymbol => l.tipSymbol,
  CoachTipKind.dodgeObstacles => l.tipDodge,
  CoachTipKind.jumpObstacles => l.tipJump,
  CoachTipKind.lookAhead => l.tipLookAhead,
  CoachTipKind.tryCombo => l.tipCombo,
  CoachTipKind.greatRun => l.tipGreat,
};

/// "A + B = C" with colour badges (works without reading).
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    super.key,
    required this.a,
    required this.b,
    required this.result,
    this.size = 40,
  });

  final GameColor a;
  final GameColor b;
  final GameColor result;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size * 0.7, fontWeight: FontWeight.w900);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorBadge(color: a, size: size),
        Text(' + ', style: style),
        ColorBadge(color: b, size: size),
        Text(' = ', style: style),
        ColorBadge(color: result, size: size),
      ],
    );
  }
}

/// Small icon explanation of a mechanic.
class MechanicVisual extends StatelessWidget {
  const MechanicVisual({super.key, required this.mechanic});

  final Mechanic mechanic;

  @override
  Widget build(BuildContext context) {
    switch (mechanic) {
      case Mechanic.mixing:
        return const RecipeRow(
          a: GameColor.red,
          b: GameColor.blue,
          result: GameColor.purple,
          size: 48,
        );
      case Mechanic.secondaryGates:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorBadge(color: GameColor.orange, size: 48),
            SizedBox(width: 8),
            ColorBadge(color: GameColor.green, size: 48),
            SizedBox(width: 8),
            ColorBadge(color: GameColor.purple, size: 48),
          ],
        );
      case Mechanic.drops:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, size: 56, color: Color(0xFF2F7BFF)),
            Icon(Icons.arrow_forward_rounded, size: 40),
            ColorBadge(color: GameColor.blue, size: 48),
          ],
        );
      case Mechanic.specials:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, size: 56, color: Colors.white),
            Icon(Icons.auto_awesome_rounded, size: 56, color: MixoColors.sun),
            Icon(Icons.contrast_rounded, size: 56, color: Colors.white),
          ],
        );
      case Mechanic.obstacles:
        return const Icon(
          Icons.block_rounded,
          size: 64,
          color: MixoColors.candy,
        );
      case Mechanic.fiveLanes:
        return const Icon(
          Icons.view_week_rounded,
          size: 64,
          color: MixoColors.sun,
        );
      case Mechanic.jump:
        return const Icon(
          Icons.keyboard_double_arrow_up_rounded,
          size: 64,
          color: MixoColors.mint,
        );
      case Mechanic.dive:
        return const Icon(
          Icons.keyboard_double_arrow_down_rounded,
          size: 64,
          color: MixoColors.mint,
        );
    }
  }
}
