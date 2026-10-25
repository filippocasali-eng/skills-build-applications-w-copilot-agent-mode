import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/roster.dart';
import '../../game/sim/game_sim.dart';
import '../providers.dart';
import 'trophies.dart';

/// Best results for one level.
class LevelRecord {
  const LevelRecord({
    this.bestScore = 0,
    this.rank = '',
    this.cassettes = 0,
    this.noDeath = false,
    this.allHostages = false,
    this.speedrun = false,
    this.clears = 0,
  });

  factory LevelRecord.fromJson(Map<String, dynamic> j) => LevelRecord(
    bestScore: j['best'] as int? ?? 0,
    rank: j['rank'] as String? ?? '',
    cassettes: j['tapes'] as int? ?? 0,
    noDeath: j['noDeath'] as bool? ?? false,
    allHostages: j['hostages'] as bool? ?? false,
    speedrun: j['speedrun'] as bool? ?? false,
    clears: j['clears'] as int? ?? 0,
  );

  final int bestScore;
  final String rank;

  /// Bit mask of the 3 cassettes found.
  final int cassettes;
  final bool noDeath, allHostages, speedrun;
  final int clears;

  bool get cleared => clears > 0;
  int get cassetteCount =>
      (cassettes & 1) + (cassettes >> 1 & 1) + (cassettes >> 2 & 1);

  Map<String, Object> toJson() => {
    'best': bestScore,
    'rank': rank,
    'tapes': cassettes,
    'noDeath': noDeath,
    'hostages': allHostages,
    'speedrun': speedrun,
    'clears': clears,
  };

  static const _order = 'DCBAS';

  static String betterRank(String a, String b) =>
      _order.indexOf(a) >= _order.indexOf(b) ? a : b;
}

class HighScore {
  const HighScore(this.initials, this.score, this.mode);

  factory HighScore.fromJson(Map<String, dynamic> j) => HighScore(
    j['i'] as String? ?? '???',
    j['s'] as int? ?? 0,
    j['m'] as String? ?? 'arcade',
  );

  final String initials;
  final int score;
  final String mode;

  Map<String, Object> toJson() => {'i': initials, 's': score, 'm': mode};
}

/// What a finished level gave the player (shown on the results screen).
class LevelRewards {
  const LevelRewards({
    required this.tokens,
    required this.xp,
    required this.creditEarned,
    required this.newRecord,
    required this.unlocks,
    required this.trophies,
  });

  final int tokens;
  final int xp;
  final bool creditEarned;
  final bool newRecord;
  final List<String> unlocks;
  final List<Trophy> trophies;
}

