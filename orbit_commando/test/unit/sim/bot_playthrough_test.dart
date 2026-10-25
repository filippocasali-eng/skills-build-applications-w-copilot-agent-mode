import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/game/input/input_source.dart';
import 'package:orbit_commando/game/levels/tiled_loader.dart';
import 'package:orbit_commando/game/sim/balance.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';

/// Runs the autopilot on a level; returns (completed, ticks, continues).
(bool, int, int) botRun(
  String file, {
  Difficulty d = Difficulty.easy,
  int max = 60 * 60 * 8,
}) {
  final level = TiledLoader.parse(File(file).readAsStringSync());
  final sim = GameSim(level: level, difficulty: d, levelNumber: 5, seed: 1);
  final bot = AutoPilot();
  var continues = 0;
  while (sim.tick < max && sim.state != SimState.complete) {
    sim.step(bot.next(sim));
    if (sim.state == SimState.gameOver) {
      continues++;
      sim.continueGame();
    }
  }
  return (sim.state == SimState.complete, sim.tick, continues);
}

void main() {
  final levels =
      ((jsonDecode(File('assets/levels/campaign.json').readAsStringSync())
                  as Map<String, dynamic>)['levels']
              as List<dynamic>)
          .cast<Map<String, dynamic>>();
  final report = Platform.environment['BOT_REPORT'] == '1';

  test('the autopilot finishes level 1-1', () {
    final (done, ticks, cont) = botRun('assets/levels/w1_l1.tmj');
    expect(done, isTrue, reason: 'ticks=$ticks continues=$cont');
  });

  // The whole campaign must be beatable: a clumsy bot (with continues)
  // finishes every level, bosses included. Catches unreachable exits,
  // softlocks and unbeatable bosses.
  for (final l in levels) {
    test('the autopilot finishes ${l['id']} (${l['name']})', () {
      final (done, ticks, cont) = botRun('assets/${l['file']}');
      if (report) {
        // ignore: avoid_print
        print(
          '${l['id']}: ${(ticks / 60).toStringAsFixed(0)} s, $cont continues',
        );
      }
      expect(done, isTrue, reason: 'ticks=$ticks continues=$cont');
    });
  }
}
