import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';

enum PixelTextAlign { left, center, right }

class Glyph {
  const Glyph(this.x, this.y, this.width);

  final int x;
  final int y;
  final int width;
}

/// Parsed font metadata (`fonts/<name>.json`), independent of the image.
class BitmapFontData {
  const BitmapFontData({
    required this.image,
    required this.lineHeight,
    required this.baseline,
    required this.spacing,
    required this.glyphs,
  });

  factory BitmapFontData.fromJson(Map<String, dynamic> json) {
    final glyphs = <int, Glyph>{};
    (json['glyphs'] as Map<String, dynamic>).forEach((ch, value) {
      final g = value as Map<String, dynamic>;
      glyphs[ch.runes.single] = Glyph(
        g['x'] as int,
        g['y'] as int,
        g['w'] as int,
      );
    });
    return BitmapFontData(
      image: json['image'] as String,
      lineHeight: json['lineHeight'] as int,
      baseline: json['baseline'] as int,
      spacing: json['spacing'] as int,
      glyphs: glyphs,
    );
  }

  final String image;
  final int lineHeight;
  final int baseline;
  final int spacing;
  final Map<int, Glyph> glyphs;

  /// Fallback for unknown characters.
  Glyph get missing => glyphs['?'.runes.single]!;

  /// The font only has capitals; text is upper-cased before lookup.
  Glyph glyphFor(int rune) => glyphs[rune] ?? missing;

  bool supports(String text) =>
      text.toUpperCase().runes.every((r) => r == 10 || glyphs.containsKey(r));

  /// Width in virtual pixels of a single line.
  int measure(String text) {
    var w = 0;
    var n = 0;
    for (final r in text.toUpperCase().runes) {
      w += glyphFor(r).width;
      n++;
    }
    return n == 0 ? 0 : w + (n - 1) * spacing;
  }
}

/// Pixel font drawn from a white glyph sheet, tinted at draw time.
class BitmapFont {
  BitmapFont(this.data, this.image);

  final BitmapFontData data;
  final Image image;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;
  Color? _tint;

  static Future<BitmapFont> load(
    String name, {
    required Images images,
    required AssetsCache assets,
  }) async {
    final json = jsonDecode(
      await assets.readFile('fonts/$name.json'),
    ) as Map<String, dynamic>;
    final data = BitmapFontData.fromJson(json);
    final image = await images.load('fonts/${data.image}');
    return BitmapFont(data, image);
  }

  int measure(String text) => data.measure(text);

  /// Draws [text] with its top-left (or top-centre/right) at [x],[y].
  /// Coordinates are snapped to whole pixels.
  void draw(
    Canvas canvas,
    String text,
    double x,
    double y, {
    required Color color,
    PixelTextAlign align = PixelTextAlign.left,
    Color? shadow,
  }) {
    if (shadow != null) {
      draw(canvas, text, x + 1, y + 1, color: shadow, align: align);
    }
    if (_tint != color) {
      _tint = color;
      _paint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    }
    final w = measure(text);
    var cx = switch (align) {
      PixelTextAlign.left => x,
      PixelTextAlign.center => x - w / 2,
      PixelTextAlign.right => x - w,
    }.roundToDouble();
    final cy = y.roundToDouble();
    final h = data.lineHeight.toDouble();
    for (final r in text.toUpperCase().runes) {
      final g = data.glyphFor(r);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(g.x.toDouble(), g.y.toDouble(), g.width.toDouble(), h),
        Rect.fromLTWH(cx, cy, g.width.toDouble(), h),
        _paint,
      );
      cx += g.width + data.spacing;
    }
  }
}