/// Persistent player progress (campaign, currencies, unlocks, records).
class Progress {
  const Progress({
    this.levels = const {},
    this.credits = 5,
    this.tokens = 0,
    this.xp = 0,
    this.heroes = const {'roxy', 'brutus'},
    this.selectedHero = 'roxy',
    this.trophies = const {},
    this.highScores = const [],
    this.upgrades = const {},
    this.skins = const {},
    this.cheats = const {},
    this.stats = const {},
  });

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
    levels: {
      for (final e
          in (j['levels'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: LevelRecord.fromJson(e.value as Map<String, dynamic>),
    },
    credits: j['credits'] as int? ?? 5,
    tokens: j['tokens'] as int? ?? 0,
    xp: j['xp'] as int? ?? 0,
    heroes: {
      for (final h
          in (j['heroes'] as List<dynamic>? ?? const ['roxy', 'brutus']))
        h as String,
    },
    selectedHero: j['hero'] as String? ?? 'roxy',
    trophies: {
      for (final t in (j['trophies'] as List<dynamic>? ?? const []))
        t as String,
    },
    highScores: [
      for (final h in (j['scores'] as List<dynamic>? ?? const []))
        HighScore.fromJson(h as Map<String, dynamic>),
    ],
    upgrades: {
      for (final e
          in (j['upgrades'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as int,
    },
    skins: {
      for (final s in (j['skins'] as List<dynamic>? ?? const [])) s as String,
    },
    cheats: {
      for (final s in (j['cheats'] as List<dynamic>? ?? const [])) s as String,
    },
    stats: {
      for (final e in (j['stats'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as int,
    },
  );

  final Map<String, LevelRecord> levels;

  /// Credits for CONTINUE (earned by playing; capped at [maxCredits]).
  final int credits;

  /// "Gettoni": soft currency for the Workshop.
  final int tokens;
  final int xp;
  final Set<String> heroes;
  final String selectedHero;
  final Set<String> trophies;
  final List<HighScore> highScores;

  /// Workshop upgrade levels by id (see workshop).
  final Map<String, int> upgrades;
  final Set<String> skins;
  final Set<String> cheats;

  /// Lifetime counters (kills, deaths, hostages, levels, playSeconds...).
  final Map<String, int> stats;

  static const maxCredits = 9;

  Map<String, Object> toJson() => {
    'levels': {for (final e in levels.entries) e.key: e.value.toJson()},
    'credits': credits,
    'tokens': tokens,
    'xp': xp,
    'heroes': heroes.toList(),
    'hero': selectedHero,
    'trophies': trophies.toList(),
    'scores': [for (final h in highScores) h.toJson()],
    'upgrades': upgrades,
    'skins': skins.toList(),
    'cheats': cheats.toList(),
    'stats': stats,
  };

  Progress copyWith({
    Map<String, LevelRecord>? levels,
    int? credits,
    int? tokens,
    int? xp,
    Set<String>? heroes,
    String? selectedHero,
    Set<String>? trophies,
    List<HighScore>? highScores,
    Map<String, int>? upgrades,
    Set<String>? skins,
    Set<String>? cheats,
    Map<String, int>? stats,
  }) => Progress(
    levels: levels ?? this.levels,
    credits: credits ?? this.credits,
    tokens: tokens ?? this.tokens,
    xp: xp ?? this.xp,
    heroes: heroes ?? this.heroes,
    selectedHero: selectedHero ?? this.selectedHero,
    trophies: trophies ?? this.trophies,
    highScores: highScores ?? this.highScores,
    upgrades: upgrades ?? this.upgrades,
    skins: skins ?? this.skins,
    cheats: cheats ?? this.cheats,
    stats: stats ?? this.stats,
  );

  // ----------------------------------------------------------- derived --

  LevelRecord record(String id) => levels[id] ?? const LevelRecord();

  bool cleared(String id) => record(id).cleared;

  /// Campaign is linear: level n unlocks when n-1 is cleared.
  bool unlocked(List<String> campaignOrder, String id) {
    final i = campaignOrder.indexOf(id);
    return i <= 0 || cleared(campaignOrder[i - 1]);
  }

  /// Arcade difficulty and Arcade Mode unlock after World 1.
  bool get arcadeUnlocked => cleared('w1_l5');
  bool get bossRushUnlocked => cleared('w3_l5');
  bool get campaignComplete => cleared('w3_l5');

  int get totalCassettes =>
      levels.values.fold(0, (sum, r) => sum + r.cassetteCount);

  /// Pilot rank grows with the square root of XP.
  int get pilotRank => 1 + math.sqrt(xp / 150).floor();
  int xpForRank(int r) => (r - 1) * (r - 1) * 150;

  int stat(String k) => stats[k] ?? 0;

  bool isHighScore(int score, String mode) {
    final list = highScores.where((h) => h.mode == mode).toList();
    return score > 0 && (list.length < 10 || score > list.last.score);
  }

  List<HighScore> scoresFor(String mode) =>
      highScores.where((h) => h.mode == mode).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
}

class ProgressController extends Notifier<Progress> {
  @override
  Progress build() =>
      Progress.fromJson(ref.watch(saveStoreProvider).section('progress'));

  Future<void> _save(Progress p) async {
    state = p;
    final store = ref.read(saveStoreProvider);
    store.section('progress')
      ..clear()
      ..addAll(p.toJson());
    await store.flush();
  }

  Future<void> set(Progress Function(Progress p) change) =>
      _save(change(state));

  Future<bool> spendCredit() async {
    if (state.credits <= 0) return false;
    await _save(state.copyWith(credits: state.credits - 1));
    return true;
  }

  Future<void> addCredits(int n) => _save(
    state.copyWith(credits: math.min(Progress.maxCredits, state.credits + n)),
  );

  Future<void> addTokens(int n) =>
      _save(state.copyWith(tokens: math.max(0, state.tokens + n)));

  Future<void> selectHero(Commando h) =>
      _save(state.copyWith(selectedHero: h.atlas));

  Future<void> addHighScore(String initials, int score, String mode) {
    final list = [...state.highScores, HighScore(initials, score, mode)];
    final byMode = <String, List<HighScore>>{};
    for (final h in list) {
      (byMode[h.mode] ??= []).add(h);
    }
    final kept = <HighScore>[
      for (final l in byMode.values)
        ...(l..sort((a, b) => b.score.compareTo(a.score))).take(10),
    ];
    return _save(state.copyWith(highScores: kept));
  }

  /// Records a finished level and returns what it earned.
  Future<LevelRewards> recordLevel({
    required String levelId,
    required LevelResult result,
    required int parTime,
    required int kills,
    bool earnsCredit = true,
  }) async {
    final p = state;
    final old = p.record(levelId);
    final rec = LevelRecord(
      bestScore: math.max(old.bestScore, result.total),
      rank: old.rank.isEmpty
          ? result.rank
          : LevelRecord.betterRank(old.rank, result.rank),
      cassettes: old.cassettes | result.cassettes,
      noDeath: old.noDeath || result.medalNoDeath,
      allHostages: old.allHostages || result.medalAllHostages,
      speedrun: old.speedrun || result.medalSpeedrun(parTime),
      clears: old.clears + 1,
    );
    final rankBonus =
        {'S': 60, 'A': 40, 'B': 25, 'C': 15, 'D': 8}[result.rank] ?? 0;
    final tokens = result.total ~/ 1000 + rankBonus;
    final xp = result.total ~/ 50;
    final stats = {...p.stats};
    void inc(String k, int v) => stats[k] = (stats[k] ?? 0) + v;
    inc('kills', kills);
    inc('deaths', result.deaths);
    inc('hostages', result.hostagesFreed);
    inc('levels', 1);
    inc('playSeconds', result.seconds);
    if (result.rank == 'S') inc('sRanks', 1);

    final levels = {...p.levels, levelId: rec};
    var next = p.copyWith(
      levels: levels,
      tokens: p.tokens + tokens,
      xp: p.xp + xp,
      credits: earnsCredit
          ? math.min(Progress.maxCredits, p.credits + 1)
          : p.credits,
      stats: stats,
    );

    // Unlocks.
    final unlocks = <String>[];
    if (levelId == 'w1_l5' && !old.cleared) unlocks.add('arcade');
    if (levelId == 'w2_l5' && !next.heroes.contains('nyx')) {
      next = next.copyWith(heroes: {...next.heroes, 'nyx'});
      unlocks.add('hero:nyx');
    }
    if (levelId == 'w3_l5' && !old.cleared) {
      unlocks.add('bossrush');
      if (!next.heroes.contains('doc')) {
        next = next.copyWith(heroes: {...next.heroes, 'doc'});
        unlocks.add('hero:doc');
      }
    }

    // Trophies.
    final earned = Trophies.check(
      next,
      lastResult: result,
      levelId: levelId,
    ).where((t) => !next.trophies.contains(t.id)).toList();
    if (earned.isNotEmpty) {
      next = next.copyWith(
        trophies: {...next.trophies, for (final t in earned) t.id},
      );
    }
    await _save(next);
    return LevelRewards(
      tokens: tokens,
      xp: xp,
      creditEarned: earnsCredit && p.credits < Progress.maxCredits,
      newRecord: result.total > old.bestScore,
      unlocks: unlocks,
      trophies: earned,
    );
  }

  Future<List<Trophy>> unlockTrophy(String id) async {
    if (state.trophies.contains(id)) return const [];
    await _save(state.copyWith(trophies: {...state.trophies, id}));
    return [Trophies.byId(id)];
  }
}

final progressProvider = NotifierProvider<ProgressController, Progress>(
  ProgressController.new,
);
