// Server copy of lib/core/monetization/catalog.dart (what each SKU grants).
const SKUS = {
  full_cartridge: { kind: 'nonConsumable', cents: 499 },
  gems_100: { kind: 'consumable', cents: 99, gems: 100 },
  gems_550: { kind: 'consumable', cents: 499, gems: 550 },
  gems_1200: { kind: 'consumable', cents: 999, gems: 1200 },
  gems_2600: { kind: 'consumable', cents: 1999, gems: 2600 },
  gems_7000: { kind: 'consumable', cents: 4999, gems: 7000 },
  season_pass_s1: { kind: 'nonConsumable', cents: 999 },
  pack_retro_suits: { kind: 'nonConsumable', cents: 299 },
  pack_crt_deluxe: { kind: 'nonConsumable', cents: 199 },
  pack_mixtape_vol1: { kind: 'nonConsumable', cents: 199 },
  starter_pack: { kind: 'nonConsumable', cents: 199, gems: 300 },
};

module.exports = { SKUS };
