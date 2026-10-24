/// Shapes drawn on every colored element for colour-blind accessibility.
enum ColorSymbol { circle, triangle, square, diamond, star, hexagon, cross }

/// Every colour Mixo, gates and drops can have.
enum GameColor {
  red(0xFFFF3B47, ColorSymbol.circle),
  yellow(0xFFFFD21F, ColorSymbol.triangle),
  blue(0xFF2F7BFF, ColorSymbol.square),
  orange(0xFFFF8A1F, ColorSymbol.diamond),
  green(0xFF2BD66B, ColorSymbol.star),
  purple(0xFFB04DFF, ColorSymbol.hexagon),
  brown(0xFF8A5A3B, ColorSymbol.cross);

  const GameColor(this.argb, this.symbol);

  final int argb;
  final ColorSymbol symbol;

  bool get isPrimary => this == red || this == yellow || this == blue;
  bool get isSecondary => this == orange || this == green || this == purple;

  /// Primary components as a bitmask (red=1, yellow=2, blue=4).
  int get components => switch (this) {
    red => 1,
    yellow => 2,
    blue => 4,
    orange => 3,
    purple => 5,
    green => 6,
    brown => 7,
  };

  static const primaries = [red, yellow, blue];
  static const secondaries = [orange, green, purple];
}

/// Pure colour rules. See GAME_DESIGN.md §Colori.
abstract final class ColorSystem {
  static GameColor _fromComponents(int mask) => switch (mask) {
    1 => GameColor.red,
    2 => GameColor.yellow,
    4 => GameColor.blue,
    3 => GameColor.orange,
    5 => GameColor.purple,
    6 => GameColor.green,
    _ => GameColor.brown,
  };

  /// Result of Mixo (colour [current]) absorbing a drop of colour [drop].
  ///
  /// With [mixing] disabled (beginner mode) the drop simply replaces the
  /// colour. With mixing:
  /// - same colour → unchanged;
  /// - two different primaries → the secondary;
  /// - secondary + one of its own primaries → unchanged;
  /// - anything that ends up with all three primaries → brown ("mud");
  /// - brown stays brown (only a white drop resets it).
  static GameColor mix(
    GameColor current,
    GameColor drop, {
    bool mixing = true,
  }) {
    if (!mixing) return drop;
    if (current == GameColor.brown) return GameColor.brown;
    return _fromComponents(current.components | drop.components);
  }

  /// Complementary colour (Invert drop).
  static GameColor complement(GameColor c) => switch (c) {
    GameColor.red => GameColor.green,
    GameColor.green => GameColor.red,
    GameColor.yellow => GameColor.purple,
    GameColor.purple => GameColor.yellow,
    GameColor.blue => GameColor.orange,
    GameColor.orange => GameColor.blue,
    GameColor.brown => GameColor.brown,
  };
}
