import '../../core/models/profile.dart';
import '../../core/models/run_result.dart';
import '../../core/services/wellbeing.dart';
import '../../game/ai/adaptive_director.dart';
import '../../game/sim/difficulty.dart';
import '../../game/sim/replay.dart';
import '../../game/sim/rng.dart';
import '../academy/lessons.dart';

/// Everything needed to start a run of a given mode.
class RunSetup {
  const RunSetup({
    required this.mode,
    required this.seed,
    required this.params,
    this.ghost,
    this.ghostScore = 0,
    this.introducing,
    this.lessonIndex,
  });

  final GameMode mode;
  final int seed;
  final DifficultyParams params;
  final Replay? ghost;
  final int ghostScore;
  final Mechanic? introducing;
  final int? lessonIndex;

  static const ghostTrackId = 'ghost-track-1';

  static const onboardingParams = DifficultyParams(
    baseSpeed: 6.5,
    maxSpeed: 8,
    gapSeconds: 1.8,
    minGapSeconds: 1.6,
    maxTier: 0,
    targetTier: 0,
    drops: false,
    obstacles: false,
    liveAdapt: false,
    practice: true,
    finishDistance: 230,
    focus: 'basic_01,basic_03,basic_04,basic_05',
  );

  /// Builds the next run. For free runs this consults (and updates) the
  /// player's skill state.
  static RunSetup create(
    GameMode mode,
    PlayerProfile p,
    AdaptiveDirector director, {
    int? lessonIndex,
    required DateTime now,
    required int freshSeed,
  }) {
    switch (mode) {
      case GameMode.free:
        final plan = director.planRun(p.skill, level: p.level);
        return RunSetup(
          mode: mode,
          seed: freshSeed,
          params: plan.params,
          introducing: plan.introducing,
        );
      case GameMode.daily:
        return RunSetup(
          mode: mode,
          seed: Rng.seedFromString('mixo-daily-${Wellbeing.dayKey(now)}'),
          params: director.fixedParams('daily'),
        );
      case GameMode.academy:
        final lesson = Lessons.all[lessonIndex ?? 0];
        return RunSetup(
          mode: mode,
          seed: lesson.seed,
          params: lesson.params,
          introducing: lesson.mechanic,
          lessonIndex: lesson.index,
        );
      case GameMode.ghost:
        final g = p.ghostReplay;
        return RunSetup(
          mode: mode,
          seed: g?.seed ?? Rng.seedFromString('mixo-$ghostTrackId'),
          params: g?.params ?? director.fixedParams('ghost'),
          ghost: g,
          ghostScore: p.ghostScore,
        );
      case GameMode.onboarding:
        return RunSetup(mode: mode, seed: 0x0B0A, params: onboardingParams);
    }
  }
}
