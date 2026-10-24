import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/profile_controller.dart';
import 'package:mixo_color_rush/core/services/key_value_store.dart';
import 'package:mixo_color_rush/features/settings/settings_screen.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('toggles persist and language switches live', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final c = testContainer(store: store);
    await tester.pumpWidget(
      testApp(c, home: const SettingsScreen(), locale: 'it'),
    );
    await tester.pump();
    expect(find.text('Musica'), findsOneWidget);
    expect(c.read(profileProvider).settings.music, isTrue);

    await tester.tap(find.byKey(const Key('set-music')));
    await tester.pump();
    expect(c.read(profileProvider).settings.music, isFalse);
    expect(store.getString('mixo.profile'), contains('"music":false'));

    expect(c.read(profileProvider).settings.symbolsAlways, isTrue);
    await tester.tap(find.byKey(const Key('set-symbols')));
    await tester.pump();
    expect(c.read(profileProvider).settings.symbolsAlways, isFalse);
  });

  testWidgets('parent area requires the parental gate', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = testContainer();
    await tester.pumpWidget(
      testApp(c, home: const SettingsScreen(), locale: 'en'),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('parent-area')));
    await tester.pumpAndSettle();
    expect(find.text('Ask a grown-up'), findsOneWidget);
    expect(find.text('Daily play limit'), findsNothing);
  });
}
