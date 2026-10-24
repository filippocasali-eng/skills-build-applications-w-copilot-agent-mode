import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/game/systems/score_system.dart';

void main() {
  test('combo tiers map to x1 x2 x3 x5 x8', () {
    expect(ScoreSystem.tierFor(0), 0);
    expect(ScoreSystem.tierFor(4), 0);
    expect(ScoreSystem.tierFor(5), 1);
    expect(ScoreSystem.tierFor(12), 2);
    expect(ScoreSystem.tierFor(22), 3);
    expect(ScoreSystem.tierFor(35), 4);
    expect(ScoreSystem.tierFor(500), 4);
  });

  test('gates multiply by the current tier and report tier ups', () {
    final s = ScoreSystem();
    var tierUps = 0;
    for (var i = 0; i < 5; i++) {
      if (s.gatePassed()) tierUps++;
    }
    // 4 gates at x1, the 5th already at x2.
    expect(s.score, 4 * 100 + 200);
    expect(tierUps, 1);
    expect(s.multiplier, 2);
  });

  test('breaking the combo keeps max combo', () {
    final s = ScoreSystem();
    for (var i = 0; i < 7; i++) {
      s.gatePassed();
    }
    s.breakCombo();
    expect(s.combo, 0);
    expect(s.maxCombo, 7);
    expect(s.multiplier, 1);
  });
}
