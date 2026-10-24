import '../../game/ai/adaptive_director.dart';
import '../../game/sim/difficulty.dart';

/// One short Academy lesson (~40–60 s course).
class Lesson {
  const Lesson({
    required this.index,
    required this.mechanic,
    required this.params,
  });

  final int index;

  /// Mechanic the lesson teaches (icon + intro card), null for basics.
  final Mechanic? mechanic;
  final DifficultyParams params;

  int get seed => 0xACAD + index * 101;

  /// The first two lessons are mandatory before Daily and Ghost modes.
  bool get mandatory => index < 2;
}

abstract final class Lessons {
  static const _course = 600.0;

  static const List<Lesson> all = [
    Lesson(
      index: 0,
      mechanic: null,
      params: DifficultyParams(
        baseSpeed: 7,
        maxSpeed: 10,
        gapSeconds: 1.6,
        minGapSeconds: 1.3,
        maxTier: 1,
        targetTier: 0.5,
        drops: false,
        obstacles: false,
        liveAdapt: false,
        finishDistance: 450,
        focus: 'basic',
      ),
    ),
    Lesson(
      index: 1,
      mechanic: Mechanic.drops,
      params: DifficultyParams(
        baseSpeed: 7.5,
        maxSpeed: 11,
        gapSeconds: 1.5,
        minGapSeconds: 1.2,
        maxTier: 1,
        targetTier: 0.6,
        obstacles: false,
        liveAdapt: false,
        finishDistance: 500,
        focus: 'drops',
      ),
    ),
    Lesson(
      index: 2,
      mechanic: Mechanic.obstacles,
      params: DifficultyParams(
        baseSpeed: 8,
        maxSpeed: 12,
        gapSeconds: 1.4,
        minGapSeconds: 1.1,
        maxTier: 2,
        targetTier: 1,
        liveAdapt: false,
        finishDistance: _course,
        focus: 'obst_0',
      ),
    ),
    Lesson(
      index: 3,
      mechanic: Mechanic.mixing,
      params: DifficultyParams(
        baseSpeed: 8,
        maxSpeed: 12,
        gapSeconds: 1.5,
        minGapSeconds: 1.2,
        maxTier: 3,
        targetTier: 2,
        mixing: true,
        liveAdapt: false,
        finishDistance: _course,
        focus: 'mix_01,mix_02,mix_03,mix_05',
      ),
    ),
    Lesson(
      index: 4,
      mechanic: Mechanic.secondaryGates,
      params: DifficultyParams(
        baseSpeed: 8.5,
        maxSpeed: 13,
        gapSeconds: 1.4,
        minGapSeconds: 1.1,
        maxTier: 3,
        targetTier: 2.5,
        mixing: true,
        mixDepth: 2,
        liveAdapt: false,
        finishDistance: _course,
        focus: 'mix_0',
      ),
    ),
    Lesson(
      index: 5,
      mechanic: Mechanic.mixing,
      params: DifficultyParams(
        baseSpeed: 8.5,
        maxSpeed: 13,
        gapSeconds: 1.4,
        minGapSeconds: 1.1,
        maxTier: 5,
        targetTier: 3.5,
        mixing: true,
        mixDepth: 2,
        liveAdapt: false,
        finishDistance: _course,
        focus: 'mix_06,mix_08,mix_09,mix_04,spec_01',
      ),
    ),
    Lesson(
      index: 6,
      mechanic: Mechanic.specials,
      params: DifficultyParams(
        baseSpeed: 9,
        maxSpeed: 14,
        gapSeconds: 1.35,
        minGapSeconds: 1.05,
        maxTier: 5,
        targetTier: 3.5,
        mixing: true,
        mixDepth: 2,
        specials: true,
        strict: false,
        liveAdapt: false,
        finishDistance: _course,
        focus: 'spec_',
      ),
    ),
    Lesson(
      index: 7,
      mechanic: Mechanic.jump,
      params: DifficultyParams(
        baseSpeed: 10,
        maxSpeed: 17,
        gapSeconds: 1.2,
        minGapSeconds: 0.9,
        maxTier: 5,
        targetTier: 3.5,
        mixing: true,
        mixDepth: 2,
        specials: true,
        strict: false,
        jumpEnabled: true,
        diveEnabled: true,
        liveAdapt: false,
        finishDistance: 800,
        focus: 'obst_07,obst_08,obst_09,exp_',
      ),
    ),
  ];

  /// Stars for a finished lesson: hearts left (0 if failed).
  static int starsFor({required bool completed, required int heartsLeft}) =>
      completed ? heartsLeft.clamp(1, 3) : 0;

  static bool unlocked(Map<int, int> stars, int index) =>
      index == 0 || (stars[index - 1] ?? 0) > 0;

  static bool mandatoryDone(Map<int, int> stars) =>
      (stars[0] ?? 0) > 0 && (stars[1] ?? 0) > 0;
}
