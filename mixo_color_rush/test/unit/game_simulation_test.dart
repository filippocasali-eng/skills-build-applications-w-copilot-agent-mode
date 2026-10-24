import 'package:flutter_test/flutter_test.dart';
import 'package:mixo_color_rush/game/sim/difficulty.dart';
import 'package:mixo_color_rush/game/sim/game_simulation.dart';
import 'package:mixo_color_rush/game/sim/replay.dart';
import 'package:mixo_color_rush/game/sim/rng.dart';
import 'package:mixo_color_rush/game/sim/track.dart';

import '../support/test_data.dart';

/// Simple bot: moves towards the first safe lane of the next row.
void botStep(GameSimulation sim) {
  for (final row in sim.rows) {
    if (row.resolved || row.d <= sim.distance) continue;
    var target = -1;
    for (var l = 0; l < sim.params.laneCount; l++) {
      final c = row.cells[l];
      final safe =
          c.type == CellType.empty ||
          c.type == CellType.drop ||
          (c.type == CellType.gate && c.color == sim.color);
      if (safe &&
          (target < 0 || (l - sim.lane).abs() < (target - sim.lane).abs())) {
        target = l;
      }
    }
    if (target >= 0 && target != sim.lane && sim.tick % 6 == 0) {
      sim.input(target < sim.lane ? InputAction.left : InputAction.right);
    }
    return;
  }
}

void main() {
  const params = DifficultyParams();
  final lib = loadLibrary();

  test('idle player eventually loses all hearts', () {
    final sim = GameSimulation(library: lib, seed: 3, params: params);
    while (!sim.isOver && sim.tick < 60 * 600) {
      sim.step();
    }
    expect(sim.isOver, isTrue);
    expect(sim.hearts, 0);
    expect(sim.gatesFail + sim.errorsByType[2], greaterThanOrEqualTo(3));
  });

  test('a bot that reads the track survives much longer', () {
    var total = 0;
    for (var seed = 0; seed < 20; seed++) {
      final sim = GameSimulation(library: lib, seed: seed, params: params);
      while (!sim.isOver && sim.tick < 60 * 120) {
        botStep(sim);
        sim.step();
      }
      expect(sim.gatesOk, greaterThan(20), reason: 'seed $seed');
      total += sim.elapsedMs;
    }
    expect(total / 20, greaterThan(60000));
  });

  test('lanes are clamped', () {
    final sim = GameSimulation(library: lib, seed: 1, params: params);
    for (var i = 0; i < 5; i++) {
      sim.input(InputAction.left);
      sim.step();
    }
    expect(sim.lane, 0);
    for (var i = 0; i < 9; i++) {
      sim.input(InputAction.right);
      sim.step();
    }
    expect(sim.lane, params.laneCount - 1);
  });

  test('same seed produces the same track', () {
    final a = GameSimulation(library: lib, seed: 99, params: params);
    final b = GameSimulation(library: lib, seed: 99, params: params);
    for (var i = 0; i < 60 * 30; i++) {
      a.step();
      b.step();
    }
    expect(a.rows.length, b.rows.length);
    for (var i = 0; i < a.rows.length; i++) {
      expect(a.rows[i].d, b.rows[i].d);
      for (var l = 0; l < params.laneCount; l++) {
        expect(a.rows[i].cells[l].type, b.rows[i].cells[l].type);
        expect(a.rows[i].cells[l].color, b.rows[i].cells[l].color);
      }
    }
  });

  test('replay reproduces score exactly (also through JSON)', () {
    final rng = Rng(5);
    final sim = GameSimulation(library: lib, seed: 1234, params: params);
    while (!sim.isOver && sim.tick < 60 * 200) {
      if (rng.chance(0.03)) {
        sim.input(rng.chance(0.5) ? InputAction.left : InputAction.right);
      }
      sim.step();
    }
    final replay = Replay.fromJson(sim.toReplay().toJson());
    final again = GameSimulation.fromReplay(replay, lib);
    expect(again.score.score, sim.score.score);
    expect(again.tick, sim.tick);
    expect(again.gatesOk, sim.gatesOk);
    expect(again.isOver, sim.isOver);
  });

  test('wrong gate costs a heart and breaks combo', () {
    final sim = GameSimulation(library: lib, seed: 8, params: params);
    var lostHeart = false;
    while (!sim.isOver && sim.tick < 60 * 60) {
      sim.step();
      sim.drainEvents((e) {
        if (e.type == SimEventType.gateFail) lostHeart = true;
      });
      if (lostHeart) break;
    }
    expect(lostHeart, isTrue);
    expect(sim.hearts, GameSimulation.startHearts - 1);
    expect(sim.score.combo, 0);
  });
}
