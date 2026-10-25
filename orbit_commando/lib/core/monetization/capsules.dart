import 'dart:convert';

import '../../engine/math/det_random.dart';

/// One possible capsule reward.
class CapsuleItem {
  const CapsuleItem({
    required this.id,
    required this.kind,
    this.amount = 1,
    this.upgrade,
    this.weapon,
  });

  factory CapsuleItem.fromJson(Map<String, dynamic> j) => CapsuleItem(
    id: j['id'] as String,
    kind: j['kind'] as String,
    amount: j['amount'] as int? ?? 1,
    upgrade: j['upgrade'] as String?,
    weapon: j['weapon'] as String?,
  );

  final String id;

  /// tokens | credits | gems | fragment | skin | crt | weapon | collectible
  final String kind;
  final int amount;
  final String? upgrade;
  final String? weapon;
}

class Rarity {
  const Rarity(this.id, this.weight, this.items);

  final String id;
  final int weight;
  final List<CapsuleItem> items;
}

/// Drop table loaded from `assets/data/capsules.json`.
///
/// The probability screen and the draw use THIS object, so shown and real
/// odds cannot diverge (brief §8.6).
class DropTable {
  const DropTable({
    required this.version,
    required this.pity,
    required this.rarities,
  });

  factory DropTable.parse(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    return DropTable(
      version: j['version'] as int,
      pity: j['pity'] as int,
      rarities: [
        for (final r in j['rarities'] as List<dynamic>)
          Rarity(
            (r as Map<String, dynamic>)['id'] as String,
            r['weight'] as int,
            [
              for (final i in r['items'] as List<dynamic>)
                CapsuleItem.fromJson(i as Map<String, dynamic>),
            ],
          ),
      ],
    );
  }

  final int version;

  /// A Legendary is guaranteed at most every [pity] opens.
  final int pity;
  final List<Rarity> rarities;

  int get totalWeight => rarities.fold(0, (s, r) => s + r.weight);

  /// Exact probability of a rarity on a normal open (no pity).
  double rarityChance(String id) =>
      rarities.firstWhere((r) => r.id == id).weight / totalWeight;

  /// Exact probability of one item (items are uniform inside a rarity).
  double itemChance(String rarity, String item) {
    final r = rarities.firstWhere((x) => x.id == rarity);
    return rarityChance(rarity) / r.items.length;
  }

  Rarity get legendary => rarities.last;
}

class CapsuleResult {
  const CapsuleResult(
    this.rarity,
    this.item,
    this.pityAfter, {
    this.byPity = false,
  });

  final String rarity;
  final CapsuleItem item;

  /// Opens since the last Legendary, after this one.
  final int pityAfter;
  final bool byPity;
}

/// Pure capsule opening: given the table, a RNG and the pity counter.
class CapsuleEngine {
  const CapsuleEngine(this.table);

  final DropTable table;

  CapsuleResult open(DetRandom rng, int pityCounter) {
    final opens = pityCounter + 1;
    Rarity r;
    var byPity = false;
    if (opens >= table.pity) {
      r = table.legendary;
      byPity = true;
    } else {
      var roll = rng.nextInt(table.totalWeight);
      r = table.rarities.first;
      for (final x in table.rarities) {
        if (roll < x.weight) {
          r = x;
          break;
        }
        roll -= x.weight;
      }
    }
    final item = r.items[rng.nextInt(r.items.length)];
    final legendary = r.id == table.legendary.id;
    return CapsuleResult(r.id, item, legendary ? 0 : opens, byPity: byPity);
  }
}
