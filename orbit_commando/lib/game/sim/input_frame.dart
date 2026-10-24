/// One tick of player input, in the player's LOCAL frame (up = away from the
/// current gravity). The input layer converts screen directions to local
/// ones, so the simulation never depends on camera settings.
///
/// Packs into a small int for replays and ghosts.
class InputFrame {
  const InputFrame({
    this.dx = 0,
    this.dy = 0,
    this.jump = false,
    this.fire = false,
    this.grenade = false,
    this.dash = false,
  });

  factory InputFrame.unpack(int v) => InputFrame(
    dx: (v & 3) - 1,
    dy: ((v >> 2) & 3) - 1,
    jump: v & 16 != 0,
    fire: v & 32 != 0,
    grenade: v & 64 != 0,
    dash: v & 128 != 0,
  );

  static const none = InputFrame();

  /// -1 left, 0, +1 right (local).
  final int dx;

  /// -1 down, 0, +1 up (local).
  final int dy;
  final bool jump;
  final bool fire;
  final bool grenade;
  final bool dash;

  int pack() =>
      (dx + 1) |
      (dy + 1) << 2 |
      (jump ? 16 : 0) |
      (fire ? 32 : 0) |
      (grenade ? 64 : 0) |
      (dash ? 128 : 0);

  @override
  bool operator ==(Object other) =>
      other is InputFrame && other.pack() == pack();

  @override
  int get hashCode => pack();

  @override
  String toString() =>
      'Input(dx:$dx dy:$dy${jump ? ' J' : ''}${fire ? ' F' : ''}'
      '${grenade ? ' G' : ''}${dash ? ' D' : ''})';
}
