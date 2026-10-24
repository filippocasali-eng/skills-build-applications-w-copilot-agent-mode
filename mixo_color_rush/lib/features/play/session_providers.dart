import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Best score (in memory until persistence lands in M6).
class BestScoreNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Returns true if [score] is a new record.
  bool submit(int score) {
    if (score <= state) return false;
    state = score;
    return true;
  }
}

final bestScoreProvider = NotifierProvider<BestScoreNotifier, int>(
  BestScoreNotifier.new,
);
