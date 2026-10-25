import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR consent through Google's User Messaging Platform (UMP).
/// Ads are initialised only after UMP says ads may be requested.
class ConsentService {
  bool _canRequestAds = false;

  bool get canRequestAds => _canRequestAds;

  Future<bool> gather() async {
    if (kIsWeb) return false;
    final done = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          _canRequestAds = await ConsentInformation.instance.canRequestAds();
          if (!done.isCompleted) done.complete(_canRequestAds);
        },
        (e) {
          debugPrint('UMP error: ${e.message}');
          if (!done.isCompleted) done.complete(false);
        },
      );
    } catch (e) {
      debugPrint('UMP unavailable: $e');
      return false;
    }
    return done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
  }

  /// "Ad consent" button in Settings.
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('Privacy options unavailable: $e');
    }
  }
}

final consentProvider = Provider((ref) => ConsentService());
