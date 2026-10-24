import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

/// One animation inside an atlas.
class AtlasAnimation {
  const AtlasAnimation({
    required this.frames,
    required this.fps,
    required this.loop,
  });

  final List<int> frames;
  final double fps;
  final bool loop;
}

/// Parsed `<name>.json` produced by tools/pixel_art (see ART_PIPELINE.md).
class AtlasData {
  const AtlasData({
    required this.image,
    required this.origin,
    required this.frames,
    required this.animations,
  });

  factory AtlasData.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (version != 1) {
      throw FormatException('Unsupported atlas version $version');
    }
    final origin = json['origin'] as Map<String, dynamic>;
    final frames = [
      for (final f in json['frames'] as List<dynamic>)
        Rect.fromLTWH(
          ((f as Map<String, dynamic>)['x'] as num).toDouble(),
          (f['y'] as num).toDouble(),
          (f['w'] as num).toDouble(),
          (f['h'] as num).toDouble(),
        ),
    ];
    final anims = <String, AtlasAnimation>{};
    (json['animations'] as Map<String, dynamic>).forEach((name, value) {
      final a = value as Map<String, dynamic>;
      final idx = [for (final i in a['frames'] as List<dynamic>) i as int];
      for (final i in idx) {
        if (i < 0 || i >= frames.length) {
          throw FormatException('Animation "$name" references frame $i');
        }
      }
      anims[name] = AtlasAnimation(
        frames: idx,
        fps: (a['fps'] as num).toDouble(),
        loop: a['loop'] as bool? ?? true,
      );
    });
    return AtlasData(
      image: json['image'] as String,
      origin: Offset(
        (origin['x'] as num).toDouble(),
        (origin['y'] as num).toDouble(),
      ),
      frames: frames,
      animations: anims,
    );
  }

  final String image;

  /// Anchor in frame pixels (feet for characters, centre for round things).
  final Offset origin;
  final List<Rect> frames;
  final Map<String, AtlasAnimation> animations;
}

/// An atlas with its image loaded, able to build Flame sprites/animations.
class SpriteAtlas {
  SpriteAtlas(this.data, this.image);

  final AtlasData data;
  final Image image;

  /// Loads `sprites/<name>.png` + `sprites/<name>.json`.
  static Future<SpriteAtlas> load(
    String name, {
    required Images images,
    required AssetsCache assets,
  }) async {
    final json = jsonDecode(
      await assets.readFile('sprites/$name.json'),
    ) as Map<String, dynamic>;
    final data = AtlasData.fromJson(json);
    final image = await images.load('sprites/${data.image}');
    return SpriteAtlas(data, image);
  }

  Vector2 get frameSize =>
      Vector2(data.frames.first.width, data.frames.first.height);

  /// Origin as a Flame [Anchor] (relative to frame size).
  Anchor get anchor => Anchor(
    data.origin.dx / data.frames.first.width,
    data.origin.dy / data.frames.first.height,
  );

  Sprite sprite(int frame) {
    final r = data.frames[frame];
    return Sprite(
      image,
      srcPosition: Vector2(r.left, r.top),
      srcSize: Vector2(r.width, r.height),
    );
  }

  SpriteAnimation animation(String name) {
    final a = data.animations[name];
    if (a == null) throw ArgumentError('No animation "$name" in ${data.image}');
    return SpriteAnimation.spriteList(
      [for (final f in a.frames) sprite(f)],
      stepTime: 1 / a.fps,
      loop: a.loop,
    );
  }
}

/// Makes a sprite component draw hard-edged pixels even when rotated:
/// no anti-aliasing on the quad edges, nearest-neighbour sampling.
T makeCrisp<T extends HasPaint>(T component) {
  component.paint
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  return component;
}
