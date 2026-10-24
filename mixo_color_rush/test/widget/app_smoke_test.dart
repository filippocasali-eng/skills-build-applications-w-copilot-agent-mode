import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/app/app.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MixoApp()));
    expect(find.text('MIXO: Color Rush'), findsOneWidget);
  });
}
