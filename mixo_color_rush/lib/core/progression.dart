import '../game/ai/adaptive_director.dart';
import '../game/ai/coach.dart';
import '../game/sim/rng.dart';
import 'models/achievements.dart';
import 'models/cosmetics.dart';
import 'models/missions.dart';
import 'models/profile.dart';
import 'models/run_result.dart';

/// What a finished run gave the player (shown on the results screen).
class RunRewards {
  RunRewards({
    required this.xpGained,
    required this.levelBefore,
    required this.xpBefore,
    required this.levelAfter,
    required this.xpAfter,
    required this.starsGained,
    required this.isRecord,
    required this.tip,
    required this.newUnlocks,
    required this.completedMissions,
    required this.newAchievements,
    required this.ratingDelta,
  });

  final int xpGained;
  final int levelBefore;
  final int xpBefore;
  final int levelAfter;
  final int xpAfter;
  final int starsGained;
  final bool isRecord;
  final CoachTip tip;
  final List<String> newUnlocks;
  final List<Mission> completedMissions;
  final List<Achievement> newAchievements;
  final double ratingDelta;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Pure progression rules: XP, levels, stars, missions, trophies.
abstract final class Progression {
  static const int maxLevel = 50;
  static const int activeMissions = 3;

  /// XP needed to go from [level] to level + 1.
  static int xpToNext(int level) => 100 + (level - 1) * 50;

  /// XP for a run: always > 0, even for a lost run.
  static int xpForRun(RunResult r) =>
      (10 + r.score ~/ 40 + r.gatesOk * 2 + r.durationMs ~/ 4000).clamp(
        10,
        600,
      );

  static int starsForRun(RunResult r) =>
      (r.score ~/ 500).clamp(0, 20) + (r.completed ? 3 : 0);

  static PlayerProfile newProfile(int seed, AdaptiveDirector director) {
    final rng = Rng(seed);
    return PlayerProfile(
      nickname: Nickname(
        rng.nextInt(Nickname.animals),
        rng.nextInt(Nickname.adjectives),
        10 + rng.nextInt(90),
      ),
      skill: director.newSkill(),
    );
  }

  static bool mixingKnown(PlayerProfile p) =>
      p.skill.seenMechanics.contains(Mechanic.mixing);

  static void ensureMissions(PlayerProfile p, {required int jumpLevel}) {
    while (p.missions.length < activeMissions) {
      p.missions.add(
        MissionFactory.create(
          p.missionCounter++,
          level: p.level,
          mixing: mixingKnown(p),
          jump: p.level >= jumpLevel,
          avoid: {for (final m in p.missions) m.kind},
        ),
      );
    }
  }

  /// Items unlocked by reaching [level].
  static Iterable<CosmeticItem> levelItems(int level) => Catalog.items.where(
    (i) => i.unlock == UnlockKind.level && i.level == level,
  );

  /// Grants every product item for owned products (purchase or restore).
  static List<String> grantProduct(PlayerProfile p, String productId) {
    p.owned.add(productId);
    final added = <String>[];
    for (final item in Catalog.ofProduct(productId)) {
      if (p.unlocked.add(item.id)) added.add(item.id);
    }
    return added;
  }

  static RunRewards applyRun(
    PlayerProfile p,
    RunResult r,
    AdaptiveDirector director, {
    bool jumpEnabled = false,
  }) {
    final s = p.stats;
    final isRecord = r.mode == GameMode.free && r.score > s.bestScore;
    s
      ..runs += 1
      ..totalTimeMs += r.durationMs
      ..gates += r.gatesOk
      ..drops += r.dropsTaken
      ..nearMisses += r.nearMisses
      ..jumps += r.obstaclesJumped
      ..mixGates += r.mixGatesOk;
    if (r.score > s.bestScore) s.bestScore = r.score;
    if (r.maxCombo > s.bestCombo) s.bestCombo = r.maxCombo;
    if (r.maxMultiplier > s.bestMultiplier) s.bestMultiplier = r.maxMultiplier;
    if (r.durationMs > s.longestRunMs) s.longestRunMs = r.durationMs;
    for (var i = 0; i < s.okByColor.length && i < r.okByGateColor.length; i++) {
      s.okByColor[i] += r.okByGateColor[i];
    }
    if (r.mode == GameMode.daily) s.dailyPlays += 1;

    var ratingDelta = 0.0;
    if (r.mode == GameMode.free) ratingDelta = director.recordRun(p.skill, r);

    // XP and levels.
    final levelBefore = p.level;
    final xpBefore = p.xp;
    final xp = xpForRun(r);
    var stars = starsForRun(r);
    final unlocks = <String>[];
    p.xp += xp;
    while (p.level < maxLevel && p.xp >= xpToNext(p.level)) {
      p.xp -= xpToNext(p.level);
      p.level++;
      stars += 10;
      for (final item in levelItems(p.level)) {
        if (p.unlocked.add(item.id)) unlocks.add(item.id);
      }
    }

    // Missions (renew on completion only).
    ensureMissions(p, jumpLevel: director.jumpLevel);
    final completed = <Mission>[];
    for (var i = 0; i < p.missions.length; i++) {
      if (p.missions[i].apply(r)) {
        completed.add(p.missions[i]);
        stars += p.missions[i].reward;
      }
    }
    p.missions.removeWhere((m) => m.done);
    ensureMissions(p, jumpLevel: director.jumpLevel);

    p.stars += stars;

    // Trophies (may grant stars, which may not unlock more trophies).
    final newAch = checkAchievements(p);

    return RunRewards(
      xpGained: xp,
      levelBefore: levelBefore,
      xpBefore: xpBefore,
      levelAfter: p.level,
      xpAfter: p.xp,
      starsGained: stars + newAch.fold(0, (a, b) => a + b.reward),
      isRecord: isRecord,
      tip: Coach.tipFor(r, jumpEnabled: jumpEnabled),
      newUnlocks: unlocks,
      completedMissions: completed,
      newAchievements: newAch,
      ratingDelta: ratingDelta,
    );
  }

  static List<Achievement> checkAchievements(PlayerProfile p) {
    final out = <Achievement>[];
    for (final a in Achievement.values) {
      if (!p.achievements.contains(a.name) && a.isMet(p)) {
        p.achievements.add(a.name);
        p.stars += a.reward;
        out.add(a);
      }
    }
    return out;
  }

  /// Buys a stars item. Returns false if not affordable or not for sale.
  static bool buyWithStars(PlayerProfile p, String itemId) {
    final item = Catalog.get(itemId);
    if (item.unlock != UnlockKind.stars || p.unlocked.contains(itemId)) {
      return false;
    }
    if (p.stars < item.price) return false;
    p.stars -= item.price;
    p.unlocked.add(itemId);
    return true;
  }

  static bool equip(PlayerProfile p, String itemId) {
    if (!p.unlocked.contains(itemId)) return false;
    final item = Catalog.get(itemId);
    switch (item.type) {
      case CosmeticType.skin:
        p.skin = itemId;
      case CosmeticType.trail:
        p.trail = itemId;
      case CosmeticType.theme:
        p.theme = itemId;
      case CosmeticType.badge:
        return false;
    }
    return true;
  }
}
