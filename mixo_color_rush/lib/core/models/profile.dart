import '../../game/ai/adaptive_director.dart';
import '../../game/sim/replay.dart';
import 'cosmetics.dart';
import 'missions.dart';

/// Generated nickname: animal + adjective + number (localized at display).
/// Never free text: no personal data can be typed in.
class Nickname {
  const Nickname(this.animal, this.adjective, this.number);

  factory Nickname.fromJson(Map<String, Object?> j) =>
      Nickname(j['a']! as int, j['j']! as int, j['n']! as int);

  static const animals = 12;
  static const adjectives = 12;

  final int animal;
  final int adjective;
  final int number;

  Map<String, Object?> toJson() => {'a': animal, 'j': adjective, 'n': number};
}

enum ControlMode { swipe, tapSides }

class Settings {
  Settings({
    this.sound = true,
    this.music = true,
    this.haptics = true,
    this.controlMode = ControlMode.swipe,
    this.symbolsAlways = true,
    this.reduceEffects = false,
    this.localeCode,
  });

  factory Settings.fromJson(Map<String, Object?> j) => Settings(
    sound: j['sound'] as bool? ?? true,
    music: j['music'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    controlMode: ControlMode.values.byName(
      j['controlMode'] as String? ?? 'swipe',
    ),
    symbolsAlways: j['symbolsAlways'] as bool? ?? true,
    reduceEffects: j['reduceEffects'] as bool? ?? false,
    localeCode: j['localeCode'] as String?,
  );

  bool sound;
  bool music;
  bool haptics;
  ControlMode controlMode;
  bool symbolsAlways;

  /// Accessibility: no screen shake, no slow-motion, fewer particles.
  bool reduceEffects;

  /// null = follow the device.
  String? localeCode;

  Map<String, Object?> toJson() => {
    'sound': sound,
    'music': music,
    'haptics': haptics,
    'controlMode': controlMode.name,
    'symbolsAlways': symbolsAlways,
    'reduceEffects': reduceEffects,
    'localeCode': localeCode,
  };
}

/// Settings behind the parental gate.
class ParentSettings {
  ParentSettings({this.dailyLimitMinutes = 0, this.purchasesEnabled = true});

  factory ParentSettings.fromJson(Map<String, Object?> j) => ParentSettings(
    dailyLimitMinutes: j['dailyLimitMinutes'] as int? ?? 0,
    purchasesEnabled: j['purchasesEnabled'] as bool? ?? true,
  );

  /// 0 = no limit.
  int dailyLimitMinutes;
  bool purchasesEnabled;

  Map<String, Object?> toJson() => {
    'dailyLimitMinutes': dailyLimitMinutes,
    'purchasesEnabled': purchasesEnabled,
  };
}

class Stats {
  Stats();

  factory Stats.fromJson(Map<String, Object?> j) {
    int i(String k) => j[k] as int? ?? 0;
    return Stats()
      ..runs = i('runs')
      ..totalTimeMs = i('totalTimeMs')
      ..bestScore = i('bestScore')
      ..bestCombo = i('bestCombo')
      ..bestMultiplier = i('bestMultiplier')
      ..longestRunMs = i('longestRunMs')
      ..gates = i('gates')
      ..drops = i('drops')
      ..nearMisses = i('nearMisses')
      ..jumps = i('jumps')
      ..mixGates = i('mixGates')
      ..dailyPlays = i('dailyPlays')
      ..ghostWins = i('ghostWins')
      ..okByColor = [
        ...(j['okByColor'] as List<Object?>? ?? List.filled(7, 0)).cast<int>(),
      ];
  }

  int runs = 0;
  int totalTimeMs = 0;
  int bestScore = 0;
  int bestCombo = 0;
  int bestMultiplier = 1;
  int longestRunMs = 0;
  int gates = 0;
  int drops = 0;
  int nearMisses = 0;
  int jumps = 0;
  int mixGates = 0;
  int dailyPlays = 0;
  int ghostWins = 0;
  List<int> okByColor = List.filled(7, 0);

  Map<String, Object?> toJson() => {
    'runs': runs,
    'totalTimeMs': totalTimeMs,
    'bestScore': bestScore,
    'bestCombo': bestCombo,
    'bestMultiplier': bestMultiplier,
    'longestRunMs': longestRunMs,
    'gates': gates,
    'drops': drops,
    'nearMisses': nearMisses,
    'jumps': jumps,
    'mixGates': mixGates,
    'dailyPlays': dailyPlays,
    'ghostWins': ghostWins,
    'okByColor': okByColor,
  };
}

class DailyChallengeState {
  DailyChallengeState({this.date = '', this.bestScore = 0, this.plays = 0});

  factory DailyChallengeState.fromJson(Map<String, Object?> j) =>
      DailyChallengeState(
        date: j['date'] as String? ?? '',
        bestScore: j['bestScore'] as int? ?? 0,
        plays: j['plays'] as int? ?? 0,
      );

  String date;
  int bestScore;
  int plays;

