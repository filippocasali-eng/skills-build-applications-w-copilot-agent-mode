import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_provider.dart';

/// Google Mobile Ads (rewarded + interstitial). Unit ids default to
/// Google's public TEST units; real ids are injected at build time with
/// --dart-define=ADMOB_REWARDED=... / ADMOB_INTERSTITIAL=...
/// [age] 0 means "not answered yet".
AgeRestrictedTreatment treatmentFor(int age) => age >= 18
    ? AgeRestrictedTreatment.unspecified
    : (age > 0 && age < 13)
    ? AgeRestrictedTreatment.child
    : AgeRestrictedTreatment.teen;

class GoogleAdsProvider implements AdProvider {
  static const _rewardedId = String.fromEnvironment(
    'ADMOB_REWARDED',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _interstitialId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  bool _ready = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  /// Age signal for Google's ad treatment:
  /// - under 13: child treatment (COPPA, no personalised ads);
  /// - 13-17, or age not answered yet: teen treatment;
  /// - 18+: unspecified (personalisation only with UMP consent).
  /// The content rating is capped at T for everyone.
  Future<void> init({required int age}) async {
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.t,
          ageRestrictedTreatment: treatmentFor(age),
        ),
      );
      _ready = true;
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  void _loadRewarded() => RewardedAd.load(
    adUnitId: _rewardedId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) => _rewarded = ad,
      onAdFailedToLoad: (_) => _rewarded = null,
    ),
  );

  void _loadInterstitial() => InterstitialAd.load(
    adUnitId: _interstitialId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => _interstitial = ad,
      onAdFailedToLoad: (_) => _interstitial = null,
    ),
  );

  @override
  bool get available => _ready && _rewarded != null;

  @override
  Future<bool> showRewarded(String placement) async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    final earned = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!earned.isCompleted) earned.complete(false);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadRewarded();
        if (!earned.isCompleted) earned.complete(false);
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        if (!earned.isCompleted) earned.complete(true);
      },
    );
    return earned.future;
  }

  @override
  Future<void> showInterstitial(String placement) async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
        done.complete();
      },
    );
    await ad.show();
    return done.future;
  }
}
