import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/achievements.dart';
import 'package:mixo_color_rush/core/models/cosmetics.dart';
import 'package:mixo_color_rush/core/models/missions.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/core/progression.dart';
import 'package:mixo_color_rush/game/systems/color_system.dart';

import '../support/test_data.dart';

RunResult run({
  int score = 1200,
  int ok = 30,
  int ms = 70000,
  GameMode mode = GameMode.free,
  int mult = 2,
}) => RunResult(
  seed: 1,
  mode: mode,
  score: score,
  maxCombo: 12,
  maxMultiplier: mult,
  durationMs: ms,
  gatesOk: ok,
  gatesFail: 3,
  errorsByType: [3, 0, 0],
  failsByGateColor: List.filled(7, 0),
  okByGateColor: List.filled(7, 0)
    ..[GameColor.red.index] = 10
    ..[GameColor.purple.index] = 2,
  failsWhileBrown: 0,
  dropsTaken: 5,
  nearMisses: 1,
  obstaclesJumped: 0,
  mixGatesOk: 2,
  avgReactionMs: 500,
  completed: false,
  heartsLeft: 0,
);

void main() {
  final director = loadDirector();

  test('catalog meets the content targets', () {
    expect(Catalog.ofType(CosmeticType.skin).length, greaterThanOrEqualTo(12));
    expect(
      Catalog.ofType(CosmeticType.trail)
          .where((t) => t.trail.name != 'none')
          .length,
      greaterThanOrEqualTo(8),
    );
    expect(Catalog.ofType(CosmeticType.theme).length, greaterThanOrEqualTo(6));
    expect(Achievement.values.length, greaterThanOrEqualTo(20));
    expect(Catalog.items.map((i) => i.id).toSet().length, Catalog.items.length);
    for (final p in Products.all) {
      expect(Catalog.ofProduct(p), isNotEmpty, reason: p);
    }
  });

  test('a lost run still gives XP; levels unlock items', () {
    final p = Progression.newProfile(1, director);
    final rw = Progression.applyRun(
      p,
      run(score: 0, ok: 0, ms: 5000),
      director,
    );
    expect(rw.xpGained, greaterThan(0));

    var unlockedCap = false;
    for (var i = 0; i < 20 && !unlockedCap; i++) {
      final r = Progression.applyRun(p, run(score: 3000), director);
      unlockedCap =
          r.newUnlocks.contains('skin_cap') || p.unlocked.contains('skin_cap');
    }
    expect(p.level, greaterThanOrEqualTo(2));
    expect(p.unlocked, contains('skin_cap'));
  });

  test('records only from free runs', () {
    final p = Progression.newProfile(2, director);
    expect(Progression.applyRun(p, run(score: 500), director).isRecord, isTrue);
    expect(
      Progression.applyRun(p, run(score: 400), director).isRecord,
      isFalse,
    );
    expect(
      Progression.applyRun(
        p,
        run(score: 900, mode: GameMode.daily),
        director,
      ).isRecord,
      isFalse,
    );
  });

  test('missions renew on completion, never on a timer', () {
    final p = Progression.newProfile(3, director);
    Progression.ensureMissions(p, jumpLevel: 5);
    expect(p.missions, hasLength(3));
    final counter = p.missionCounter;
    var completed = 0;
    for (var i = 0; i < 30; i++) {
      completed += Progression.applyRun(
        p,
        run(score: 4000, ms: 200000, mult: 8),
        director,
      ).completedMissions.length;
    }
    expect(completed, greaterThan(0));
    expect(p.missions, hasLength(3));
    expect(p.missionCounter, greaterThan(counter));
  });

  test('mission factory is deterministic and respects unlocks', () {
    final a = MissionFactory.create(5, level: 3, mixing: false, jump: false);
    final b = MissionFactory.create(5, level: 3, mixing: false, jump: false);
    expect(a.toJson(), b.toJson());
    for (var i = 0; i < 200; i++) {
      final m = MissionFactory.create(i, level: 1, mixing: false, jump: false);
      expect(m.kind, isNot(MissionKind.mixGates));
      expect(m.kind, isNot(MissionKind.jumps));
      if (m.color != null) expect(m.color!.isPrimary, isTrue);
    }
  });

  test('cumulative vs best-in-run missions', () {
    final cumulative = Mission(kind: MissionKind.drops, target: 8, reward: 10);
    cumulative.apply(run());
    expect(cumulative.progress, 5);
    expect(cumulative.apply(run()), isTrue);
    final best = Mission(kind: MissionKind.survive, target: 100, reward: 10);
    best
      ..apply(run(ms: 60000))
      ..apply(run(ms: 30000));
    expect(best.progress, 60);
  });

  test('achievements unlock once and give stars', () {
    final p = Progression.newProfile(4, director);
    final rw = Progression.applyRun(p, run(score: 1500), director);
    expect(
      rw.newAchievements,
      containsAll([
        Achievement.firstRun,
        Achievement.score1k,
        Achievement.firstMix,
      ]),
    );
    final again = Progression.applyRun(p, run(score: 1500), director);
    expect(again.newAchievements, isNot(contains(Achievement.firstRun)));
  });

  test('buying with stars and equipping', () {
    final p = Progression.newProfile(5, director)..stars = 120;
    expect(Progression.buyWithStars(p, 'skin_headphones'), isFalse); // 150
    expect(Progression.buyWithStars(p, 'trail_stars'), isTrue); // 100
    expect(p.stars, 20);
    expect(Progression.equip(p, 'trail_stars'), isTrue);
    expect(p.trail, 'trail_stars');
    expect(Progression.equip(p, 'skin_golden'), isFalse);
    expect(Progression.buyWithStars(p, 'skin_golden'), isFalse); // product only
  });

  test('a product grants exactly its items', () {
    final p = Progression.newProfile(6, director);
    final added = Progression.grantProduct(p, Products.supporter);
    expect(
      added,
      containsAll([
        'skin_golden',
        'skin_astro',
        'skin_dragon',
        'theme_aurora',
        'badge_supporter',
      ]),
    );
    expect(p.owned, contains(Products.supporter));
    expect(
      Progression.grantProduct(p, Products.supporter),
      isEmpty,
    ); // restore is idempotent
  });
}
