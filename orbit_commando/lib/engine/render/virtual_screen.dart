import 'dart:math' as math;
import 'dart:ui';

/// Internal resolution of the game. Everything in the world and the HUD is
/// drawn at this size and then upscaled with nearest-neighbour filtering.
abstract final class VirtualScreen {
  static const int width = 640;
  static const int height = 360;
  static const Size size = Size(640, 360);
  static const Rect rect = Rect.fromLTWH(0, 0, 640, 360);
}

enum ScaleMode {
  /// Largest whole-number multiple that fits: perfectly square pixels.
  integer,

  /// Fill as much of the screen as possible, keeping the aspect ratio.
  fit,
}

/// Where the 640x360 frame lands on the physical screen.
class LetterboxLayout {
  const LetterboxLayout._(this.screen, this.scale, this.dest);

  factory LetterboxLayout.compute(
    Size screen, {
    ScaleMode mode = ScaleMode.integer,
  }) {
    final fit = math.min(
      screen.width / VirtualScreen.width,
      screen.height / VirtualScreen.height,
    );
    // Screens smaller than the virtual resolution can't use integer scaling.
    final scale = (mode == ScaleMode.integer && fit >= 1)
        ? fit.floorToDouble()
        : fit;
    final w = VirtualScreen.width * scale;
    final h = VirtualScreen.height * scale;
    final left = ((screen.width - w) / 2).floorToDouble();
    final top = ((screen.height - h) / 2).floorToDouble();
    return LetterboxLayout._(screen, scale, Rect.fromLTWH(left, top, w, h));
  }

  final Size screen;
  final double scale;
  final Rect dest;

  /// Converts a physical-screen point to virtual-screen coordinates.
  Offset toVirtual(Offset p) =>
      Offset((p.dx - dest.left) / scale, (p.dy - dest.top) / scale);

  /// Converts a virtual-screen point to physical-screen coordinates.
  Offset toScreen(Offset v) =>
      Offset(dest.left + v.dx * scale, dest.top + v.dy * scale);
}
