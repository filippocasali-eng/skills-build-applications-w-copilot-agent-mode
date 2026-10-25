import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/ui/atlas_sprite.dart';
import '../../app/ui/pixel.dart';
import '../../engine/render/palette.g.dart';

/// The postcard players send to friends: score, rank, combo and the
/// challenge code, in the game's 16-bit style. 16:9 so it previews well in
/// chats and stories.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.levelName,
    required this.score,
    required this.rank,
    required this.maxCombo,
    required this.code,
    required this.hero,
    required this.tagline,
    this.comboLabel = 'MAX COMBO',
  });

  final String levelName;
  final int score;
  final String rank;
  final int maxCombo;
  final String code;
  final String hero;
  final String tagline;
  final String comboLabel;

  static const size = Size(480, 270);

  /// Renders the card in [key]'s RepaintBoundary to PNG bytes.
  static Future<Uint8List?> capture(GlobalKey key, {double ratio = 2.5}) async {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    final img = await ro.toImage(pixelRatio: ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    // Laid out in card pixels, independent of the device's UI scale.
    final s = 1 / kPx;
    final rankColor = switch (rank) {
      'S' => Pal.gold7,
      'A' => Pal.ember6,
      'B' => Pal.aqua6,
      _ => Pal.ink6,
    };
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Pal.space1, Pal.ink1, Pal.space1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Pal.gold6, width: 3),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _Stars()),
            Positioned(
              left: 14,
              top: 10,
              child: PixelText(
                "ORBIT COMMANDO '94",
                scale: 2.2 * s,
                color: Pal.gold7,
                shadow: Pal.ember2,
              ),
            ),
            Positioned(
              left: 16,
              top: 44,
              child: PixelText(levelName, scale: 1.1 * s, color: Pal.aqua6),
            ),
            Positioned(
              left: 16,
              top: 74,
              child: PixelText('$score', scale: 4.2 * s, color: Pal.ink7),
            ),
            Positioned(
              left: 16,
              top: 140,
              child: PixelText(
                '$comboLabel x$maxCombo',
                scale: 1.2 * s,
                color: Pal.ember6,
              ),
            ),
            Positioned(
              right: 22,
              top: 46,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: rankColor, width: 4),
                  ),
                  child: PixelText(rank, scale: 6 * s, color: rankColor),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 52,
              child: AtlasSprite(hero, anim: 'idle', scale: 1.4),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Pal.ink0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PixelText(
                        tagline,
                        scale: 1.2 * s,
                        color: Pal.gold6,
                      ),
                    ),
                    PixelText(code, scale: 1.5 * s, color: Pal.neon6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fixed starfield (same every time: the card is a keepsake).
class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    var seed = 1994;
    int next() => seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    for (var i = 0; i < 70; i++) {
      final x = (next() % size.width.toInt()).toDouble();
      final y = (next() % size.height.toInt()).toDouble();
      final big = next() % 7 == 0;
      p.color = big ? Pal.ink7 : Pal.ink5;
      canvas.drawRect(Rect.fromLTWH(x, y, big ? 2 : 1, big ? 2 : 1), p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
