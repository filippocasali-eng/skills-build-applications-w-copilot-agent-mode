import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/app/app.dart';
import 'package:orbit_commando/core/monetization/billing.dart';
import 'package:orbit_commando/core/monetization/store.dart';
import 'package:orbit_commando/core/providers.dart';
import 'package:orbit_commando/core/storage/save_store.dart';

/// Pumps the app on [home] with an in-memory save and the test store.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget home, {
  Map<String, dynamic>? save,
  String locale = 'it',
}) async {
  await loadFonts();
  // A load left pending by the previous test's fake clock would stay cached
  // forever: start every test with a fresh asset cache.
  rootBundle.clear();
  // A typical 20:9 phone in landscape: 2400x1080 at 2.625x (914x411 dp).
  tester.view.physicalSize = const Size(2400, 1080);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(SaveStore.memory(save)),
      billingProvider.overrideWithValue(TestBillingService()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OrbitApp(locale: Locale(locale), home: home),
    ),
  );
  await settle(tester);
  return container;
}

/// Lets real async work (asset loading, image decoding) finish.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Map<String, dynamic> adultSave({bool cartridge = false}) => {
  'profile': {'by': 1985, 'bm': 5},
  'wallet': {'cartridge': cartridge, 'gems': 1000},
};

bool _fontsLoaded = false;

/// Tests don't load pubspec fonts by default: load the real pixel font so
/// text measures like on a device.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final loader = FontLoader('Orbit5')
    ..addFont(rootBundle.load('assets/fonts/Orbit5.ttf'));
  await loader.load();
}

/// Saves a PNG of the current screen when SHOT_DIR is set.
Future<void> screenshot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOT_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final img = await layer.toImage(
      Offset.zero & tester.view.physicalSize,
      pixelRatio: 0.5,
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
