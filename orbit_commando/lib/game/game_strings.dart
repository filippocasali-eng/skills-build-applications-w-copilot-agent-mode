/// Localised strings the in-game (bitmap-font) UI needs. Filled from the
/// Flutter l10n layer so the game code stays free of BuildContext.
class GameStrings {
  const GameStrings({
    required this.title,
    required this.pressStart,
    required this.credits,
    required this.sandbox,
  });

  final String title;
  final String pressStart;
  final String credits;
  final String sandbox;
}
