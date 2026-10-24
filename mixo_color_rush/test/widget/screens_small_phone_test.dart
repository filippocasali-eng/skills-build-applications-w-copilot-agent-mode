import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/features/academy/academy_screen.dart';
import 'package:mixo_color_rush/features/collection/collection_screen.dart';
import 'package:mixo_color_rush/features/daily/daily_screen.dart';
import 'package:mixo_color_rush/features/ghost/ghost_screen.dart';
import 'package:mixo_color_rush/features/home/home_screen.dart';
import 'package:mixo_color_rush/features/missions/missions_screen.dart';
import 'package:mixo_color_rush/features/settings/parent_area_screen.dart';
import 'package:mixo_color_rush/features/settings/settings_screen.dart';
import 'package:mixo_color_rush/features/shop/shop_screen.dart';

import '../support/test_app.dart';

/// Every screen renders without overflow on a small phone (360×640 dp),
/// in both languages.
void main() {
  final screens = <String, Widget Function()>{
    'home': HomeScreen.new,
    'collection': CollectionScreen.new,
    'missions': MissionsScreen.new,
    'academy': AcademyScreen.new,
    'daily': DailyScreen.new,
    'ghost': GhostScreen.new,
    'settings': SettingsScreen.new,
    'parent': ParentAreaScreen.new,
    'shop': ShopScreen.new,
  };
  for (final locale in ['it', 'en']) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits a small phone ($locale)', (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          testApp(testContainer(), home: entry.value(), locale: locale),
        );
        await tester.pump(const Duration(milliseconds: 500));
        // Visit the other tabs too.
        for (final tab in find.byType(Tab).evaluate().toList()) {
          await tester.tap(find.byWidget(tab.widget));
          await tester.pump(const Duration(milliseconds: 600));
        }
      });
    }
  }
}
