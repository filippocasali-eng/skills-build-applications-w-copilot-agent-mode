import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/features/campaign_map/campaign_map.dart';
import 'package:orbit_commando/features/challenge/challenge_screen.dart';
import 'package:orbit_commando/features/menu/main_menu.dart';
import 'package:orbit_commando/features/settings/settings_screen.dart';
import 'package:orbit_commando/features/shop/shop_screen.dart';
import 'package:orbit_commando/features/workshop/workshop_screen.dart';
import 'package:orbit_commando/l10n/app_localizations.dart';

import '../helpers/app.dart';

/// Every main screen, in every language, on a phone: no overflow, no
/// missing translation. Overflow throws in tests, so pumping is the check.
void main() {
  final screens = <String, Widget Function()>{
    'menu': () => const MainMenu(),
    'map': () => const CampaignMap(),
    'challenges': () => const ChallengeScreen(),
    'shop': () => const ShopScreen(),
    'workshop': () => const WorkshopScreen(),
    'settings': () => const SettingsScreen(),
  };
  for (final locale in AppLocalizations.supportedLocales) {
    for (final e in screens.entries) {
      testWidgets('${locale.languageCode}: ${e.key} lays out', (tester) async {
        await pumpApp(
          tester,
          e.value(),
          save: adultSave(),
          locale: locale.languageCode,
        );
        expect(tester.takeException(), isNull);
        if (e.key == 'menu') {
          await screenshot(tester, 'menu_${locale.languageCode}');
        }
      });
    }
  }
}
