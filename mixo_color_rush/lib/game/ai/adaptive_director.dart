import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/run_result.dart';
import '../sim/difficulty.dart';

/// Gameplay mechanics introduced progressively, each with a 2 s tip.
enum Mechanic {
  drops,
  obstacles,
  mixing,
  secondaryGates,
  specials,
  fiveLanes,
  jump,
  dive,
}

/// Persistent skill estimate (local only).
class SkillState {
  SkillState({
    required this.rating,
    List<RunResult>? recentRuns,
    Set<Mechanic>? seenMechanics,
    this.earlyFailStreak = 0,
  }) : recentRuns = recentRuns ?? [],
       seenMechanics = seenMechanics ?? {};

  factory SkillState.fromJson(Map<String, Object?> j) => SkillState(
    rating: (j['rating']! as num).toDouble(),
    earlyFailStreak: j['earlyFailStreak'] as int? ?? 0,
    recentRuns: [
      for (final r in (j['recentRuns'] as List<Object?>? ?? const []))
        RunResult.fromJson((r! as Map<Object?, Object?>).cast()),
    ],
    seenMechanics: {
      for (final m
          in (j['seenMechanics'] as List<Object?>? ?? const []).cast<String>())
        if (Mechanic.values.any((v) => v.name == m)) Mechanic.values.byName(m),
    },
  );

  double rating;
  final List<RunResult> recentRuns;
  final Set<Mechanic> seenMechanics;
  int earlyFailStreak;

  Map<String, Object?> toJson() => {
    'rating': rating,
    'earlyFailStreak': earlyFailStreak,
    'recentRuns': [for (final r in recentRuns) r.toJson()],
    'seenMechanics': [for (final m in seenMechanics) m.name],
  };
}

/// Parameters for the next run plus the mechanic being introduced (if any).
class RunPlan {
  const RunPlan(this.params, this.introducing);

  final DifficultyParams params;
  final Mechanic? introducing;
}

/// On-device dynamic difficulty adjustment (no data leaves the device).
///
/// Keeps the player in the 70–85 % success "flow zone": a simplified Elo
/// style rating moves after every run and maps to [DifficultyParams] by
/// interpolating the stages of `difficulty_config.json`. Inside a run the
/// generator also adapts chunk by chunk (see `GameSimulation._liveSkill`).
class AdaptiveDirector {
  AdaptiveDirector(this.config);

  factory AdaptiveDirector.fromJsonString(String json) =>
      AdaptiveDirector(jsonDecode(json) as Map<String, Object?>);

  final Map<String, Object?> config;

  Map<String, Object?> get _rating =>
      (config['rating']! as Map<Object?, Object?>).cast();
  double _r(String k) => (_rating[k]! as num).toDouble();

  List<Map<String, Object?>> get _stages => [
    for (final s in config['stages']! as List<Object?>)
      (s! as Map<Object?, Object?>).cast<String, Object?>(),
  ];

  Map<String, Object?> get _unlocks =>
      (config['unlocks']! as Map<Object?, Object?>).cast();
  int get jumpLevel => _unlocks['jumpLevel']! as int;
  int get diveLevel => _unlocks['diveLevel']! as int;

  SkillState newSkill() => SkillState(rating: _r('start'));

  /// Params for a run at [rating], for a player of profile [level].
  DifficultyParams paramsFor(double rating, {int level = 1}) {
    final stages = _stages;
    var lo = stages.first;
    var hi = stages.first;
    for (final s in stages) {
      if ((s['rating']! as num) <= rating) lo = s;
    }
    hi = stages.firstWhere(
      (s) => (s['rating']! as num) > rating,
      orElse: () => stages.last,
    );
    final r0 = (lo['rating']! as num).toDouble();
    final r1 = (hi['rating']! as num).toDouble();
    final t = r1 > r0 ? ((rating - r0) / (r1 - r0)).clamp(0.0, 1.0) : 0.0;
    double lerp(String k) {
      final a = (lo[k]! as num).toDouble();
      final b = (hi[k]! as num).toDouble();
      return a + (b - a) * t;
    }

    return DifficultyParams.fromJson({
      ...lo,
      'baseSpeed': lerp('baseSpeed'),
      'maxSpeed': lerp('maxSpeed'),
      'gapSeconds': lerp('gapSeconds'),
      'minGapSeconds': lerp('minGapSeconds'),
      'targetTier': lerp('targetTier'),
      'jumpEnabled': level >= jumpLevel,
      'diveEnabled': level >= diveLevel,
      'liveAdapt': true,
    });
  }

