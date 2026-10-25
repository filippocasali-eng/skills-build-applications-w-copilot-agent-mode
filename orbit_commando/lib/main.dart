import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/ui/pixel.dart';
import 'core/ads/ad_provider.dart';
import 'core/ads/consent.dart';
import 'core/ads/google_ads.dart';
import 'core/analytics/analytics.dart';
import 'core/audio/audio.dart';
import 'core/monetization/wallet.dart';
import 'core/providers.dart';
import 'core/settings/settings.dart';
import 'core/storage/save_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Hive.initFlutter();
  final save = await SaveStore.open();
  final settings = Settings.fromJson(save.section('settings'));
  final wallet = Wallet.fromJson(save.section('wallet'));

  final audio = FlameAudioService();
  await audio.init();
  audio.setVolumes(music: settings.musicVolume, sfx: settings.sfxVolume);
  UiFeedback.onTap = () => audio.sfx(Sfx.confirm);
  UiFeedback.onFocus = () => audio.sfx(Sfx.select);

  AnalyticsService analytics = const NoopAnalytics();
  if (settings.analyticsOptIn) {
    final dir = await getApplicationSupportDirectory();
    analytics = LocalFileAnalytics(File('${dir.path}/telemetry.jsonl'));
  }

  // Ads only for players without the Full Cartridge, after UMP consent.
  final consent = ConsentService();
  final ads = GoogleAdsProvider();
  final useAds = !wallet.fullCartridge && !kDebugMode;

  runApp(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(save),
        audioProvider.overrideWithValue(audio),
        analyticsProvider.overrideWithValue(analytics),
        consentProvider.overrideWithValue(consent),
        adProvider.overrideWithValue(
          useAds ? ads : const NoAdsProvider(simulateRewards: kTestStore),
        ),
      ],
      child: const OrbitApp(),
    ),
  );

  if (useAds) {
    if (await consent.gather()) await ads.init();
  }
}
