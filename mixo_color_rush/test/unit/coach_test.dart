import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/game/ai/coach.dart';
import 'package:mixo_color_rush/game/systems/color_system.dart';

RunResult run({
  List<int> errors = const [0, 0, 0],
  List<int>? failsByColor,
  int brown = 0,
  int ms = 60000,
  int mult = 1,
}) => RunResult(
  seed: 1,
  mode: GameMode.free,
  score: 0,
  maxCombo: 0,
  maxMultiplier: mult,
  durationMs: ms,
  gatesOk: 10,
  gatesFail: errors[0] + errors[1],
  errorsByType: errors,
  failsByGateColor: failsByColor ?? List.filled(7, 0),
  okByGateColor: List.filled(7, 0),
  failsWhileBrown: brown,
  dropsTaken: 0,
  nearMisses: 0,
  obstaclesJumped: 0,
  mixGatesOk: 0,
  avgReactionMs: 0,
  completed: false,
  heartsLeft: 0,
);

void main() {
  test('mix errors on purple give the red + blue recipe', () {
    final fails = List.filled(7, 0)..[GameColor.purple.index] = 3;
    final tip = Coach.tipFor(run(errors: [0, 3, 0], failsByColor: fails));
    expect(tip.kind, CoachTipKind.mixRecipe);
    expect({tip.a, tip.b}, {GameColor.red, GameColor.blue});
    expect(tip.result, GameColor.purple);
  });

  test('brown failures suggest the white drop', () {
    final tip = Coach.tipFor(run(errors: [0, 3, 0], brown: 3));
    expect(tip.kind, CoachTipKind.brownNeedsWhite);
  });

  test('obstacles: dodge or jump depending on unlocks', () {
    expect(
      Coach.tipFor(run(errors: [0, 0, 3])).kind,
      CoachTipKind.dodgeObstacles,
    );
    expect(
      Coach.tipFor(run(errors: [0, 0, 3]), jumpEnabled: true).kind,
      CoachTipKind.jumpObstacles,
    );
  });

  test('wrong colours: short run → look ahead, long → match symbol', () {
    expect(
      Coach.tipFor(run(errors: [3, 0, 0], ms: 10000)).kind,
      CoachTipKind.lookAhead,
    );
    expect(Coach.tipFor(run(errors: [3, 0, 0])).kind, CoachTipKind.matchSymbol);
  });

  test('no errors: suggest combo, or praise', () {
    expect(Coach.tipFor(run()).kind, CoachTipKind.tryCombo);
    expect(Coach.tipFor(run(mult: 8)).kind, CoachTipKind.greatRun);
  });
}
