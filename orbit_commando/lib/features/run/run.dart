import '../../core/campaign.dart';
import '../../core/social/challenge.dart';
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
    this.day = 0,
    this.challenge,
  });

  /// Orbit of the Day for [now].
  factory RunSpec.daily(Campaign c, Commando hero, DateTime now) {
    final day = Daily.dayIndex(now);
    final pool = c.entries.where((e) => !e.boss).toList();
    return RunSpec(
      mode: GameMode.daily,
      levels: [pool[Daily.levelSlot(day) % pool.length]],
      difficulty: Difficulty.normal,
      hero: hero,
      weekly: WeeklyModifier.values[Daily.modifier(day) - 1],
      day: day,
    );
  }

  /// Replays a friend's run from a challenge code.
  factory RunSpec.fromChallenge(Campaign c, Challenge ch) => RunSpec(
    mode: GameMode.challenge,
    levels: [c.entries[ch.levelIndex]],
    difficulty: Difficulty.normal,
    hero: Commando.values[ch.hero],
    weekly: ch.modifier == 0 ? null : WeeklyModifier.values[ch.modifier - 1],
    challenge: ch,
  );

  final GameMode mode;
  final List<CampaignEntry> levels;
  final Difficulty difficulty;
  final Commando hero;
  final WeeklyModifier? weekly;
  final int week;
  final int day;

  /// Set when this run answers a friend's challenge code.
  final Challenge? challenge;

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
    GameMode.daily => 'daily$day',
    _ => null,
  };

  /// Modes that race a ghost of the best run.
  bool get ghostMode => mode == GameMode.weekly || mode == GameMode.daily;

  int get seed => switch (mode) {
    GameMode.weekly => 7000 + week,
    GameMode.daily => Daily.seed(day),
    GameMode.challenge => challenge!.seed,
    _ => 1994 + index,
  };

  /// The code a player shares after this run, to dare friends to beat
  /// [score] on exactly the same level, remix and seed.
  Challenge challengeFor(Campaign c, int score) => Challenge(
    levelIndex: c.entries.indexWhere((e) => e.id == current.id),
    modifier: weekly == null ? 0 : weekly!.index + 1,
    seed: seed & 0xFFFF,
    hero: hero.index,
    target: score,
  );
}
