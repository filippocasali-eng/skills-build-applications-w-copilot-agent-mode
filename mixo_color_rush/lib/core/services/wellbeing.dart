import '../models/profile.dart';

/// Digital wellbeing rules (no streaks, no guilt).
abstract final class Wellbeing {
  /// A gentle break is suggested after this much continuous play.
  static const Duration breakAfter = Duration(minutes: 30);

  /// A gap this long resets the continuous play counter.
  static const Duration resetGap = Duration(minutes: 5);

  static String dayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  /// Adds [ms] of play to today's total (resetting on a new day).
  static void addPlay(PlayerProfile p, int ms, DateTime now) {
    final today = dayKey(now);
    if (p.playDate != today) {
      p
        ..playDate = today
        ..playMsToday = 0
        ..limitExtensionMinutes = 0;
    }
    p.playMsToday += ms;
  }

  static int todayMs(PlayerProfile p, DateTime now) =>
      p.playDate == dayKey(now) ? p.playMsToday : 0;

  /// Whether the parent's daily limit is reached for today.
  static bool limitReached(PlayerProfile p, DateTime now) {
    final limit = p.parent.dailyLimitMinutes;
    if (limit <= 0) return false;
    final ext = p.playDate == dayKey(now) ? p.limitExtensionMinutes : 0;
    return todayMs(p, now) >= (limit + ext) * 60000;
  }
}

/// Tracks continuous play within the app session.
class SessionTracker {
  SessionTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  int _continuousMs = 0;
  DateTime? _last;

  int get continuousMs => _continuousMs;

  void addPlay(int ms) {
    final now = _clock();
    if (_last != null &&
        now.difference(_last!) >
            Wellbeing.resetGap + Duration(milliseconds: ms)) {
      _continuousMs = 0;
    }
    _continuousMs += ms;
    _last = now;
  }

  bool get needsBreak => _continuousMs >= Wellbeing.breakAfter.inMilliseconds;

  void tookBreak() => _continuousMs = 0;
}
