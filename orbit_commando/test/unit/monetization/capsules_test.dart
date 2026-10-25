import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/monetization/capsules.dart';
import 'package:orbit_commando/engine/math/det_random.dart';

void main() {
  final table = DropTable.parse(
    File('assets/data/capsules.json').readAsStringSync(),
  );

  test('odds shown add up to exactly 100%', () {
    final sum = table.rarities.fold(
      0.0,
      (s, r) => s + table.rarityChance(r.id),
    );
    expect(sum, closeTo(1, 1e-12));
    var items = 0.0;
    for (final r in table.rarities) {
      for (final i in r.items) {
        items += table.itemChance(r.id, i.id);
      }
    }
    expect(items, closeTo(1, 1e-12));
    expect(table.rarityChance('legendary'), 0.015);
  });

  test('1,000,000 opens match the published odds and the pity rule', () {
    final engine = CapsuleEngine(table);
    final rng = DetRandom(20261025);
    final counts = <String, int>{};
    var pity = 0, sinceLegendary = 0, maxGap = 0, pityHits = 0;
    const n = 1000000;
    for (var i = 0; i < n; i++) {
      final r = engine.open(rng, pity);
      counts[r.rarity] = (counts[r.rarity] ?? 0) + 1;
      pity = r.pityAfter;
      sinceLegendary++;
      if (r.rarity == 'legendary') {
        if (sinceLegendary > maxGap) maxGap = sinceLegendary;
        sinceLegendary = 0;
      }
      if (r.byPity) pityHits++;
    }
    // Guarantee: never more than 50 opens without a Legendary.
    expect(maxGap, lessThanOrEqualTo(table.pity));
    expect(pityHits, greaterThan(0));
    // Non-legendary rarities follow the table (pity only adds legendaries).
    for (final r in table.rarities.where((r) => r.id != 'legendary')) {
      final expected = table.rarityChance(r.id);
      final observed = counts[r.id]! / n;
      // Pity steals a small share from the others; allow for it.
      expect(observed, closeTo(expected, 0.012), reason: r.id);
    }
    // Effective legendary rate with pity >= the base rate.
    expect(counts['legendary']! / n, greaterThanOrEqualTo(0.015));
    expect(counts['legendary']! / n, lessThan(0.03));
  });

  test('without pity the raw draw matches the table within 0.1%', () {
    final engine = CapsuleEngine(table);
    final rng = DetRandom(7);
    final counts = <String, int>{};
    const n = 1000000;
    for (var i = 0; i < n; i++) {
      final r = engine.open(rng, 0); // pity counter always fresh
      counts[r.rarity] = (counts[r.rarity] ?? 0) + 1;
    }
    for (final r in table.rarities) {
      expect(
        counts[r.id]! / n,
        closeTo(table.rarityChance(r.id), 0.001),
        reason: r.id,
      );
    }
  });

  test('the 50th open after a legendary is always legendary', () {
    final engine = CapsuleEngine(table);
    final r = engine.open(DetRandom(1), table.pity - 1);
    expect(r.rarity, 'legendary');
    expect(r.byPity, isTrue);
    expect(r.pityAfter, 0);
  });
}
