import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/campaign.dart';
import 'package:orbit_commando/core/progress/progress.dart';
import 'package:orbit_commando/features/play/play_screen.dart';
import 'package:orbit_commando/features/results/results_screen.dart';
import 'package:orbit_commando/features/run/run.dart';
import 'package:orbit_commando/game/input/input_source.dart';
import 'package:orbit_commando/game/play_config.dart';
import 'package:orbit_commando/game/roster.dart';
import 'package:orbit_commando/game/sim/balance.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';
import 'package:orbit_commando/game/levels/tiled_loader.dart';

import '../helpers/app.dart';

/// Whole flow with the real screens: the autopilot clears level 1-1 inside
/// PlayScreen, the game hands over to ResultsScreen and progress is saved.
void main() {
  Future<RunSpec> campaignRun() async {
    final c = await Campaign.load(rootBundle);
    return RunSpec(
      mode: GameMode.campaign,
      levels: [c.entries.first],
      difficulty: Difficulty.normal,
      hero: Commando.roxy,
    );
  }

  testWidgets('autopilot clears 1-1 and lands on the results', (tester) async {
    final run = (await tester.runAsync(campaignRun))!;
    final c = await pumpApp(
      tester,
      PlayScreen(run: run, input: AutoPilot()),
      save: adultSave(),
    );
    expect(find.byType(PlayScreen), findsOneWidget);
    // 5 sim steps per frame (the clock's catch-up limit): 12 frames a second.
    for (var i = 0; i < 12 * 150; i++) {
      await tester.pump(const Duration(milliseconds: 84));
      if (i % 120 == 0) await settle(tester, rounds: 1);
      if (find.byType(ResultsScreen).evaluate().isNotEmpty) break;
    }
    await settle(tester);
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(c.read(progressProvider).levels.containsKey('w1_l1'), isTrue);
    await screenshot(tester, 'results_live');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('results screen tallies, stamps the rank and continues', (
    tester,
  ) async {
    final run = (await tester.runAsync(campaignRun))!;
    final level = TiledLoader.parse(
      File('assets/levels/w1_l1.tmj').readAsStringSync(),
    );
    const result = LevelResult(
      score: 12340,
      timeBonus: 3000,
      noDeathBonus: 5000,
      total: 20340,
      rank: 'A',
      deaths: 0,
      hostagesFreed: 3,
      hostagesTotal: 3,
      cassettes: 1,
      seconds: 64,
      kills: 31,
    );
    final results = ResultsScreen(
      run: run,
      result: result,
      rewards: const LevelRewards(
        tokens: 120,
        xp: 200,
        creditEarned: true,
        newRecord: true,
        unlocks: [],
        trophies: [],
      ),
      level: level,
    );
    // The results are pushed over the campaign map in the real app.
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => results)),
          child: const Text('host'),
        ),
      ),
      save: adultSave(cartridge: true),
    );
    await tester.tap(find.text('host'));
    await settle(tester);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.textContaining('20340'), findsWidgets);
    await screenshot(tester, 'results');
    await tester.tap(find.text('Avanti'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });
}
