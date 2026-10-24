import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/profile_controller.dart';
import 'core/progression.dart';
import 'core/providers.dart';
import 'core/services/billing.dart';
import 'core/services/feedback.dart';
import 'core/services/game_data.dart';
import 'core/services/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final audio = FlameGameAudio();
  final (data, store, _) = await (
    GameData.load(rootBundle),
    SharedPrefsStore.open(),
    audio.init(),
  ).wait;
  final BillingService billing = kIsWeb
      ? UnavailableBillingService()
      : PlayBillingService();

  final container = ProviderContainer(
    overrides: [
      gameDataProvider.overrideWithValue(data),
      storeProvider.overrideWithValue(store),
      audioProvider.overrideWithValue(audio),
      billingProvider.overrideWithValue(billing),
    ],
  );

  // Apply saved settings to the services.
  final profile = container.read(profileProvider);
  audio
    ..soundOn = profile.settings.sound
    ..musicOn = profile.settings.music;
  container.read(hapticsProvider).enabled = profile.settings.haptics;

  // Purchases and restores grant cosmetic items locally.
  billing.onEntitled = (productId) => container
      .read(profileProvider.notifier)
      .update((p) => Progression.grantProduct(p, productId));
  await billing.init();

  runApp(
    UncontrolledProviderScope(container: container, child: const MixoApp()),
  );
}
