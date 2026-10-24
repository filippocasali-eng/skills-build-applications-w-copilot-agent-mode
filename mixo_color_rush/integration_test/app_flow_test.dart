import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixo_color_rush/app/app.dart';
import 'package:mixo_color_rush/core/providers.dart';
import 'package:mixo_color_rush/core/services/game_data.dart';
import 'package:mixo_color_rush/core/services/key_value_store.dart';
import 'package:mixo_color_rush/game/mixo_game.dart';
import 'package:mixo_color_rush/game/sim/replay.dart';

/// On-device flow: launch → onboarding → free run with automatic inputs →
/// game over → AGAIN restarts in < 1 s.
///
/// Run with: flutter test integration_test (emulator or device attached).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch, play, game over, restart', (tester) async {
    final data = await GameData.load(rootBundle);
    final container = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWithValue(data),
        storeProvider.overrideWithValue(MemoryStore()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MixoApp(locale: Locale('en')),
      ),
    );

    MixoGame game() => tester
        .widget<GameWidget<MixoGame>>(find.byType(GameWidget<MixoGame>))
        .game!;

    // Splash → onboarding (practice run, cannot be lost). Steer towards
    // matching gates until it completes, then the free run starts.
    await tester.pump(const Duration(seconds: 2));
    for (
      var i = 0;
      i < 600 && find.byType(GameWidget<MixoGame>).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
      if (game().sim.params.practice && i % 3 == 0) {
        game().input(i.isEven ? InputAction.left : InputAction.right);
      }
      if (!game().sim.params.practice) break;
    }

    // Free run: random inputs until game over.
    var frames = 0;
    while (find.byKey(const Key('results-score')).evaluate().isEmpty &&
        frames < 4000) {
      await tester.pump(const Duration(milliseconds: 50));
      if (frames % 7 == 0) {
        game().input(frames.isEven ? InputAction.left : InputAction.right);
      }
      frames++;
    }
    expect(find.byKey(const Key('results-score')), findsOneWidget);

    final sw = Stopwatch()..start();
    await tester.tap(find.byKey(const Key('again-button')));
    await tester.pump();
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(find.byKey(const Key('results-score')), findsNothing);
    expect(game().sim.isOver, isFalse);
  });
}
