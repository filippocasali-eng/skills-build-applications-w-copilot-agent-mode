import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/app/app.dart';
import 'package:mixo_color_rush/core/providers.dart';
import 'package:mixo_color_rush/core/services/game_data.dart';

import '../support/test_data.dart';

void main() {
  testWidgets('home shows the big play button (IT)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameDataProvider.overrideWithValue(
            GameData(library: loadLibrary(), director: loadDirector()),
          ),
        ],
        child: const MixoApp(locale: Locale('it')),
      ),
    );
    await tester.pump();
    expect(find.text('GIOCA'), findsOneWidget);
    expect(find.text('MIXO'), findsOneWidget);
  });

  testWidgets('home shows the big play button (EN)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameDataProvider.overrideWithValue(
            GameData(library: loadLibrary(), director: loadDirector()),
          ),
        ],
        child: const MixoApp(locale: Locale('en')),
      ),
    );
    await tester.pump();
    expect(find.text('PLAY'), findsOneWidget);
  });
}
