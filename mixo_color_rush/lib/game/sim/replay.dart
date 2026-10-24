import '../systems/color_system.dart';
import 'difficulty.dart';

enum InputAction { left, right, jump, dive }

/// A player input stamped with the simulation tick it was issued at.
class InputCommand {
  const InputCommand(this.tick, this.action);

  final int tick;
  final InputAction action;
}

/// Compact, deterministic recording of a run: seed + params + inputs.
/// Re-simulating it reproduces the exact same run.
class Replay {
  Replay({
    required this.seed,
    required this.params,
    required this.startColor,
    required this.inputs,
    required this.endTick,
  });

  factory Replay.fromJson(Map<String, Object?> j) {
    final packed = (j['inputs']! as List<Object?>).cast<int>();
    return Replay(
      seed: j['seed']! as int,
      params: DifficultyParams.fromJson(
        (j['params']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      startColor: GameColor.values[j['startColor']! as int],
      endTick: j['endTick']! as int,
      inputs: [
        for (final p in packed) InputCommand(p >> 2, InputAction.values[p & 3]),
      ],
    );
  }

  final int seed;
  final DifficultyParams params;
  final GameColor startColor;
  final List<InputCommand> inputs;
  int endTick;

  /// Inputs are packed as `tick << 2 | action` to keep saves small.
  Map<String, Object?> toJson() => {
    'v': 1,
    'seed': seed,
    'params': params.toJson(),
    'startColor': startColor.index,
    'endTick': endTick,
    'inputs': [for (final i in inputs) i.tick << 2 | i.action.index],
  };
}
