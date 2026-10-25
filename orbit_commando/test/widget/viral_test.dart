import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/campaign.dart';
import 'package:orbit_commando/core/progress/progress.dart';
import 'package:orbit_commando/core/social/challenge.dart';
import 'package:orbit_commando/core/social/share.dart';
import 'package:orbit_commando/features/challenge/challenge_screen.dart';
import 'package:orbit_commando/features/play/play_screen.dart';
import 'package:orbit_commando/features/results/results_screen.dart';
import 'package:orbit_commando/features/run/run.dart';
import 'package:orbit_commando/game/levels/tiled_loader.dart';
import 'package:orbit_commando/game/play_config.dart';
import 'package:orbit_commando/game/roster.dart';
import 'package:orbit_commando/game/sim/balance.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';

import '../helpers/app.dart';

class FakeShare implements ShareService {
  Uint8List? png;
  String? text;

  @override
  Future<bool> sharePng(Uint8List png, String text) async {
    this.png = png;
    this.text = text;
    return true;
  }
}

void main() {
  testWidgets('a wrong challenge code is refused', (tester) async {
    await pumpApp(
      tester,
      const ChallengeScreen(initialCode: 'OC-HELLO-WORLD'),
      save: adultSave(),
    );
    await tester.tap(find.text('Gioca').last);
    await settle(tester);
    expect(
      find.text('Codice non valido. Controllalo e riprova.'),
      findsOneWidget,
    );
    expect(find.byType(PlayScreen), findsNothing);
  });

  testWidgets('a friend\'s code starts the same run with the target', (
    tester,
  ) async {
    const ch = Challenge(
      levelIndex: 6,
      modifier: 2,
      seed: 4242,
      hero: 1,
      target: 31400,
    );
    await pumpApp(
      tester,
      ChallengeScreen(initialCode: ch.encode()),
      save: adultSave(),
    );
    await screenshot(tester, 'challenges');
    await tester.tap(find.text('Gioca').last);
    await settle(tester);
    final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(play.run.mode, GameMode.challenge);
    expect(play.run.challenge, ch);
    expect(play.run.seed, 4242);
    expect(play.run.hero, Commando.brutus);
    expect(play.run.current.id, 'w2_l2');
    expect(play.run.weekly, WeeklyModifier.ricochetOnly);
  });

  testWidgets('results: the share card goes out with a working code', (
    tester,
  ) async {
    final share = FakeShare();
    rootBundle.clear();
    final c = await tester.runAsync(() => Campaign.load(rootBundle));
    final run = RunSpec(
      mode: GameMode.campaign,
      levels: [c!.entries.first],
      difficulty: Difficulty.normal,
      hero: Commando.roxy,
    );
    final results = ResultsScreen(
      run: run,
      result: const LevelResult(
        score: 20000,
        timeBonus: 1000,
        noDeathBonus: 5000,
        total: 26000,
        rank: 'S',
        deaths: 0,
        hostagesFreed: 3,
        hostagesTotal: 3,
        cassettes: 1,
        seconds: 50,
        kills: 40,
        maxCombo: 10,
      ),
      rewards: const LevelRewards(
        tokens: 100,
        xp: 100,
        creditEarned: false,
        newRecord: false,
        unlocks: [],
        trophies: [],
      ),
      level: TiledLoader.parse(
        File('assets/levels/w1_l1.tmj').readAsStringSync(),
      ),
    );
    await pumpApp(
      tester,
      results,
      save: adultSave(),
      overrides: [shareServiceProvider.overrideWithValue(share)],
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await settle(tester);
    await screenshot(tester, 'results_share');
    expect(find.text('Combo max x10'), findsOneWidget);
    await tester.tap(find.text('Sfida gli amici'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await settle(tester);
    expect(share.png, isNotNull);
    final dir = Platform.environment['SHOT_DIR'];
    if (dir != null) File('$dir/share_card.png').writeAsBytesSync(share.png!);
    // PNG signature, 16:9 card at 2.5x.
    expect(share.png!.sublist(1, 4), 'PNG'.codeUnits);
    final code = RegExp(r'OC-\w{5}-\w{5}').firstMatch(share.text!)!.group(0)!;
    final back = Challenge.decode(code)!;
    expect(back.levelIndex, 0);
    expect(back.target, 26000);
    expect(share.text, contains(kStoreUrl));
  });
}