  DifficultyParams fixedParams(String key, {int level = 1}) =>
      DifficultyParams.fromJson({
        ...(config[key]! as Map<Object?, Object?>).cast<String, Object?>(),
        'jumpEnabled': level >= jumpLevel,
        'diveEnabled': level >= diveLevel,
      });

  /// Plans the next free run and marks a newly enabled mechanic as seen.
  RunPlan planRun(SkillState skill, {int level = 1}) {
    final params = paramsFor(skill.rating, level: level);
    final enabled = mechanicsOf(params);
    Mechanic? introducing;
    for (final m in Mechanic.values) {
      if (enabled.contains(m) && !skill.seenMechanics.contains(m)) {
        introducing = m;
        break;
      }
    }
    if (introducing != null) skill.seenMechanics.add(introducing);
    return RunPlan(params, introducing);
  }

  static Set<Mechanic> mechanicsOf(DifficultyParams p) => {
    if (p.drops) Mechanic.drops,
    if (p.obstacles) Mechanic.obstacles,
    if (p.mixing) Mechanic.mixing,
    if (p.mixDepth >= 2) Mechanic.secondaryGates,
    if (p.specials) Mechanic.specials,
    if (p.laneCount >= 5) Mechanic.fiveLanes,
    if (p.jumpEnabled) Mechanic.jump,
    if (p.diveEnabled) Mechanic.dive,
  };

  /// Updates [skill] after a free run. Returns the rating delta.
  double recordRun(SkillState skill, RunResult run) {
    skill.recentRuns.add(run);
    while (skill.recentRuns.length > 10) {
      skill.recentRuns.removeAt(0);
    }
    final s = run.successRate;
    final low = _r('flowLow');
    final high = _r('flowHigh');
    final mid = (low + high) / 2;
    final halfBand = (high - low) / 2;
    var delta = _r('k') * ((s - mid) / halfBand).clamp(-1.5, 1.5);
    if (s >= low && s <= high) delta += _r('inFlowBonus');
    if (run.durationMs >= _r('longRunMs')) delta += _r('longRunBonus');
    if (s >= _r('masteryRate') && run.durationMs >= _r('masteryMinMs')) {
      delta += _r('masteryBonus');
    }
    if (run.avgReactionMs > 0 &&
        run.avgReactionMs < _r('fastReactionMs') &&
        s > high) {
      delta += _r('fastReactionBonus');
    }

    // Three quick losses in a row: quietly make it easier.
    if (run.durationMs < _r('earlyFailMs')) {
      skill.earlyFailStreak++;
      if (skill.earlyFailStreak >= _r('earlyFailStreak')) {
        delta -= _r('earlyFailPenalty');
        skill.earlyFailStreak = 0;
      }
    } else {
      skill.earlyFailStreak = 0;
    }

    final before = skill.rating;
    skill.rating = (skill.rating + delta).clamp(_r('min'), _r('max'));
    if (kDebugMode) {
      debugPrint(
        '[AdaptiveDirector] success=${(s * 100).toStringAsFixed(0)}% '
        'dur=${run.durationMs ~/ 1000}s react=${run.avgReactionMs}ms '
        'rating ${before.toStringAsFixed(0)} -> ${skill.rating.toStringAsFixed(0)}',
      );
    }
    return skill.rating - before;
  }
}
