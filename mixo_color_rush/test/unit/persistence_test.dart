import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/profile.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/core/progression.dart';
import 'package:mixo_color_rush/core/services/key_value_store.dart';
import 'package:mixo_color_rush/core/services/profile_repository.dart';
import 'package:mixo_color_rush/core/services/wellbeing.dart';
import 'package:mixo_color_rush/game/sim/game_simulation.dart';
import 'package:mixo_color_rush/game/sim/replay.dart';

import '../support/test_data.dart';

void main() {
  final director = loadDirector();
  final lib = loadLibrary();

  test('profile round-trips through storage (survives restart)', () async {
    final store = MemoryStore();
    final repo = ProfileRepository(store, director);
    final p = repo.load(seed: 9);
    final sim = GameSimulation(
      library: lib,
      seed: 3,
      params: director.paramsFor(100),
    );
    for (var i = 0; i < 60 * 40; i++) {
      if (i % 50 == 0) sim.input(InputAction.left);
      sim.step();
    }
    final r = RunResult.fromSim(sim, GameMode.free);
    Progression.applyRun(p, r, director);
    p
      ..ghostReplay = r.replay
      ..ghostScore = r.score
      ..academyStars[0] = 3
      ..settings.music = false
      ..parent.dailyLimitMinutes = 45;
    Progression.grantProduct(p, 'mixo_pack_dino');
    await repo.save(p);

    final again = ProfileRepository(store, director).load();
    expect(jsonEncode(again.toJson()), jsonEncode(p.toJson()));
    expect(again.skill.recentRuns, hasLength(1));
    expect(again.ghostReplay!.inputs.length, r.replay!.inputs.length);
    // The stored ghost replays to the same score.
    expect(
      GameSimulation.fromReplay(again.ghostReplay!, lib).score.score,
      r.score,
    );
  });

  test('v0 documents migrate to the current schema', () {
    final store = MemoryStore()
      ..data[ProfileRepository.key] = jsonEncode({
        'bestScore': 777,
        'stars': 12,
      });
    final p = ProfileRepository(store, director).load();
    expect(p.stats.bestScore, 777);
    expect(p.stars, 12);
    expect(p.toJson()['schemaVersion'], PlayerProfile.schemaVersion);
  });

  test('a corrupted main document falls back to the backup', () async {
    final store = MemoryStore();
    final repo = ProfileRepository(store, director);
    final p = repo.load(seed: 1)..stars = 5;
    await repo.save(p);
    p.stars = 6;
    await repo.save(p); // backup now holds stars = 5
    store.data[ProfileRepository.key] = '{broken';
    expect(ProfileRepository(store, director).load().stars, 5);
  });

  test('daily limit and extension', () {
    final p = Progression.newProfile(1, director)
      ..parent.dailyLimitMinutes = 30;
    final now = DateTime(2026, 10, 24, 18);
    expect(Wellbeing.limitReached(p, now), isFalse);
    Wellbeing.addPlay(p, 29 * 60000, now);
    expect(Wellbeing.limitReached(p, now), isFalse);
    Wellbeing.addPlay(p, 60000, now);
    expect(Wellbeing.limitReached(p, now), isTrue);
    p.limitExtensionMinutes = 15;
    expect(Wellbeing.limitReached(p, now), isFalse);
    // A new day resets everything.
    expect(Wellbeing.limitReached(p, DateTime(2026, 10, 25, 9)), isFalse);
    Wellbeing.addPlay(p, 1000, DateTime(2026, 10, 25, 9));
    expect(p.playMsToday, 1000);
    expect(p.limitExtensionMinutes, 0);
  });

  test('wellbeing break after 30 continuous minutes, reset after a gap', () {
    var now = DateTime(2026, 1, 1, 10);
    final t = SessionTracker(clock: () => now);
    for (var i = 0; i < 29; i++) {
      now = now.add(const Duration(minutes: 1));
      t.addPlay(60000);
    }
    expect(t.needsBreak, isFalse);
    now = now.add(const Duration(minutes: 1));
    t.addPlay(60000);
    expect(t.needsBreak, isTrue);
    t.tookBreak();
    expect(t.needsBreak, isFalse);

    for (var i = 0; i < 20; i++) {
      now = now.add(const Duration(minutes: 1));
      t.addPlay(60000);
    }
    now = now.add(const Duration(minutes: 20)); // long pause
    t.addPlay(60000);
    expect(t.continuousMs, 60000);
  });
}
