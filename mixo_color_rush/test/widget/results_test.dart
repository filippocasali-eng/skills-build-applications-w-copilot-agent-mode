import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/models/run_result.dart';
import 'package:mixo_color_rush/core/profile_controller.dart';
import 'package:mixo_color_rush/features/play/play_screen.dart';
import 'package:mixo_color_rush/game/mixo_game.dart';

import '../support/test_app.dart';

/// Full flow: start a run, play with automatic (bad) inputs until game
/// over, check the results screen and restart with one tap.
void main() {
  testWidgets('play → game over → results → AGAIN restarts', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = testContainer();
    c.read(profileProvider.notifier).update((p) => p.onboardingDone = true);
    await tester.pumpWidget(
      testApp(
        c,
        home: const PlayScreen(mode: GameMode.free),
        locale: 'en',
      ),
    );
    await tester.pump();

    MixoGame game() => tester
        .widget<GameWidget<MixoGame>>(find.byType(GameWidget<MixoGame>))
        .game!;

    // Intro card for the first mechanic (drops) pauses for 2 s.
    await tester.pump(const Duration(seconds: 3));

    var frames = 0;
    while (find.byKey(const Key('results-score')).evaluate().isEmpty &&
        frames < 3000) {
      await tester.pump(const Duration(milliseconds: 100));
      frames++;
    }
    expect(
      find.byKey(const Key('results-score')),
      findsOneWidget,
      reason: 'no game over after $frames frames',
    );
    expect(find.byKey(const Key('coach-tip')), findsOneWidget);
    final p = c.read(profileProvider);
    expect(p.stats.runs, 1);
    expect(p.xp + (p.level - 1) * 100, greaterThan(0));
    expect(p.skill.recentRuns, hasLength(1));

    // The AGAIN button is always on screen (never pushed below the fold).
    final again = tester.getRect(find.byKey(const Key('again-button')));
    expect(
      again.bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );

    final before = DateTime.now();
    await tester.tap(find.byKey(const Key('again-button')));
    await tester.pump();
    expect(DateTime.now().difference(before).inMilliseconds, lessThan(1000));
    expect(find.byKey(const Key('results-score')), findsNothing);
    expect(game().sim.tick, lessThan(5));
    expect(game().sim.isOver, isFalse);
  });

  testWidgets('pause and resume', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = testContainer();
    // Skip the intro card: mark drops as already seen.
    c
        .read(profileProvider.notifier)
        .update((p) => p.skill.seenMechanics.addAll(<Never>{}));
    await tester.pumpWidget(testApp(c, home: const PlayScreen(), locale: 'en'));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byKey(const Key('resume-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume-button')));
    await tester.pump();
    expect(find.byKey(const Key('resume-button')), findsNothing);
  });
}
