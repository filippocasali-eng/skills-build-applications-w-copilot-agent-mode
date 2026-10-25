import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live-tunable values (gem prices, shop rotation, events, blocked
/// countries). v1 reads bundled defaults; a Firebase Remote Config adapter
/// can override the same keys without republishing (MONETIZATION.md).
class RemoteConfig {
  const RemoteConfig(this.values);

  factory RemoteConfig.parse(String source) =>
      RemoteConfig(jsonDecode(source) as Map<String, dynamic>);

  final Map<String, dynamic> values;

  int gemPrice(String key) =>
      ((values['gem_prices'] as Map<String, dynamic>?)?[key] as num?)
          ?.toInt() ??
      0;

  /// Approximate euro value of a gem amount, in cents.
  int gemsToCents(int gems) =>
      (gems * ((values['gem_euro_cents_per_100'] as num?) ?? 91) / 100).round();

  Set<String> get paidLootboxBlockedCountries => {
    for (final c
        in (values['lootbox_paid_blocked_countries'] as List<dynamic>? ??
            const ['BE']))
      (c as String).toUpperCase(),
  };

  List<Map<String, dynamic>> list(String key) => [
    for (final e in (values[key] as List<dynamic>? ?? const []))
      e as Map<String, dynamic>,
  ];

  Map<String, dynamic> map(String key) =>
      (values[key] as Map<String, dynamic>?) ?? const {};

  int intValue(String key, int fallback) =>
      (values[key] as num?)?.toInt() ?? fallback;
}

abstract interface class RemoteConfigService {
  Future<RemoteConfig> fetch();
}

class BundledRemoteConfig implements RemoteConfigService {
  BundledRemoteConfig(this.bundle);

  final AssetBundle bundle;

  @override
  Future<RemoteConfig> fetch() async => RemoteConfig.parse(
    await bundle.loadString('assets/data/remote_defaults.json'),
  );
}

final remoteConfigProvider = FutureProvider<RemoteConfig>(
  (ref) => BundledRemoteConfig(rootBundle).fetch(),
);
