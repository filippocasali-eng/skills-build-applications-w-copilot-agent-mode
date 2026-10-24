/// Advertising abstraction. **v1 ships without ads** ([NoAds]).
///
/// Future rules (see DECISIONS.md D-020): only Google Play Families
/// self-certified SDKs, only non-personalized *rewarded* ads chosen by the
/// player (e.g. a cosmetic preview), never interstitials during play,
/// never in the first session, always behind a clear "watch" button.
abstract class AdProvider {
  bool get enabled;
  Future<bool> showRewarded(String placement);
}

class NoAds implements AdProvider {
  const NoAds();

  @override
  bool get enabled => false;

  @override
  Future<bool> showRewarded(String placement) async => false;
}
