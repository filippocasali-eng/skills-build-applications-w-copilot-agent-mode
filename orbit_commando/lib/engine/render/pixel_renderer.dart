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
    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      layout.dest,
      _paint,
    );
  }
}

/// CRT look through `assets/shaders/crt.frag`.
class CrtPostProcessor implements PostProcessor {
  CrtPostProcessor(this.program, this.params);

  final FragmentProgram program;
  final CrtParams params;
  late final FragmentShader _shader = program.fragmentShader();
  final Paint _paint = Paint();
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void draw(Canvas canvas, Image frame, LetterboxLayout layout) {
    final d = layout.dest;
    final p = params;
    _shader
      ..setFloat(0, d.width)
      ..setFloat(1, d.height)
      ..setFloat(2, frame.width.toDouble())
      ..setFloat(3, frame.height.toDouble())
      ..setFloat(4, _clock.elapsedMilliseconds / 1000)
      ..setFloat(5, p.scan)
      ..setFloat(6, p.curve)
      ..setFloat(7, p.chroma)
      ..setFloat(8, p.bloom)
      ..setFloat(9, p.noise)
      ..setFloat(10, p.roll)
      ..setFloat(11, d.left)
      ..setFloat(12, d.top)
      ..setImageSampler(0, frame);
    _paint.shader = _shader;
    canvas.drawRect(d, _paint);
  }
}

class CrtParams {
  const CrtParams({
    this.scan = 0.45,
    this.curve = 0.12,
    this.chroma = 0.6,
    this.bloom = 0.25,
    this.noise = 0.015,
    this.roll = 0,
  });

  final double scan, curve, chroma, bloom, noise, roll;

  static const arcade = CrtParams();
  static const tv = CrtParams(
    scan: 0.3,
    curve: 0.22,
    chroma: 1.2,
    bloom: 0.4,
    noise: 0.03,
  );
  static const broken = CrtParams(
    scan: 0.5,
    curve: 0.3,
    chroma: 3,
    bloom: 0.5,
    noise: 0.08,
    roll: 1,
  );
}

/// Renders the whole component tree into a 640x360 offscreen picture, then
/// hands it to a [PostProcessor] to be scaled onto the real canvas.
///
/// Combine with a camera that uses `FixedSizeViewport(640, 360)` so the world
/// is laid out in virtual pixels.
mixin PixelPerfectRender on FlameGame {
  PostProcessor postProcessor = NearestUpscaler();
  ScaleMode scaleMode = ScaleMode.integer;

  /// Secret-code "giant pixels": halve the resolution before upscaling.
  bool chunkyPixels = false;
  final Paint _down = Paint()..filterQuality = FilterQuality.none;

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
    var frame = picture.toImageSync(VirtualScreen.width, VirtualScreen.height);
    picture.dispose();
    if (chunkyPixels) {
      const w = VirtualScreen.width ~/ 2, h = VirtualScreen.height ~/ 2;
      final rec = PictureRecorder();
      Canvas(rec).drawImageRect(
        frame,
        VirtualScreen.rect,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        _down,
      );
      final pic = rec.endRecording();
      frame.dispose();
      frame = pic.toImageSync(w, h);
      pic.dispose();
    }

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
