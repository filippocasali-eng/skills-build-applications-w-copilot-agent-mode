import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/app/app.dart';

void main() {
  testWidgets('home shows the big play button (IT)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MixoApp(locale: Locale('it'))),
    );
    await tester.pump();
    expect(find.text('GIOCA'), findsOneWidget);
    expect(find.text('MIXO'), findsOneWidget);
  });

  testWidgets('home shows the big play button (EN)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MixoApp(locale: Locale('en'))),
    );
    await tester.pump();
    expect(find.text('PLAY'), findsOneWidget);
  });
}
