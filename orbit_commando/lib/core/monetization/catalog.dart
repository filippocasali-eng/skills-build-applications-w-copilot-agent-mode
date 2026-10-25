/// Store catalogue. Real prices come from Google Play (localised); these
/// euro prices are the defaults shown by the TEST store and used for the
/// spending limit when the store doesn't report a price.
enum SkuKind { nonConsumable, consumable, subscriptionLike }

class Sku {
  const Sku(
    this.id,
    this.cents,
    this.kind, {
    this.gems = 0,
    this.titleIt = '',
    this.titleEn = '',
  });

  final String id;
  final int cents;
  final SkuKind kind;

  /// Gems granted (gem packs and bundles).
  final int gems;
  final String titleIt, titleEn;

  String title(String lang) => lang == 'it' ? titleIt : titleEn;
}

class Catalog {
  static const fullCartridge = 'full_cartridge';
  static const seasonPass = 'season_pass_s1';
  static const starterPack = 'starter_pack';

  static const skus = <Sku>[
    Sku(
      fullCartridge,
      499,
      SkuKind.nonConsumable,
      titleIt: 'Cartuccia Completa',
      titleEn: 'Full Cartridge',
    ),
    Sku(
      'gems_100',
      99,
      SkuKind.consumable,
      gems: 100,
      titleIt: '100 Gemme',
      titleEn: '100 Gems',
    ),
    Sku(
      'gems_550',
      499,
      SkuKind.consumable,
      gems: 550,
      titleIt: '550 Gemme',
      titleEn: '550 Gems',
    ),
    Sku(
      'gems_1200',
      999,
      SkuKind.consumable,
      gems: 1200,
      titleIt: '1200 Gemme',
      titleEn: '1200 Gems',
    ),
    Sku(
      'gems_2600',
      1999,
      SkuKind.consumable,
      gems: 2600,
      titleIt: '2600 Gemme',
      titleEn: '2600 Gems',
    ),
    Sku(
      'gems_7000',
      4999,
      SkuKind.consumable,
      gems: 7000,
      titleIt: '7000 Gemme',
      titleEn: '7000 Gems',
    ),
    Sku(
      seasonPass,
      999,
      SkuKind.nonConsumable,
      titleIt: 'Season Pass S1',
      titleEn: 'Season Pass S1',
    ),
    Sku(
      'pack_retro_suits',
      299,
      SkuKind.nonConsumable,
      titleIt: 'Pacchetto Tute Retro',
      titleEn: 'Retro Suits Pack',
    ),
    Sku(
      'pack_crt_deluxe',
      199,
      SkuKind.nonConsumable,
      titleIt: 'Filtri CRT Deluxe',
      titleEn: 'CRT Deluxe Filters',
    ),
    Sku(
      'pack_mixtape_vol1',
      199,
      SkuKind.nonConsumable,
      titleIt: 'Mixtape Vol. 1',
      titleEn: 'Mixtape Vol. 1',
    ),
    Sku(
      starterPack,
      199,
      SkuKind.nonConsumable,
      gems: 300,
      titleIt: 'Pacchetto Iniziale',
      titleEn: 'Starter Pack',
    ),
  ];

  static Sku byId(String id) => skus.firstWhere((s) => s.id == id);

  /// What each cosmetic pack contains (shown BEFORE purchase).
  static const packContents = <String, List<String>>{
    'pack_retro_suits': [
      'skin_tracksuit',
      'skin_fannypack',
      'skin_suit_red',
      'skin_suit_teal',
    ],
    'pack_crt_deluxe': ['crt_green', 'crt_amber'],
    'pack_mixtape_vol1': ['track_bonus1', 'track_bonus2'],
    starterPack: ['gems_300', 'capsule_x3', 'skin_walkman_lite'],
  };

  static String euro(int cents) {
    final e = cents ~/ 100, c = (cents % 100).toString().padLeft(2, '0');
    return '€$e,$c';
  }
}