  Map<String, Object?> toJson() => {
    'date': date,
    'bestScore': bestScore,
    'plays': plays,
  };
}

/// Everything saved on the device. No personal data.
class PlayerProfile {
  PlayerProfile({
    required this.nickname,
    required this.skill,
    Settings? settings,
    ParentSettings? parent,
    Stats? stats,
    Set<String>? unlocked,
    Set<String>? owned,
    Set<String>? achievements,
    List<Mission>? missions,
    Map<int, int>? academyStars,
    DailyChallengeState? daily,
    this.level = 1,
    this.xp = 0,
    this.stars = 0,
    this.skin = Catalog.defaultSkin,
    this.trail = Catalog.defaultTrail,
    this.theme = Catalog.defaultTheme,
    this.missionCounter = 0,
    this.onboardingDone = false,
    this.ghostReplay,
    this.ghostScore = 0,
    this.playDate = '',
    this.playMsToday = 0,
    this.limitExtensionMinutes = 0,
  }) : settings = settings ?? Settings(),
       parent = parent ?? ParentSettings(),
       stats = stats ?? Stats(),
       unlocked =
           unlocked ??
           {Catalog.defaultSkin, Catalog.defaultTrail, Catalog.defaultTheme},
       owned = owned ?? {},
       achievements = achievements ?? {},
       missions = missions ?? [],
       academyStars = academyStars ?? {},
       daily = daily ?? DailyChallengeState();

  static const schemaVersion = 1;

  Nickname nickname;
  SkillState skill;
  Settings settings;
  ParentSettings parent;
  Stats stats;
  int level;
  int xp;
  int stars;

  /// Cosmetic ids the player can equip.
  final Set<String> unlocked;

  /// Store product ids owned (restored from Google Play).
  final Set<String> owned;

  final Set<String> achievements;
  final List<Mission> missions;
  int missionCounter;

  /// Academy lesson index → best stars (1..3).
  final Map<int, int> academyStars;
  DailyChallengeState daily;

  String skin;
  String trail;
  String theme;

  bool onboardingDone;

  /// Best "Sfida Fantasma" run.
  Replay? ghostReplay;
  int ghostScore;

  /// Daily play-time accounting (parent limit).
  String playDate;
  int playMsToday;
  int limitExtensionMinutes;

  int get bestScore => stats.bestScore;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'nickname': nickname.toJson(),
    'skill': skill.toJson(),
    'settings': settings.toJson(),
    'parent': parent.toJson(),
    'stats': stats.toJson(),
    'level': level,
    'xp': xp,
    'stars': stars,
    'unlocked': unlocked.toList()..sort(),
    'owned': owned.toList()..sort(),
    'achievements': achievements.toList()..sort(),
    'missions': [for (final m in missions) m.toJson()],
    'missionCounter': missionCounter,
    'academyStars': {for (final e in academyStars.entries) '${e.key}': e.value},
    'daily': daily.toJson(),
    'skin': skin,
    'trail': trail,
    'theme': theme,
    'onboardingDone': onboardingDone,
    'ghostReplay': ghostReplay?.toJson(),
    'ghostScore': ghostScore,
    'playDate': playDate,
    'playMsToday': playMsToday,
    'limitExtensionMinutes': limitExtensionMinutes,
  };

  /// Parses the current schema. Older schemas go through
  /// `ProfileRepository.migrate` first.
  factory PlayerProfile.fromJson(Map<String, Object?> j) {
    Map<String, Object?> m(String k) =>
        (j[k] as Map<Object?, Object?>? ?? const {}).cast();
    Set<String> set(String k) => {
      ...(j[k] as List<Object?>? ?? const []).cast<String>(),
    };
    final ghost = j['ghostReplay'] as Map<Object?, Object?>?;
    return PlayerProfile(
      nickname: Nickname.fromJson(m('nickname')),
      skill: SkillState.fromJson(m('skill')),
      settings: Settings.fromJson(m('settings')),
      parent: ParentSettings.fromJson(m('parent')),
      stats: Stats.fromJson(m('stats')),
      level: j['level'] as int? ?? 1,
      xp: j['xp'] as int? ?? 0,
      stars: j['stars'] as int? ?? 0,
      unlocked: set('unlocked'),
      owned: set('owned'),
      achievements: set('achievements'),
      missions: [
        for (final x in (j['missions'] as List<Object?>? ?? const []))
          Mission.fromJson((x! as Map<Object?, Object?>).cast()),
      ],
      missionCounter: j['missionCounter'] as int? ?? 0,
      academyStars: {
        for (final e in m('academyStars').entries)
          int.parse(e.key): e.value! as int,
      },
      daily: DailyChallengeState.fromJson(m('daily')),
      skin: j['skin'] as String? ?? Catalog.defaultSkin,
      trail: j['trail'] as String? ?? Catalog.defaultTrail,
      theme: j['theme'] as String? ?? Catalog.defaultTheme,
      onboardingDone: j['onboardingDone'] as bool? ?? false,
      ghostReplay: ghost == null ? null : Replay.fromJson(ghost.cast()),
      ghostScore: j['ghostScore'] as int? ?? 0,
      playDate: j['playDate'] as String? ?? '',
      playMsToday: j['playMsToday'] as int? ?? 0,
      limitExtensionMinutes: j['limitExtensionMinutes'] as int? ?? 0,
    );
  }
}
