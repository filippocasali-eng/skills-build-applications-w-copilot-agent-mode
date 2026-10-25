import 'dart:async';
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
import 'core/monetization/catalog.dart';
import 'core/monetization/wallet.dart';
import 'core/profile/profile.dart';
import 'core/providers.dart';
import 'core/settings/settings.dart';
import 'core/storage/save_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _start();
  } catch (e, st) {
    // Never leave the player on a dead splash: show what went wrong.
    debugPrint('Startup failed: $e\n$st');
    runApp(_StartupError('$e'));
  }
}

Future<void> _start() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Catalog.setCountry(
    WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );
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
    // After the first frame, and never fatal: ads are optional.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        try {
          final profile = Profile.fromJson(save.section('profile'));
          if (await consent.gather()) {
            await ads.init(age: profile.ageAt(DateTime.now()));
          }
        } catch (e) {
          debugPrint('Ads unavailable: $e');
        }
      }),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF0B0B1E),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            "ORBIT COMMANDO '94 non è riuscito ad avviarsi.\n\n$message",
            style: const TextStyle(color: Color(0xFFFFE36B), fontSize: 16),
          ),
        ),
      ),
    ),
  );
}
