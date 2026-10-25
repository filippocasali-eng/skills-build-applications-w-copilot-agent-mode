import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/monetization/wallet.dart';
import 'package:orbit_commando/core/profile/profile.dart';
import 'package:orbit_commando/core/progress/progress.dart';
import 'package:orbit_commando/core/settings/settings.dart';
import 'package:orbit_commando/features/campaign_map/campaign_map.dart';
import 'package:orbit_commando/features/chat/chat_screen.dart';
import 'package:orbit_commando/features/menu/main_menu.dart';
import 'package:orbit_commando/features/onboarding/age_gate.dart';
import 'package:orbit_commando/features/settings/settings_screen.dart';
import 'package:orbit_commando/features/shop/shop_screen.dart';
import 'package:orbit_commando/features/trophies/trophies_screen.dart';
import 'package:orbit_commando/features/workshop/workshop_screen.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('main menu: campaign open, Arcade locked until World 1', (
    tester,
  ) async {
    await pumpApp(tester, const MainMenu(), save: adultSave());
    await screenshot(tester, 'menu');
    expect(
      find.text('CAMPAGNA'),
      findsNothing,
    ); // the font is caps-only by glyphs, text keeps case
    expect(find.text('Campagna'), findsOneWidget);
    expect(find.text('Finisci il Mondo 1 per sbloccare'), findsOneWidget);
    await tester.tap(find.text('Campagna'));
    await settle(tester);
    expect(find.byType(CampaignMap), findsOneWidget);
  });

  testWidgets('campaign map: World 2 asks for the Full Cartridge', (
    tester,
  ) async {
    await pumpApp(tester, const CampaignMap(), save: adultSave());
    await screenshot(tester, 'map');
    expect(find.textContaining('Cintura di Asteroidi'), findsOneWidget);
    await tester.tap(find.text('Mondo 2'));
    await settle(tester);
    expect(find.text('Cartuccia Completa'), findsWidgets);
  });

  testWidgets('shop: buy the cartridge with the test store, odds visible', (
    tester,
  ) async {
    final c = await pumpApp(tester, const ShopScreen(), save: adultSave());
    await screenshot(tester, 'shop');
    expect(find.text('TEST STORE'), findsOneWidget);
    await tester.tap(find.textContaining('€4,99'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(c.read(walletProvider).fullCartridge, isTrue);
    expect(c.read(walletProvider).history.single.sku, 'full_cartridge');
    await tester.tap(find.text('Capsule cosmiche'));
    await settle(tester);
    await tester.tap(find.text('Probabilità'));
    await settle(tester);
    expect(find.textContaining('Leggendaria: 1.50%'), findsOneWidget);
  });

  testWidgets('shop: paid capsules disabled for minors', (tester) async {
    await pumpApp(
      tester,
      const ShopScreen(),
      save: {
        'profile': {'by': DateTime.now().year - 16, 'bm': 1},
        'wallet': {'gems': 500},
      },
    );
    await tester.tap(find.text('Capsule cosmiche'));
    await settle(tester);
    expect(
      find.text('Le capsule a pagamento sono disattivate sotto i 18 anni.'),
      findsOneWidget,
    );
  });

  testWidgets('settings: switching to fixed camera persists', (tester) async {
    final c = await pumpApp(tester, const SettingsScreen(), save: adultSave());
    await screenshot(tester, 'settings');
    expect(c.read(settingsProvider).rotatingCamera, isTrue);
    final row = find
        .ancestor(of: find.text('Camera'), matching: find.byType(Row))
        .first;
    await tester.tap(find.descendant(of: row, matching: find.text('>')));
    await settle(tester);
    expect(c.read(settingsProvider).rotatingCamera, isFalse);
  });

  testWidgets('workshop: buying a level spends tokens', (tester) async {
    final c = await pumpApp(
      tester,
      const WorkshopScreen(),
      save: {
        ...adultSave(),
        'progress': {'tokens': 1000},
      },
    );
    await tester.tap(find.text('150 gettoni'));
    await settle(tester);
    expect(c.read(progressProvider).upgrades['damage'], 1);
    expect(c.read(progressProvider).tokens, 850);
  });

  testWidgets('trophies screen lists all 32', (tester) async {
    await pumpApp(tester, const TrophiesScreen());
    expect(find.text('0/32 trofei'), findsOneWidget);
  });

  testWidgets('chat: under 16 cannot go online; 16-17 gets emotes only', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ChatScreen(),
      save: {
        'profile': {'by': DateTime.now().year - 14, 'bm': 1},
      },
    );
    expect(
      find.text('Le funzioni online sono disponibili dai 16 anni.'),
      findsOneWidget,
    );
    await pumpApp(
      tester,
      const ChatScreen(),
      save: {
        'profile': {'by': DateTime.now().year - 17, 'bm': 1},
      },
    );
    expect(
      find.text('Solo messaggi rapidi (sotto i 18 anni).'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await pumpApp(tester, const ChatScreen(), save: adultSave());
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('age gate stores year and month', (tester) async {
    var done = false;
    final c = await pumpApp(tester, AgeGate(onDone: () => done = true));
    await tester.tap(find.text('>').first);
    await tester.pump();
    await tester.tap(find.text('>').last);
    await tester.pump();
    await tester.tap(find.text('Conferma'));
    await settle(tester);
    expect(done, isTrue);
    expect(c.read(profileProvider).ageKnown, isTrue);
  });
}
