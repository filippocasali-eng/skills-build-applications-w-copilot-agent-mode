import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/math/det_random.dart';
import 'package:orbit_commando/game/levels/tiled_loader.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';
import 'package:orbit_commando/game/sim/input_frame.dart';

void main() {
  final index = jsonDecode(
    File('assets/levels/campaign.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final levels = (index['levels'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('campaign has 15 levels: 3 worlds x (4 + boss)', () {
    expect(levels, hasLength(15));
    for (var w = 1; w <= 3; w++) {
      final inWorld = levels.where((l) => l['world'] == w).toList();
      expect(inWorld, hasLength(5));
      expect(inWorld.where((l) => l['boss'] == true), hasLength(1));
    }
  });

  for (final entry in levels) {
    final file = 'assets/${entry['file']}';
    test('${entry['id']} loads and survives 1,200 ticks of play', () {
      final level = TiledLoader.parse(File(file).readAsStringSync());
      expect(level.id, entry['id']);
      expect(level.solids, isNotEmpty);
      if (level.isBoss) {
        expect(level.ofType('boss'), hasLength(1));
      } else {
        expect(level.exit, isNotNull);
        expect(level.ofType('checkpoint').length, greaterThanOrEqualTo(2));
        expect(level.ofType('cassette'), hasLength(3));
      }
      final sim = GameSim(level: level, levelNumber: 5, seed: 3);
      // The player starts on solid ground.
      for (var i = 0; i < 30; i++) {
        sim.step(InputFrame.none);
      }
      expect(sim.player.body.grounded, isTrue, reason: 'start on ground');
      final r = DetRandom(11);
      for (var i = 0; i < 1200; i++) {
        final v = r.nextUint32();
        sim.step(
          InputFrame(
            dx: v % 5 == 0 ? -1 : 1,
            jump: v & 8 != 0,
            fire: true,
            grenade: v % 97 == 0,
          ),
        );
        if (sim.state == SimState.gameOver) sim.continueGame();
      }
      expect(sim.tick, 1230);
    });
  }
}
