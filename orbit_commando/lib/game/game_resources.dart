import 'dart:ui';

import 'package:flame/cache.dart';

import '../engine/render/bitmap_font.dart';
import '../engine/render/sprite_atlas.dart';
import 'roster.dart';

/// Every asset the game needs, loaded once per game instance.
///
/// Atlases are listed explicitly so a missing file fails fast at startup
/// (and in tests) instead of mid-level.
class GameResources {
  GameResources._(this.font, this.atlases, this.images, this._imageCache);

  static final atlasNames = [
    'planetoid_small',
    'planetoid_large',
    'nebula',
    'ringed_planet',
    for (final h in Commando.values) h.atlas,
    for (final e in EnemyKind.values) e.atlas,
    // generated enemies
    'clerk', 'drone', 'turret', 'roller', 'sniper', 'minimech', 'jelly',
    'swarm',
    // world
    'hostage', 'items', 'beacon', 'exit_sign', 'mech', 'bike', 'shuttle',
    // bosses
    'stamper_body', 'stamper_parts', 'washer_body', 'washer_drum',
    'washer_panel', 'emperor_throne', 'emperor_parts',
    // fx + ui
    'explosion', 'fx', 'seg_digits', 'icons', 'touch',
  ];

  static const imageNames = [
    'sprites/bg_asteroids.png',
    'sprites/bg_station.png',
    'sprites/bg_glorbo.png',
  ];

  final BitmapFont font;
  final Map<String, SpriteAtlas> atlases;

  /// Plain images by asset path (backdrops, planetoids).
  final Map<String, Image> images;
  final Images _imageCache;

  SpriteAtlas atlas(String name) =>
      atlases[name] ?? (throw ArgumentError('Atlas "$name" not loaded'));

  Image image(String path) =>
      images[path] ?? (throw ArgumentError('Image "$path" not loaded'));

  /// Terrain textures live in tiles/textures.(png|json).
  late final SpriteAtlas textures;

  static String planetPath(int style, int radius) =>
      'planets/planet_s${style}_r$radius.png';

  /// Loads planetoid images used by a level (cached across levels).
  Future<void> loadPlanets(Iterable<(int, int)> styleRadius) async {
    for (final (style, r) in styleRadius) {
      final path = planetPath(style, r);
      if (images.containsKey(path)) continue;
      images[path] = await _imageCache.load(path);
    }
  }

  static Future<GameResources> load({
    required Images images,
    required AssetsCache assets,
  }) async {
    final font = await BitmapFont.load(
      'orbit5',
      images: images,
      assets: assets,
    );
    final atlases = <String, SpriteAtlas>{};
    await Future.wait([
      for (final name in atlasNames)
        SpriteAtlas.load(
          name,
          images: images,
          assets: assets,
        ).then((a) => atlases[name] = a),
    ]);
    final imgs = <String, Image>{};
    for (final path in imageNames) {
      imgs[path] = await images.load(path);
    }
    final res = GameResources._(font, atlases, imgs, images);
    res.textures = await SpriteAtlas.load(
      'textures',
      images: images,
      assets: assets,
      dir: 'tiles',
    );
    return res;
  }
}
