import '../../core/campaign.dart';
import '../../game/play_config.dart';
import '../../game/roster.dart';
import '../../game/sim/balance.dart';

/// Weekly-challenge modifiers (remixes of a campaign level).
enum WeeklyModifier { flameOnly, ricochetOnly, heavyGravity, lowGravity }

class Weekly {
  /// ISO-ish week number since an epoch (Monday-based).
  static int weekIndex(DateTime now) {
    final epoch = DateTime.utc(2026, 1, 5); // a Monday
    return now.toUtc().difference(epoch).inDays ~/ 7;
  }

  static DateTime weekEnd(DateTime now) {
    final epoch = DateTime.utc(2026, 1, 5);
    return epoch.add(Duration(days: (weekIndex(now) + 1) * 7));
  }

  static WeeklyModifier modifier(int week) =>
      WeeklyModifier.values[week % WeeklyModifier.values.length];

  /// Non-boss level for this week, deterministic.
  static CampaignEntry level(Campaign c, int week) {
    final pool = c.entries.where((e) => !e.boss).toList();
    return pool[(week * 7 + 3) % pool.length];
  }

  static Balance balanceFor(WeeklyModifier m, Balance b) {
    final j = b.toJson();
    switch (m) {
      case WeeklyModifier.heavyGravity:
        // Same jump apex, snappier arc: v' = v*sqrt(k), g' = g*k.
        j['gravity'] = b.gravity * 1.6;
        j['jumpSpeed'] = b.jumpSpeed * 1.2649;
        j['maxFall'] = b.maxFall * 1.3;
      case WeeklyModifier.lowGravity:
        j['gravity'] = b.gravity * 0.55;
        j['jumpSpeed'] = b.jumpSpeed * 0.7416;
      default:
        break;
    }
    return Balance.fromJson(j);
  }

  static WeaponKind? weaponFor(WeeklyModifier m) => switch (m) {
    WeeklyModifier.flameOnly => WeaponKind.flame,
    WeeklyModifier.ricochetOnly => WeaponKind.ricochet,
    _ => null,
  };
}

/// A sequence of levels played back to back (campaign plays one).
class RunSpec {
  RunSpec({
    required this.mode,
    required this.levels,
    required this.difficulty,
    required this.hero,
    this.weekly,
    this.week = 0,
    this.arcadeCredits = 3,
  });

  final GameMode mode;
  final List<CampaignEntry> levels;
  final Difficulty difficulty;
  final Commando hero;
  final WeeklyModifier? weekly;
  final int week;

  /// Credits for the whole run in Arcade Mode (like at the bar).
  int arcadeCredits;

  int index = 0;
  int totalScore = 0;
  int totalDeaths = 0;

  CampaignEntry get current => levels[index];
  bool get isLast => index >= levels.length - 1;
  bool get ranked => mode != GameMode.campaign;

  /// Score table for initials (campaign has none).
  String? get scoreTable => switch (mode) {
    GameMode.arcade => 'arcade',
    GameMode.bossRush => 'bossrush',
    GameMode.weekly => 'weekly$week',
    _ => null,
  };

  int get seed => mode == GameMode.weekly ? 7000 + week : 1994 + index;
}
