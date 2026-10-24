import 'dart:math' as math;

/// Tunable parameters that shape a run. Produced by the AdaptiveDirector
/// and fixed for the whole run, so a seed + params always yields the same
/// track (live adaptation, when enabled, only depends on recorded inputs).
class DifficultyParams {
  const DifficultyParams({
    this.laneCount = 3,
    this.baseSpeed = 9,
    this.maxSpeed = 20,
    this.speedRampDistance = 1800,
    this.gapSeconds = 1.2,
    this.minGapSeconds = 0.75,
    this.maxTier = 1,
    this.targetTier = 0.5,
    this.strict = true,
    this.liveAdapt = true,
    this.drops = true,
    this.obstacles = true,
    this.mixing = false,
    this.mixDepth = 1,
    this.specials = false,
    this.jumpEnabled = false,
    this.diveEnabled = false,
    this.finishDistance = 0,
    this.practice = false,
    this.focus = '',
  });

  factory DifficultyParams.fromJson(Map<String, Object?> j) {
    const def = DifficultyParams();
    double d(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    bool b(String k, bool v) => j[k] as bool? ?? v;
    return DifficultyParams(
      laneCount: i('laneCount', def.laneCount),
      baseSpeed: d('baseSpeed', def.baseSpeed),
      maxSpeed: d('maxSpeed', def.maxSpeed),
      speedRampDistance: d('speedRampDistance', def.speedRampDistance),
      gapSeconds: d('gapSeconds', def.gapSeconds),
      minGapSeconds: d('minGapSeconds', def.minGapSeconds),
      maxTier: i('maxTier', def.maxTier),
      targetTier: d('targetTier', def.targetTier),
      strict: b('strict', def.strict),
      liveAdapt: b('liveAdapt', def.liveAdapt),
      drops: b('drops', def.drops),
      obstacles: b('obstacles', def.obstacles),
      mixing: b('mixing', def.mixing),
      mixDepth: i('mixDepth', def.mixDepth),
      specials: b('specials', def.specials),
      jumpEnabled: b('jumpEnabled', def.jumpEnabled),
      diveEnabled: b('diveEnabled', def.diveEnabled),
      finishDistance: d('finishDistance', def.finishDistance),
      practice: b('practice', def.practice),
      focus: j['focus'] as String? ?? def.focus,
    );
  }

  final int laneCount;
  final double baseSpeed;
  final double maxSpeed;
  final double speedRampDistance;

  /// Seconds between consecutive rows at the start of the run.
  final double gapSeconds;

  /// Gap reached at full speed ramp.
  final double minGapSeconds;

  /// Highest pattern tier that may appear, and the preferred one.
  final int maxTier;
  final double targetTier;

  /// Strict: every colour Mixo may have must have a damage-free path.
  final bool strict;

  /// Whether the generator reacts to the current run's success rate.
  final bool liveAdapt;

  final bool drops;
  final bool obstacles;

  /// Whether drops mix (false: drops replace Mixo's colour).
  final bool mixing;

  /// 1: decoy gates use primaries only; 2+: secondaries too.
  final int mixDepth;

  /// White / rainbow / invert drops.
  final bool specials;
  final bool jumpEnabled;
  final bool diveEnabled;

  /// > 0: the run is completed when Mixo reaches this distance (Academy).
  final double finishDistance;

  /// Practice: mistakes never cost hearts (onboarding).
  final bool practice;

  /// Comma-separated pattern id prefixes to favour (Academy lessons).
  final String focus;

  DifficultyParams copyWith({
    int? laneCount,
    double? baseSpeed,
    double? maxSpeed,
    double? gapSeconds,
    double? minGapSeconds,
    int? maxTier,
    double? targetTier,
    bool? strict,
    bool? liveAdapt,
    bool? drops,
    bool? obstacles,
    bool? mixing,
    int? mixDepth,
    bool? specials,
    bool? jumpEnabled,
    bool? diveEnabled,
    double? finishDistance,
    bool? practice,
    String? focus,
  }) => DifficultyParams(
    laneCount: laneCount ?? this.laneCount,
    baseSpeed: baseSpeed ?? this.baseSpeed,
    maxSpeed: maxSpeed ?? this.maxSpeed,
    speedRampDistance: speedRampDistance,
    gapSeconds: gapSeconds ?? this.gapSeconds,
    minGapSeconds: minGapSeconds ?? this.minGapSeconds,
    maxTier: maxTier ?? this.maxTier,
    targetTier: targetTier ?? this.targetTier,
    strict: strict ?? this.strict,
    liveAdapt: liveAdapt ?? this.liveAdapt,
    drops: drops ?? this.drops,
    obstacles: obstacles ?? this.obstacles,
    mixing: mixing ?? this.mixing,
    mixDepth: mixDepth ?? this.mixDepth,
    specials: specials ?? this.specials,
    jumpEnabled: jumpEnabled ?? this.jumpEnabled,
    diveEnabled: diveEnabled ?? this.diveEnabled,
    finishDistance: finishDistance ?? this.finishDistance,
    practice: practice ?? this.practice,
    focus: focus ?? this.focus,
  );

  Map<String, Object?> toJson() => {
    'laneCount': laneCount,
    'baseSpeed': baseSpeed,
    'maxSpeed': maxSpeed,
    'speedRampDistance': speedRampDistance,
    'gapSeconds': gapSeconds,
    'minGapSeconds': minGapSeconds,
    'maxTier': maxTier,
    'targetTier': targetTier,
    'strict': strict,
    'liveAdapt': liveAdapt,
    'drops': drops,
    'obstacles': obstacles,
    'mixing': mixing,
    'mixDepth': mixDepth,
    'specials': specials,
    'jumpEnabled': jumpEnabled,
    'diveEnabled': diveEnabled,
    'finishDistance': finishDistance,
    'practice': practice,
    'focus': focus,
  };

  /// Ramp progress 0..1 at track distance [d].
  double rampAt(double d) => 1 - math.exp(-d / speedRampDistance);

  /// Track speed (units/s) at distance [d], before temporary boosts.
  double speedAt(double d) => baseSpeed + (maxSpeed - baseSpeed) * rampAt(d);

  /// Reaction time between rows at distance [d].
  double gapAt(double d) =>
      gapSeconds + (minGapSeconds - gapSeconds) * rampAt(d);
}
