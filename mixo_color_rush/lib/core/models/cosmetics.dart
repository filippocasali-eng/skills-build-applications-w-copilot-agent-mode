/// Every cosmetic item. Purely visual: nothing here affects gameplay
/// (no pay-to-win).
enum CosmeticType { skin, trail, theme, badge }

/// How an item is obtained. Everything is visible and deterministic:
/// no random rewards, ever.
enum UnlockKind { start, level, stars, product }

enum Accessory {
  none,
  cap,
  bow,
  glasses,
  headphones,
  crown,
  horns,
  antenna,
  flower,
  halo,
  wizard,
  ninja,
  pirate,
  chef,
  dino,
  stego,
  alien,
  robot,
  cupcake,
  bunny,
  golden,
  astro,
  dragon,
}

enum TrailKind {
  none,
  sparkle,
  bubbles,
  stars,
  hearts,
  rainbow,
  fire,
  notes,
  leaves,
  comet,
  candy,
}

/// Colours of a tunnel theme (ARGB).
class ThemePalette {
  const ThemePalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.floorFar,
    required this.floorNear,
    required this.ringHue,
    required this.ringSpread,
  });

  final int skyTop;
  final int skyMid;
  final int skyBottom;
  final int floorFar;
  final int floorNear;

  /// Base hue of the tunnel rings and how much it varies (degrees).
  final double ringHue;
  final double ringSpread;
}

class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.type,
    required this.unlock,
    this.level = 0,
    this.price = 0,
    this.productId,
    this.accessory = Accessory.none,
    this.trail = TrailKind.none,
    this.palette,
  });

  final String id;
  final CosmeticType type;
  final UnlockKind unlock;

  /// Required level for [UnlockKind.level].
  final int level;

  /// Stars price for [UnlockKind.stars].
  final int price;

  /// Store product for [UnlockKind.product].
  final String? productId;

  final Accessory accessory;
  final TrailKind trail;
  final ThemePalette? palette;
}

abstract final class Products {
  static const supporter = 'mixo_supporter_pack';
  static const dino = 'mixo_pack_dino';
  static const space = 'mixo_pack_space';
  static const sweet = 'mixo_pack_sweet';
  static const all = [supporter, dino, space, sweet];
}

abstract final class Catalog {
  static const _space = ThemePalette(
    skyTop: 0xFF120A33,
    skyMid: 0xFF3B1C7A,
    skyBottom: 0xFF6A2BB0,
    floorFar: 0xFF1A0F40,
    floorNear: 0xFF2E1A66,
    ringHue: 200,
    ringSpread: 160,
  );

