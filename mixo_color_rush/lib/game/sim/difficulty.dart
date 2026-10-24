import 'dart:math' as math;

/// Tunable parameters that shape a run. Produced by the AdaptiveDirector
/// and fixed for the whole run, so a seed + params always yields the same
/// track.
class DifficultyParams {
  const DifficultyParams({
    this.laneCount = 3,
    this.baseSpeed = 9,
    this.maxSpeed = 22,
    this.speedRampDistance = 1800,
    this.gapSeconds = 1.15,
    this.minGapSeconds = 0.6,
    this.emptyLaneChance = 0.45,
    this.dropChance = 0.25,
    this.obstacleChance = 0.08,
    this.mixing = false,
    this.mixDepth = 1,
    this.specials = false,
    this.jumpEnabled = false,
    this.diveEnabled = false,
  });

  factory DifficultyParams.fromJson(Map<String, Object?> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    const def = DifficultyParams();
    return DifficultyParams(
      laneCount: (j['laneCount'] as num?)?.toInt() ?? def.laneCount,
      baseSpeed: d('baseSpeed', def.baseSpeed),
      maxSpeed: d('maxSpeed', def.maxSpeed),
      speedRampDistance: d('speedRampDistance', def.speedRampDistance),
      gapSeconds: d('gapSeconds', def.gapSeconds),
      minGapSeconds: d('minGapSeconds', def.minGapSeconds),
      emptyLaneChance: d('emptyLaneChance', def.emptyLaneChance),
      dropChance: d('dropChance', def.dropChance),
      obstacleChance: d('obstacleChance', def.obstacleChance),
      mixing: j['mixing'] as bool? ?? def.mixing,
      mixDepth: (j['mixDepth'] as num?)?.toInt() ?? def.mixDepth,
      specials: j['specials'] as bool? ?? def.specials,
      jumpEnabled: j['jumpEnabled'] as bool? ?? def.jumpEnabled,
      diveEnabled: j['diveEnabled'] as bool? ?? def.diveEnabled,
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

  /// Probability that a gate row leaves one lane free.
  final double emptyLaneChance;
  final double dropChance;
  final double obstacleChance;

  /// Whether drops mix (false: drops replace Mixo's colour).
  final bool mixing;

  /// 1: only primary gates; 2: secondary gates appear; 3: chained mixes.
  final int mixDepth;

  /// White / rainbow / invert drops.
  final bool specials;
  final bool jumpEnabled;
  final bool diveEnabled;

  Map<String, Object?> toJson() => {
    'laneCount': laneCount,
    'baseSpeed': baseSpeed,
    'maxSpeed': maxSpeed,
    'speedRampDistance': speedRampDistance,
    'gapSeconds': gapSeconds,
    'minGapSeconds': minGapSeconds,
    'emptyLaneChance': emptyLaneChance,
    'dropChance': dropChance,
    'obstacleChance': obstacleChance,
    'mixing': mixing,
    'mixDepth': mixDepth,
    'specials': specials,
    'jumpEnabled': jumpEnabled,
    'diveEnabled': diveEnabled,
  };

  /// Ramp progress 0..1 at track distance [d].
  double rampAt(double d) => 1 - math.exp(-d / speedRampDistance);

  /// Track speed (units/s) at distance [d], before temporary boosts.
  double speedAt(double d) => baseSpeed + (maxSpeed - baseSpeed) * rampAt(d);

  /// Reaction time between rows at distance [d].
  double gapAt(double d) =>
      gapSeconds + (minGapSeconds - gapSeconds) * rampAt(d);
}
