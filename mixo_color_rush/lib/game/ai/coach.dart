import '../../core/models/run_result.dart';
import '../sim/game_simulation.dart';
import '../systems/color_system.dart';

enum CoachTipKind {
  mixRecipe,
  brownNeedsWhite,
  matchSymbol,
  dodgeObstacles,
  jumpObstacles,
  lookAhead,
  tryCombo,
  greatRun,
}

/// One short, child-friendly tip. [a] + [b] = [result] for recipes.
class CoachTip {
  const CoachTip(this.kind, {this.a, this.b, this.result});

  final CoachTipKind kind;
  final GameColor? a;
  final GameColor? b;
  final GameColor? result;
}

/// Rule-based coach: picks at most one tip from the run's mistakes.
abstract final class Coach {
  static CoachTip tipFor(RunResult run, {bool jumpEnabled = false}) {
    final mix = run.errorsByType[ErrorType.wrongMix.index];
    final wrong = run.errorsByType[ErrorType.wrongColor.index];
    final obstacle = run.errorsByType[ErrorType.obstacle.index];

    if (run.failsWhileBrown > 0 &&
        run.failsWhileBrown >= mix - run.failsWhileBrown) {
      return const CoachTip(CoachTipKind.brownNeedsWhite);
    }
    if (mix > 0 && mix >= wrong && mix >= obstacle) {
      // Most-failed secondary gate → its recipe.
      GameColor? worst;
      var most = 0;
      for (final c in GameColor.secondaries) {
        final n = run.failsByGateColor[c.index];
        if (n > most) {
          most = n;
          worst = c;
        }
      }
      if (worst != null) {
        final parts = [
          for (final p in GameColor.primaries)
            if (worst.components & p.components != 0) p,
        ];
        return CoachTip(
          CoachTipKind.mixRecipe,
          a: parts[0],
          b: parts[1],
          result: worst,
        );
      }
      return const CoachTip(CoachTipKind.matchSymbol);
    }
    if (obstacle > 0 && obstacle >= wrong) {
      return CoachTip(
        jumpEnabled ? CoachTipKind.jumpObstacles : CoachTipKind.dodgeObstacles,
      );
    }
    if (wrong > 0) {
      if (run.durationMs < 20000) return const CoachTip(CoachTipKind.lookAhead);
      return const CoachTip(CoachTipKind.matchSymbol);
    }
    if (run.maxMultiplier < 5) return const CoachTip(CoachTipKind.tryCombo);
    return const CoachTip(CoachTipKind.greatRun);
  }
}
