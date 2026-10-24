import '../../game/sim/rng.dart';
import '../../game/systems/color_system.dart';
import 'run_result.dart';

enum MissionKind {
  /// Pass N gates of a colour (cumulative).
  colorGates(cumulative: true),

  /// Reach combo N in one run.
  combo(cumulative: false),

  /// Survive N seconds in one run.
  survive(cumulative: false),

  /// Score N points in one run.
  score(cumulative: false),

  /// Collect N drops (cumulative).
  drops(cumulative: true),

  /// N "near miss" (cumulative).
  nearMiss(cumulative: true),

  /// Play N runs (cumulative).
  runs(cumulative: true),

  /// Pass N mixed-colour gates (cumulative).
  mixGates(cumulative: true),

  /// Jump over N obstacles (cumulative).
  jumps(cumulative: true);

  const MissionKind({required this.cumulative});

  final bool cumulative;
}

/// A visible, deterministic goal. Missions renew when completed, never on
/// a timer (no FOMO).
class Mission {
  Mission({
    required this.kind,
    required this.target,
    required this.reward,
    this.color,
    this.progress = 0,
  });

  factory Mission.fromJson(Map<String, Object?> j) => Mission(
    kind: MissionKind.values.byName(j['kind']! as String),
    target: j['target']! as int,
    reward: j['reward']! as int,
    color: j['color'] == null ? null : GameColor.values[j['color']! as int],
    progress: j['progress'] as int? ?? 0,
  );

  final MissionKind kind;
  final int target;

  /// Stars on completion.
  final int reward;
  final GameColor? color;
  int progress;

  bool get done => progress >= target;

  /// Applies a run. Returns true if this run completed the mission.
  bool apply(RunResult r) {
    if (done) return false;
    final value = switch (kind) {
      MissionKind.colorGates => r.okByGateColor[color!.index],
      MissionKind.combo => r.maxCombo,
      MissionKind.survive => r.durationMs ~/ 1000,
      MissionKind.score => r.score,
      MissionKind.drops => r.dropsTaken,
      MissionKind.nearMiss => r.nearMisses,
      MissionKind.runs => 1,
      MissionKind.mixGates => r.mixGatesOk,
      MissionKind.jumps => r.obstaclesJumped,
    };
    if (kind.cumulative) {
      progress += value;
    } else if (value > progress) {
      progress = value;
    }
    if (progress > target) progress = target;
    return done;
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'target': target,
    'reward': reward,
    'color': color?.index,
    'progress': progress,
  };
}

/// Deterministic mission generator (same counter → same mission).
abstract final class MissionFactory {
  static Mission create(
    int counter, {
    required int level,
    required bool mixing,
    required bool jump,
    Set<MissionKind> avoid = const {},
  }) {
    final rng = Rng(0x5EED + counter * 7919);
    final kinds = [
      MissionKind.colorGates,
      MissionKind.combo,
      MissionKind.survive,
      MissionKind.score,
      MissionKind.drops,
      MissionKind.nearMiss,
      MissionKind.runs,
      if (mixing) MissionKind.mixGates,
      if (jump) MissionKind.jumps,
    ].where((k) => !avoid.contains(k)).toList();
    final kind = kinds[rng.nextInt(kinds.length)];
    final s = 1 + (level - 1) * 0.15;
    int scaled(int base) => (base * s).round();
    switch (kind) {
      case MissionKind.colorGates:
        final palette = mixing
            ? [...GameColor.primaries, ...GameColor.secondaries]
            : GameColor.primaries;
        final c = palette[rng.nextInt(palette.length)];
        return Mission(
          kind: kind,
          target: scaled(c.isSecondary ? 6 : 10),
          reward: 20,
          color: c,
        );
      case MissionKind.combo:
        return Mission(
          kind: kind,
          target: (5 + level).clamp(5, 35),
          reward: 25,
        );
      case MissionKind.survive:
        return Mission(
          kind: kind,
          target: (45 + level * 5).clamp(45, 170),
          reward: 25,
        );
      case MissionKind.score:
        return Mission(
          kind: kind,
          target: scaled(1500) ~/ 100 * 100,
          reward: 25,
        );
      case MissionKind.drops:
        return Mission(kind: kind, target: scaled(15), reward: 15);
      case MissionKind.nearMiss:
        return Mission(kind: kind, target: scaled(3), reward: 20);
      case MissionKind.runs:
        return Mission(kind: kind, target: 3, reward: 10);
      case MissionKind.mixGates:
        return Mission(kind: kind, target: scaled(8), reward: 30);
      case MissionKind.jumps:
        return Mission(kind: kind, target: scaled(5), reward: 20);
    }
  }
}