  static const List<CosmeticItem> items = [
    // Skins (12 earnable + 3 supporter + 6 packs).
    CosmeticItem(
      id: 'skin_classic',
      type: CosmeticType.skin,
      unlock: UnlockKind.start,
    ),
    CosmeticItem(
      id: 'skin_cap',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 2,
      accessory: Accessory.cap,
    ),
    CosmeticItem(
      id: 'skin_bow',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 3,
      accessory: Accessory.bow,
    ),
    CosmeticItem(
      id: 'skin_glasses',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 4,
      accessory: Accessory.glasses,
    ),
    CosmeticItem(
      id: 'skin_flower',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 6,
      accessory: Accessory.flower,
    ),
    CosmeticItem(
      id: 'skin_crown',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 8,
      accessory: Accessory.crown,
    ),
    CosmeticItem(
      id: 'skin_wizard',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 12,
      accessory: Accessory.wizard,
    ),
    CosmeticItem(
      id: 'skin_ninja',
      type: CosmeticType.skin,
      unlock: UnlockKind.level,
      level: 15,
      accessory: Accessory.ninja,
    ),
    CosmeticItem(
      id: 'skin_headphones',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 150,
      accessory: Accessory.headphones,
    ),
    CosmeticItem(
      id: 'skin_antenna',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 200,
      accessory: Accessory.antenna,
    ),
    CosmeticItem(
      id: 'skin_chef',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 250,
      accessory: Accessory.chef,
    ),
    CosmeticItem(
      id: 'skin_horns',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 300,
      accessory: Accessory.horns,
    ),
    CosmeticItem(
      id: 'skin_pirate',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 400,
      accessory: Accessory.pirate,
    ),
    CosmeticItem(
      id: 'skin_halo',
      type: CosmeticType.skin,
      unlock: UnlockKind.stars,
      price: 500,
      accessory: Accessory.halo,
    ),
    CosmeticItem(
      id: 'skin_golden',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.supporter,
      accessory: Accessory.golden,
    ),
    CosmeticItem(
      id: 'skin_astro',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.supporter,
      accessory: Accessory.astro,
    ),
    CosmeticItem(
      id: 'skin_dragon',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.supporter,
      accessory: Accessory.dragon,
    ),
    CosmeticItem(
      id: 'skin_dino',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.dino,
      accessory: Accessory.dino,
    ),
    CosmeticItem(
      id: 'skin_stego',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.dino,
      accessory: Accessory.stego,
    ),
    CosmeticItem(
      id: 'skin_alien',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.space,
      accessory: Accessory.alien,
    ),
    CosmeticItem(
      id: 'skin_robot',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.space,
      accessory: Accessory.robot,
    ),
    CosmeticItem(
      id: 'skin_cupcake',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.sweet,
      accessory: Accessory.cupcake,
    ),
    CosmeticItem(
      id: 'skin_bunny',
      type: CosmeticType.skin,
      unlock: UnlockKind.product,
      productId: Products.sweet,
      accessory: Accessory.bunny,
    ),

    // Trails (8 earnable + 3 packs).
    CosmeticItem(
      id: 'trail_none',
      type: CosmeticType.trail,
      unlock: UnlockKind.start,
    ),
    CosmeticItem(
      id: 'trail_sparkle',
      type: CosmeticType.trail,
      unlock: UnlockKind.level,
      level: 2,
      trail: TrailKind.sparkle,
    ),
    CosmeticItem(
      id: 'trail_bubbles',
      type: CosmeticType.trail,
      unlock: UnlockKind.level,
      level: 4,
      trail: TrailKind.bubbles,
    ),
    CosmeticItem(
      id: 'trail_hearts',
      type: CosmeticType.trail,
      unlock: UnlockKind.level,
      level: 7,
      trail: TrailKind.hearts,
    ),
    CosmeticItem(
      id: 'trail_fire',
      type: CosmeticType.trail,
      unlock: UnlockKind.level,
      level: 11,
      trail: TrailKind.fire,
    ),
    CosmeticItem(
      id: 'trail_stars',
      type: CosmeticType.trail,
      unlock: UnlockKind.stars,
      price: 100,
      trail: TrailKind.stars,
    ),
    CosmeticItem(
      id: 'trail_notes',
      type: CosmeticType.trail,
      unlock: UnlockKind.stars,
      price: 200,
      trail: TrailKind.notes,
    ),
    CosmeticItem(
      id: 'trail_rainbow',
      type: CosmeticType.trail,
      unlock: UnlockKind.stars,
      price: 400,
      trail: TrailKind.rainbow,
    ),
    CosmeticItem(
      id: 'trail_leaves',
      type: CosmeticType.trail,
      unlock: UnlockKind.product,
      productId: Products.dino,
      trail: TrailKind.leaves,
    ),
    CosmeticItem(
      id: 'trail_comet',
      type: CosmeticType.trail,
      unlock: UnlockKind.product,
      productId: Products.space,
      trail: TrailKind.comet,
    ),
    CosmeticItem(
      id: 'trail_candy',
      type: CosmeticType.trail,
      unlock: UnlockKind.product,
      productId: Products.sweet,
      trail: TrailKind.candy,
    ),

    // Tunnel themes (6 earnable + 1 supporter).
    CosmeticItem(
      id: 'theme_space',
      type: CosmeticType.theme,
      unlock: UnlockKind.start,
      palette: _space,
    ),
    CosmeticItem(
      id: 'theme_ocean',
      type: CosmeticType.theme,
      unlock: UnlockKind.level,
      level: 3,
      palette: ThemePalette(
        skyTop: 0xFF031B3A,
        skyMid: 0xFF0B4F7A,
        skyBottom: 0xFF1C8FB0,
        floorFar: 0xFF04253F,
        floorNear: 0xFF0A3D62,
        ringHue: 185,
        ringSpread: 50,
      ),
    ),
    CosmeticItem(
      id: 'theme_forest',
      type: CosmeticType.theme,
      unlock: UnlockKind.level,
      level: 5,
      palette: ThemePalette(
        skyTop: 0xFF0B2414,
        skyMid: 0xFF1E4D2B,
        skyBottom: 0xFF3E7D3A,
        floorFar: 0xFF102A16,
        floorNear: 0xFF22401F,
        ringHue: 95,
        ringSpread: 60,
      ),
    ),
    CosmeticItem(
      id: 'theme_volcano',
      type: CosmeticType.theme,
      unlock: UnlockKind.level,
      level: 9,
      palette: ThemePalette(
        skyTop: 0xFF1A0505,
        skyMid: 0xFF5A1208,
        skyBottom: 0xFFB0360F,
        floorFar: 0xFF240806,
        floorNear: 0xFF3C0E08,
        ringHue: 15,
        ringSpread: 40,
      ),
    ),
    CosmeticItem(
      id: 'theme_candy',
      type: CosmeticType.theme,
      unlock: UnlockKind.stars,
      price: 200,
      palette: ThemePalette(
        skyTop: 0xFF4A1440,
        skyMid: 0xFFB0407F,
        skyBottom: 0xFFFF8FC2,
        floorFar: 0xFF5A1E4E,
        floorNear: 0xFF7A2A68,
        ringHue: 320,
        ringSpread: 70,
      ),
    ),
    CosmeticItem(
      id: 'theme_neon',
      type: CosmeticType.theme,
      unlock: UnlockKind.stars,
      price: 350,
      palette: ThemePalette(
        skyTop: 0xFF05010F,
        skyMid: 0xFF140A2E,
        skyBottom: 0xFF26104F,
        floorFar: 0xFF07031A,
        floorNear: 0xFF120838,
        ringHue: 290,
        ringSpread: 120,
      ),
    ),
    CosmeticItem(
      id: 'theme_aurora',
      type: CosmeticType.theme,
      unlock: UnlockKind.product,
      productId: Products.supporter,
      palette: ThemePalette(
        skyTop: 0xFF020B1A,
        skyMid: 0xFF0A3A4A,
        skyBottom: 0xFF2E8A6E,
        floorFar: 0xFF051421,
        floorNear: 0xFF0A2533,
        ringHue: 140,
        ringSpread: 140,
      ),
    ),

    // Badges.
    CosmeticItem(
      id: 'badge_supporter',
      type: CosmeticType.badge,
      unlock: UnlockKind.product,
      productId: Products.supporter,
    ),
  ];

  static final Map<String, CosmeticItem> byId = {
    for (final i in items) i.id: i,
  };

  static CosmeticItem get(String id) => byId[id] ?? items.first;

  static Iterable<CosmeticItem> ofType(CosmeticType t) =>
      items.where((i) => i.type == t);

  static Iterable<CosmeticItem> ofProduct(String productId) =>
      items.where((i) => i.productId == productId);

  static const defaultSkin = 'skin_classic';
  static const defaultTrail = 'trail_none';
  static const defaultTheme = 'theme_space';

  static ThemePalette paletteOf(String themeId) =>
      get(themeId).palette ?? _space;
}
