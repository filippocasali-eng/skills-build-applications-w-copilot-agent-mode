import '../l10n/app_localizations.dart';

/// Localised level title for a level id like "w2_l3" (falls back to [fallback],
/// the name stored in the level file).
String levelName(AppLocalizations l, String id, String fallback) =>
    switch (id) {
      'w1_l1' => l.lvlW1L1,
      'w1_l2' => l.lvlW1L2,
      'w1_l3' => l.lvlW1L3,
      'w1_l4' => l.lvlW1L4,
      'w1_l5' => l.lvlW1L5,
      'w2_l1' => l.lvlW2L1,
      'w2_l2' => l.lvlW2L2,
      'w2_l3' => l.lvlW2L3,
      'w2_l4' => l.lvlW2L4,
      'w2_l5' => l.lvlW2L5,
      'w3_l1' => l.lvlW3L1,
      'w3_l2' => l.lvlW3L2,
      'w3_l3' => l.lvlW3L3,
      'w3_l4' => l.lvlW3L4,
      'w3_l5' => l.lvlW3L5,
      _ => fallback,
    };
