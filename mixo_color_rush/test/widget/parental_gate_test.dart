import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/features/parental_gate/parental_gate.dart';

import '../support/test_app.dart';

void main() {
  Future<bool?> openGate(WidgetTester tester, List<bool?> out) async {
    final c = testContainer();
    await tester.pumpWidget(
      testApp(
        c,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => out.add(
                  await showParentalGate(context, random: math.Random(3)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return null;
  }

  Future<void> holdThreeSeconds(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('gate-hold'))),
    );
    for (var i = 0; i < 33; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(Key('gate-digit-$d')));
      await tester.pump();
    }
  }

  int answer(WidgetTester tester) {
    final q = tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    return int.parse(m.group(1)!) * int.parse(m.group(2)!);
  }

  testWidgets('a short tap does not reveal the question', (tester) async {
    final out = <bool?>[];
    await openGate(tester, out);
    await tester.tap(find.byKey(const Key('gate-hold')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('gate-question')), findsNothing);
  });

  testWidgets('hold 3 s + correct answer passes', (tester) async {
    final out = <bool?>[];
    await openGate(tester, out);
    await holdThreeSeconds(tester);
    final q = find.byKey(const Key('gate-question'));
    expect(q, findsOneWidget);
    final a = answer(tester);
    expect(a, greaterThanOrEqualTo(36)); // two-digit × one-digit
    await type(tester, '$a');
    await tester.tap(find.byKey(const Key('gate-ok')));
    await tester.pumpAndSettle();
    expect(out, [true]);
  });

  testWidgets('three wrong answers fail', (tester) async {
    final out = <bool?>[];
    await openGate(tester, out);
    await holdThreeSeconds(tester);
    for (var i = 0; i < 3; i++) {
      await type(tester, '1');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
    }
    expect(out, [false]);
  });
}
