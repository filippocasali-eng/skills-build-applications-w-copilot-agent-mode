import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/ads.dart';
import 'services/billing.dart';
import 'services/feedback.dart';
import 'services/game_data.dart';
import 'services/key_value_store.dart';
import 'services/wellbeing.dart';

/// Overridden in `main()` once assets are loaded.
final gameDataProvider = Provider<GameData>(
  (ref) => throw UnimplementedError('gameDataProvider must be overridden'),
);

/// Overridden in `main()` with [SharedPrefsStore]; tests use [MemoryStore].
final storeProvider = Provider<KeyValueStore>((ref) => MemoryStore());

final audioProvider = Provider<GameAudio>((ref) => SilentAudio());

final hapticsProvider = Provider<Haptics>((ref) => Haptics());

final billingProvider = Provider<BillingService>(
  (ref) => UnavailableBillingService(),
);

final adsProvider = Provider<AdProvider>((ref) => const NoAds());

final sessionProvider = Provider<SessionTracker>((ref) => SessionTracker());

/// Injectable clock (tests).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
