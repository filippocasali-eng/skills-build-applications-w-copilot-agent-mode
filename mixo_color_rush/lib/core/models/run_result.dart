import '../../game/sim/game_simulation.dart';
import '../../game/sim/replay.dart';

enum GameMode { free, daily, academy, ghost, onboarding }

/// Summary of a finished run (persisted for the AdaptiveDirector, stats,
/// missions and ghosts).
class RunResult {
  const RunResult({
    required this.seed,
    required this.mode,
    required this.score,
    required this.maxCombo,
    required this.maxMultiplier,
    required this.durationMs,
    required this.gatesOk,
    required this.gatesFail,
    required this.errorsByType,
    required this.failsByGateColor,
    required this.okByGateColor,
    required this.failsWhileBrown,
    required this.dropsTaken,
    required this.nearMisses,
    required this.obstaclesJumped,
    required this.mixGatesOk,
    required this.avgReactionMs,
    required this.completed,
    required this.heartsLeft,
    this.replay,
  });

  factory RunResult.fromSim(GameSimulation sim, GameMode mode) => RunResult(
    seed: sim.seed,
    mode: mode,
    score: sim.score.score,
    maxCombo: sim.score.maxCombo,
    maxMultiplier: sim.maxMultiplier,
    durationMs: sim.elapsedMs,
    gatesOk: sim.gatesOk,
    gatesFail: sim.gatesFail,
    errorsByType: List.of(sim.errorsByType),
    failsByGateColor: List.of(sim.failsByGateColor),
    okByGateColor: List.of(sim.okByGateColor),
    failsWhileBrown: sim.failsWhileBrown,
    dropsTaken: sim.dropsTaken,
    nearMisses: sim.nearMisses,
    obstaclesJumped: sim.obstaclesJumped,
    mixGatesOk: sim.mixGatesOk,
    avgReactionMs: sim.avgReactionMs,
    completed: sim.isCompleted,
    heartsLeft: sim.hearts,
    replay: sim.toReplay(),
  );

  factory RunResult.fromJson(Map<String, Object?> j) {
    List<int> ints(String k) => (j[k]! as List<Object?>).cast<int>();
    final r = j['replay'] as Map<Object?, Object?>?;
    return RunResult(
      seed: j['seed']! as int,
      mode: GameMode.values.byName(j['mode']! as String),
      score: j['score']! as int,
      maxCombo: j['maxCombo']! as int,
      maxMultiplier: j['maxMultiplier'] as int? ?? 1,
      durationMs: j['durationMs']! as int,
      gatesOk: j['gatesOk']! as int,
      gatesFail: j['gatesFail']! as int,
      errorsByType: ints('errorsByType'),
      failsByGateColor: ints('failsByGateColor'),
      okByGateColor: ints('okByGateColor'),
      failsWhileBrown: j['failsWhileBrown'] as int? ?? 0,
      dropsTaken: j['dropsTaken'] as int? ?? 0,
      nearMisses: j['nearMisses'] as int? ?? 0,
      obstaclesJumped: j['obstaclesJumped'] as int? ?? 0,
      mixGatesOk: j['mixGatesOk'] as int? ?? 0,
      avgReactionMs: j['avgReactionMs'] as int? ?? 0,
      completed: j['completed'] as bool? ?? false,
      heartsLeft: j['heartsLeft'] as int? ?? 0,
      replay: r == null ? null : Replay.fromJson(r.cast()),
    );
  }

  final int seed;
  final GameMode mode;
  final int score;
  final int maxCombo;
  final int maxMultiplier;
  final int durationMs;
  final int gatesOk;
  final int gatesFail;
  final List<int> errorsByType;
  final List<int> failsByGateColor;
  final List<int> okByGateColor;
  final int failsWhileBrown;
  final int dropsTaken;
  final int nearMisses;
  final int obstaclesJumped;
  final int mixGatesOk;
  final int avgReactionMs;
  final bool completed;
  final int heartsLeft;
  final Replay? replay;

  int get obstacleHits => errorsByType[ErrorType.obstacle.index];

  double get successRate {
    final total = gatesOk + gatesFail + obstacleHits;
    return total == 0 ? 1 : gatesOk / total;
  }

  Map<String, Object?> toJson({bool includeReplay = false}) => {
    'seed': seed,
    'mode': mode.name,
    'score': score,
    'maxCombo': maxCombo,
    'maxMultiplier': maxMultiplier,
    'durationMs': durationMs,
    'gatesOk': gatesOk,
    'gatesFail': gatesFail,
    'errorsByType': errorsByType,
    'failsByGateColor': failsByGateColor,
    'okByGateColor': okByGateColor,
    'failsWhileBrown': failsWhileBrown,
    'dropsTaken': dropsTaken,
    'nearMisses': nearMisses,
    'obstaclesJumped': obstaclesJumped,
    'mixGatesOk': mixGatesOk,
    'avgReactionMs': avgReactionMs,
    'completed': completed,
    'heartsLeft': heartsLeft,
    if (includeReplay && replay != null) 'replay': replay!.toJson(),
  };
}
