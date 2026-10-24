import 'dart:ui';

import 'package:flame/game.dart';

import 'palette.g.dart';
import 'virtual_screen.dart';

/// Turns the low-resolution frame into the final image on screen.
///
/// The default is a plain nearest-neighbour upscale; the CRT filter (M8) is
/// another implementation that runs a fragment shader on the same frame.
abstract interface class PostProcessor {
  void draw(Canvas canvas, Image frame, LetterboxLayout layout);
}

class NearestUpscaler implements PostProcessor {
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void draw(Canvas canvas, Image frame, LetterboxLayout layout) {
    canvas.drawImageRect(frame, VirtualScreen.rect, layout.dest, _paint);
  }
}

/// Renders the whole component tree into a 384x216 offscreen picture, then
/// hands it to a [PostProcessor] to be scaled onto the real canvas.
///
/// Combine with a camera that uses `FixedSizeViewport(384, 216)` so the world
/// is laid out in virtual pixels.
mixin PixelPerfectRender on FlameGame {
  PostProcessor postProcessor = NearestUpscaler();
  ScaleMode scaleMode = ScaleMode.integer;

  LetterboxLayout get layout => _layout;
  LetterboxLayout _layout = LetterboxLayout.compute(VirtualScreen.size);

  final Paint _border = Paint()
    ..color = Pal.space1
    ..isAntiAlias = false;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout = LetterboxLayout.compute(Size(size.x, size.y), mode: scaleMode);
  }

  @override
  void render(Canvas canvas) {
    final recorder = PictureRecorder();
    final low = Canvas(recorder, VirtualScreen.rect);
    low.clipRect(VirtualScreen.rect, doAntiAlias: false);
    super.render(low);
    final picture = recorder.endRecording();
    final frame = picture.toImageSync(
      VirtualScreen.width,
      VirtualScreen.height,
    );
    picture.dispose();

    canvas.drawColor(Pal.ink0, BlendMode.src);
    // Thin frame around the play area so letterboxing looks intentional.
    // Drawn as a filled rect underneath the frame: no anti-aliased edges.
    if (_layout.dest.left > 2 || _layout.dest.top > 2) {
      canvas.drawRect(_layout.dest.inflate(2), _border);
    }
    postProcessor.draw(canvas, frame, _layout);
    frame.dispose();
  }
}
