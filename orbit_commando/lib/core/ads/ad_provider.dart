import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ads behind an interface so builds, tests and paying players can run
/// without any ad SDK (brief §8.4).
abstract interface class AdProvider {
  bool get available;

  /// Shows a rewarded video. Returns true if the reward was earned.
  Future<bool> showRewarded(String placement);

  /// Shows an interstitial (caller enforces the frequency rules).
  Future<void> showInterstitial(String placement);
}

/// Used in debug, in tests and after the Full Cartridge purchase.
class NoAdsProvider implements AdProvider {
  const NoAdsProvider({this.simulateRewards = false});

  /// When true, rewarded "videos" succeed instantly (test store builds).
  final bool simulateRewards;

  @override
  bool get available => simulateRewards;

  @override
  Future<bool> showRewarded(String placement) async => simulateRewards;

  @override
  Future<void> showInterstitial(String placement) async {}
}

/// Interstitial frequency policy: at most one every 3 completed levels and
/// never right after a death.
class InterstitialPolicy {
  int _levelsSinceAd = 0;

  bool onLevelComplete() {
    _levelsSinceAd++;
    if (_levelsSinceAd >= 3) {
      _levelsSinceAd = 0;
      return true;
    }
    return false;
  }

  /// Deaths never trigger ads.
  bool onDeath() => false;
}

final adProvider = Provider<AdProvider>((ref) => const NoAdsProvider());
final interstitialPolicyProvider = Provider((ref) => InterstitialPolicy());
