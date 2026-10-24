import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/game/ai/adaptive_director.dart';

import '../support/test_data.dart';

RunResult fakeRun({required int ok, required int fail, required int ms}) =>
    RunResult(
      seed: 1,
      mode: GameMode.free,
      score: ok * 100,
      maxCombo: ok,
      maxMultiplier: 1,
      durationMs: ms,
      gatesOk: ok,
      gatesFail: fail,
      errorsByType: [fail, 0, 0],
      failsByGateColor: List.filled(7, 0),
      okByGateColor: List.filled(7, 0),
      failsWhileBrown: 0,
      dropsTaken: 0,
      nearMisses: 0,
      obstaclesJumped: 0,
      mixGatesOk: 0,
      avgReactionMs: 600,
      completed: false,
      heartsLeft: 0,
    );

void main() {
  final director = loadDirector();

  test('a winning streak raises the rating and unlocks mechanics', () {
    final skill = director.newSkill();
    final start = skill.rating;
    final introduced = <Mechanic>[];
    for (var i = 0; i < 20; i++) {
      final plan = director.planRun(skill, level: 12);
      if (plan.introducing != null) introduced.add(plan.introducing!);
      director.recordRun(skill, fakeRun(ok: 60, fail: 1, ms: 150000));
    }
    expect(skill.rating, greaterThan(start + 500));
    expect(introduced, containsAll([Mechanic.mixing, Mechanic.specials]));
    final p = director.paramsFor(skill.rating);
    expect(p.maxSpeed, greaterThan(director.paramsFor(start).maxSpeed));
  });

  test('a losing streak lowers the rating', () {
    final skill = director.newSkill()..rating = 500;
    for (var i = 0; i < 5; i++) {
      director.recordRun(skill, fakeRun(ok: 4, fail: 3, ms: 40000));
    }
    expect(skill.rating, lessThan(400));
  });

  test('three quick losses in a row trigger the extra easing', () {
    final a = director.newSkill()..rating = 400;
    final b = director.newSkill()..rating = 400;
    for (var i = 0; i < 3; i++) {
      director.recordRun(a, fakeRun(ok: 5, fail: 3, ms: 20000)); // < 30 s
      director.recordRun(b, fakeRun(ok: 5, fail: 3, ms: 40000));
    }
    expect(a.rating, lessThan(b.rating));
  });

  test('success inside the flow zone keeps the rating nearly stable', () {
    final skill = director.newSkill()..rating = 400;
    for (var i = 0; i < 5; i++) {
      director.recordRun(skill, fakeRun(ok: 78, fail: 22, ms: 60000));
    }
    expect((skill.rating - 400).abs(), lessThan(60));
  });

  test('recent runs are capped at 10', () {
    final skill = director.newSkill();
    for (var i = 0; i < 15; i++) {
      director.recordRun(skill, fakeRun(ok: 10, fail: 2, ms: 50000));
    }
    expect(skill.recentRuns.length, 10);
  });

  test('params interpolate monotonically in speed', () {
    var last = 0.0;
    for (var r = 0; r <= 1000; r += 50) {
      final p = director.paramsFor(r.toDouble());
      expect(p.maxSpeed, greaterThanOrEqualTo(last));
      last = p.maxSpeed;
    }
    expect(director.paramsFor(900).laneCount, 5);
    expect(director.paramsFor(0).laneCount, 3);
  });

  test('jump and dive follow the player level', () {
    expect(director.paramsFor(300, level: 4).jumpEnabled, isFalse);
    expect(director.paramsFor(300, level: 5).jumpEnabled, isTrue);
    expect(director.paramsFor(300, level: 10).diveEnabled, isTrue);
  });

  test('skill state round-trips through JSON', () {
    final skill = director.newSkill();
    director.planRun(skill);
    director.recordRun(skill, fakeRun(ok: 10, fail: 2, ms: 50000));
    final again = SkillState.fromJson(skill.toJson());
    expect(again.rating, skill.rating);
    expect(again.recentRuns.length, 1);
    expect(again.seenMechanics, skill.seenMechanics);
  });
}
