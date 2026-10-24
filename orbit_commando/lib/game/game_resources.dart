import 'package:flame/cache.dart';

import '../engine/render/bitmap_font.dart';
import '../engine/render/sprite_atlas.dart';
import 'roster.dart';

/// Every asset a scene needs, loaded once per game instance.
class GameResources {
  GameResources._(this.font, this.atlases);

  static final atlasNames = [
    'planetoid_small',
    'planetoid_medium',
    for (final h in Hero.values) h.atlas,
    for (final e in EnemyKind.values) e.atlas,
  ];

  final BitmapFont font;
  final Map<String, SpriteAtlas> atlases;

  SpriteAtlas atlas(String name) =>
      atlases[name] ?? (throw ArgumentError('Atlas "$name" not loaded'));

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
    for (final name in atlasNames) {
      atlases[name] = await SpriteAtlas.load(
        name,
        images: images,
        assets: assets,
      );
    }
    return GameResources._(font, atlases);
  }
}
