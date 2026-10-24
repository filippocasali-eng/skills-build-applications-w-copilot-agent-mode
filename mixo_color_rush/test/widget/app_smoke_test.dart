import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/core/profile_controller.dart';
import 'package:mixo_color_rush/features/home/home_screen.dart';

import '../support/test_app.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  testWidgets('home shows the big play button and modes (IT)', (tester) async {
    await phone(tester);
    final c = testContainer();
    await tester.pumpWidget(testApp(c, home: const HomeScreen()));
    await tester.pump();
    expect(find.text('GIOCA'), findsOneWidget);
    expect(find.byKey(const Key('tile-academy')), findsOneWidget);
    expect(find.byKey(const Key('tile-daily')), findsOneWidget);
    expect(find.byKey(const Key('nickname')), findsOneWidget);
    final size = tester.getSize(find.byKey(const Key('play-button')));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets('home in English', (tester) async {
    await phone(tester);
    final c = testContainer();
    await tester.pumpWidget(testApp(c, home: const HomeScreen(), locale: 'en'));
    await tester.pump();
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('daily and ghost are locked until academy lessons 1-2', (
    tester,
  ) async {
    await phone(tester);
    final c = testContainer();
    await tester.pumpWidget(testApp(c, home: const HomeScreen(), locale: 'en'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tile-daily')));
    await tester.pump();
    expect(find.textContaining('Academy'), findsWidgets);

    c
        .read(profileProvider.notifier)
        .update(
          (p) => p.academyStars
            ..[0] = 2
            ..[1] = 1,
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('tile-daily')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-play')), findsOneWidget);
  });

  testWidgets('splash sends a new player to the played onboarding', (
    tester,
  ) async {
    await phone(tester);
    final c = testContainer();
    await tester.pumpWidget(testApp(c));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Mixo'), findsWidgets);
    expect(c.read(profileProvider).onboardingDone, isFalse);
  });
}
