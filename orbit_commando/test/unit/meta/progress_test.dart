import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/meta/workshop.dart';
import 'package:orbit_commando/core/progress/progress.dart';
import 'package:orbit_commando/core/providers.dart';
import 'package:orbit_commando/core/storage/save_store.dart';
import 'package:orbit_commando/features/run/run.dart';
import 'package:orbit_commando/game/sim/balance.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';

LevelResult result({
  int total = 30000,
  String rank = 'A',
  int deaths = 0,
  int cassettes = 0,
}) => LevelResult(
  score: total,
  timeBonus: 0,
  noDeathBonus: 0,
  total: total,
  rank: rank,
  deaths: deaths,
  hostagesFreed: 2,
  hostagesTotal: 2,
  cassettes: cassettes,
  seconds: 100,
  kills: 40,
);

void main() {
  ProviderContainer container() => ProviderContainer(
    overrides: [saveStoreProvider.overrideWithValue(SaveStore.memory())],
  );

  test('campaign unlocks linearly; W1 boss unlocks Arcade, W2 boss Nyx, W3 Doc + Boss Rush', () async {
    final c = container();
    final n = c.read(progressProvider.notifier);
    final order = ['w1_l1', 'w1_l2', 'w1_l3', 'w1_l4', 'w1_l5', 'w2_l1'];
    expect(c.read(progressProvider).unlocked(order, 'w1_l1'), isTrue);
    expect(c.read(progressProvider).unlocked(order, 'w1_l2'), isFalse);
    await n.recordLevel(
      levelId: 'w1_l1',
      result: result(),
      parTime: 200,
      kills: 40,
    );
    expect(c.read(progressProvider).unlocked(order, 'w1_l2'), isTrue);
    var r = await n.recordLevel(
      levelId: 'w1_l5',
      result: result(),
      parTime: 200,
      kills: 1,
    );
    expect(r.unlocks, contains('arcade'));
    expect(c.read(progressProvider).arcadeUnlocked, isTrue);
    r = await n.recordLevel(
      levelId: 'w2_l5',
      result: result(),
      parTime: 200,
      kills: 1,
    );
    expect(r.unlocks, contains('hero:nyx'));
    r = await n.recordLevel(
      levelId: 'w3_l5',
      result: result(),
      parTime: 200,
      kills: 1,
    );
    expect(r.unlocks, containsAll(['bossrush', 'hero:doc']));
    expect(c.read(progressProvider).heroes, containsAll(['nyx', 'doc']));
  });

  test(
    'records keep the best score, best rank and all cassettes found',
    () async {
      final c = container();
      final n = c.read(progressProvider.notifier);
      await n.recordLevel(
        levelId: 'w1_l1',
        result: result(total: 40000, rank: 'S', cassettes: 1),
        parTime: 200,
        kills: 1,
      );
      await n.recordLevel(
        levelId: 'w1_l1',
        result: result(total: 10000, rank: 'C', cassettes: 4),
        parTime: 200,
        kills: 1,
      );
      final rec = c.read(progressProvider).record('w1_l1');
      expect(rec.bestScore, 40000);
      expect(rec.rank, 'S');
      expect(rec.cassettes, 5);
      expect(rec.cassetteCount, 2);
      expect(rec.clears, 2);
    },
  );

  test('credits: +1 per campaign clear, capped at 9; spending one', () async {
    final c = container();
    final n = c.read(progressProvider.notifier);
    final start = c.read(progressProvider).credits;
    await n.recordLevel(
      levelId: 'w1_l1',
      result: result(),
      parTime: 200,
      kills: 1,
    );
    expect(c.read(progressProvider).credits, start + 1);
    for (var i = 0; i < 20; i++) {
      await n.addCredits(1);
    }
    expect(c.read(progressProvider).credits, Progress.maxCredits);
    expect(await n.spendCredit(), isTrue);
    expect(c.read(progressProvider).credits, Progress.maxCredits - 1);
  });

  test('trophies are awarded once', () async {
    final c = container();
    final n = c.read(progressProvider.notifier);
    final r1 = await n.recordLevel(
      levelId: 'w1_l1',
      result: result(rank: 'S'),
      parTime: 200,
      kills: 1,
    );
    expect(
      r1.trophies.map((t) => t.id),
      containsAll(['first_blood', 'rank_s', 'no_death', 'all_hostages']),
    );
    final r2 = await n.recordLevel(
      levelId: 'w1_l1',
      result: result(rank: 'S'),
      parTime: 200,
      kills: 1,
    );
    expect(r2.trophies.map((t) => t.id), isNot(contains('first_blood')));
  });

  test('high scores keep the top 10 per table', () async {
    final c = container();
    final n = c.read(progressProvider.notifier);
    for (var i = 0; i < 15; i++) {
      await n.addHighScore('AA$i', i * 100, 'arcade');
    }
    final list = c.read(progressProvider).scoresFor('arcade');
    expect(list, hasLength(10));
    expect(list.first.score, 1400);
    expect(c.read(progressProvider).isHighScore(450, 'arcade'), isFalse);
    expect(c.read(progressProvider).isHighScore(1500, 'arcade'), isTrue);
  });

  test('workshop: upgrades apply, except in Arcade difficulty', () {
    const p = Progress(upgrades: {'damage': 3, 'hp': 1, 'grenades': 2});
    final normal = Workshop.loadoutFor(
      p,
      difficulty: Difficulty.normal,
      ranked: false,
      balance: const Balance(),
    );
    expect(normal.damageMult, closeTo(1.3, 1e-9));
    expect(normal.extraHp, 1);
    expect(normal.extraGrenades, 2);
    final arcade = Workshop.loadoutFor(
      p,
      difficulty: Difficulty.arcade,
      ranked: true,
      balance: const Balance(),
    );
    expect(arcade.damageMult, 1);
    expect(arcade.extraHp, 0);
    final noPaidRanked = Workshop.loadoutFor(
      p,
      difficulty: Difficulty.normal,
      ranked: true,
      balance: Balance.fromJson({
        ...const Balance().toJson(),
        'ranked_allow_paid_upgrades': false,
      }),
    );
    expect(noPaidRanked.damageMult, 1);
  });

  test('weekly gravity modifiers keep the jump apex reachable', () {
    const b = Balance();
    double apex(Balance x) => x.jumpSpeed * x.jumpSpeed / (2 * x.gravity);
    for (final m in [WeeklyModifier.heavyGravity, WeeklyModifier.lowGravity]) {
      final w = Weekly.balanceFor(m, b);
      expect(apex(w), closeTo(apex(b), apex(b) * 0.01), reason: '$m');
    }
    expect(Weekly.weaponFor(WeeklyModifier.flameOnly), WeaponKind.flame);
  });
}
