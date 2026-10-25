import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Funnel telemetry (opt-in). v1 writes JSON lines to a local file; a
/// Firebase Analytics adapter can implement the same interface (disabled by
/// default, see MONETIZATION.md).
abstract interface class AnalyticsService {
  void log(String event, [Map<String, Object?> params = const {}]);
}

class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {}
}

class LocalFileAnalytics implements AnalyticsService {
  LocalFileAnalytics(this.file);

  final File file;

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    final line = jsonEncode({
      't': DateTime.now().toUtc().toIso8601String(),
      'e': event,
      ...params,
    });
    try {
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
    } on FileSystemException {
      // Telemetry must never break the game.
    }
  }
}

/// Swapped in main() depending on the player's opt-in.
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalytics(),
);
