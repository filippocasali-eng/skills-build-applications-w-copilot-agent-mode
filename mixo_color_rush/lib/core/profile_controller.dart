import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/profile.dart';
import 'progression.dart';
import 'providers.dart';
import 'services/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(storeProvider),
    ref.watch(gameDataProvider).director,
  ),
);

/// Owns the mutable [PlayerProfile]; every change is persisted.
class ProfileController extends Notifier<PlayerProfile> {
  @override
  PlayerProfile build() => ref.watch(profileRepositoryProvider).load();

  /// Applies [change] to the profile, notifies listeners and saves.
  T update<T>(T Function(PlayerProfile p) change) {
    final out = change(state);
    ref.notifyListeners();
    unawaited(ref.read(profileRepositoryProvider).save(state));
    return out;
  }

  /// Like [update] but without notifying listeners: safe during widget
  /// lifecycle callbacks, for changes no widget displays.
  T silent<T>(T Function(PlayerProfile p) change) {
    final out = change(state);
    unawaited(ref.read(profileRepositoryProvider).save(state));
    return out;
  }

  bool buy(String itemId) => update((p) => Progression.buyWithStars(p, itemId));
  bool equip(String itemId) => update((p) => Progression.equip(p, itemId));
}

final profileProvider = NotifierProvider<ProfileController, PlayerProfile>(
  ProfileController.new,
);
