import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/app/app.dart';
import 'package:orbit_commando/features/play/play_screen.dart';
import 'package:orbit_commando/features/title/title_screen.dart';

final _gameWidget = find.byWidgetPredicate((w) => w is GameWidget);

void main() {
  testWidgets('title -> play in one tap, and back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(const OrbitApp(locale: Locale('it')));
    await tester.pump();

    expect(find.byType(TitleScreen), findsOneWidget);
    expect(_gameWidget, findsOneWidget);

    await tester.tap(find.byKey(const Key('title.tap')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.byTooltip('Indietro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('play.back')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.byType(TitleScreen), findsOneWidget);
  });
}
