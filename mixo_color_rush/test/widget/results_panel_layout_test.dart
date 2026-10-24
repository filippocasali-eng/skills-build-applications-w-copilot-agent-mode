import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/achievements.dart';
import 'package:mixo_color_rush/core/models/missions.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/core/progression.dart';
import 'package:mixo_color_rush/features/play/play_screen.dart';
import 'package:mixo_color_rush/features/play/results_panel.dart';
import 'package:mixo_color_rush/game/ai/coach.dart';
import 'package:mixo_color_rush/game/systems/color_system.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('AGAIN stays tappable on a small phone with many rewards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280); // 360×640 dp
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final result = RunResult(
      seed: 1,
      mode: GameMode.free,
      score: 12345,
      maxCombo: 40,
      maxMultiplier: 8,
      durationMs: 150000,
      gatesOk: 120,
      gatesFail: 3,
      errorsByType: const [1, 2, 0],
      failsByGateColor: List.filled(7, 0)..[GameColor.purple.index] = 2,
      okByGateColor: List.filled(7, 0),
      failsWhileBrown: 0,
      dropsTaken: 30,
      nearMisses: 5,
      obstaclesJumped: 3,
      mixGatesOk: 20,
      avgReactionMs: 400,
      completed: false,
      heartsLeft: 0,
    );
    final rewards = RunRewards(
      xpGained: 400,
      levelBefore: 4,
      xpBefore: 100,
      levelAfter: 6,
      xpAfter: 50,
      starsGained: 300,
      isRecord: true,
      tip: const CoachTip(
        CoachTipKind.mixRecipe,
        a: GameColor.red,
        b: GameColor.blue,
        result: GameColor.purple,
      ),
      newUnlocks: const [
        'skin_glasses',
        'trail_bubbles',
        'theme_forest',
        'skin_flower',
      ],
      completedMissions: [
        for (var i = 0; i < 3; i++)
          Mission(kind: MissionKind.runs, target: 3, reward: 10, progress: 3),
      ],
      newAchievements: Achievement.values.take(10).toList(),
      ratingDelta: 50,
    );
    var again = 0;
    final c = testContainer();
    await tester.pumpWidget(
      testApp(
        c,
        locale: 'it',
        home: Scaffold(
          body: ResultsPanel(
            outcome: RunOutcome(
              result: result,
              rewards: rewards,
              bestScore: 12345,
            ),
            mode: GameMode.free,
            onAgain: () => again++,
            onHome: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(const Key('again-button')));
    expect(rect.bottom, lessThanOrEqualTo(640));
    await tester.tap(find.byKey(const Key('again-button')));
    expect(again, 1);
  });
}
