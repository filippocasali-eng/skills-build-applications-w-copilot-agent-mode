import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/math/det_random.dart';
import 'package:orbit_commando/game/levels/level_data.dart';
import 'package:orbit_commando/game/sim/balance.dart';
import 'package:orbit_commando/game/sim/events.dart';
import 'package:orbit_commando/game/sim/game_sim.dart';
import 'package:orbit_commando/game/sim/input_frame.dart';

import '../../helpers/levels.dart';

GameSim simFor(
  LevelData level, {
  Difficulty difficulty = Difficulty.normal,
  int seed = 1,
}) => GameSim(level: level, difficulty: difficulty, seed: seed);

void run(GameSim sim, int ticks, [InputFrame input = InputFrame.none]) {
  for (var i = 0; i < ticks; i++) {
    sim.step(input);
  }
}

bool sawEvent(GameSim sim, int ticks, InputFrame input, SimEventType type) {
  for (var i = 0; i < ticks; i++) {
    sim.step(input);
    for (final e in sim.events.items) {
      if (e.type == type) return true;
    }
  }
  return false;
}

void main() {
  group('input frame', () {
    test('pack/unpack round-trips every combination', () {
      for (var v = 0; v < 256; v++) {
        final f = InputFrame.unpack(v);
        if (f.dx < -1 || f.dx > 1 || f.dy < -1 || f.dy > 1) continue;
        expect(InputFrame.unpack(f.pack()), f);
      }
    });
  });

  group('player', () {
    test('runs right and jumps', () {
      final sim = simFor(flatLevel());
      run(sim, 20);
      final x0 = sim.player.body.x;
      run(sim, 60, const InputFrame(dx: 1));
      expect(sim.player.body.x - x0, greaterThan(140));
      expect(sim.player.facing, 1);
      run(sim, 1, const InputFrame(dx: 1, jump: true));
      run(sim, 10, const InputFrame(dx: 1, jump: true));
      expect(sim.player.body.y, lessThan(350));
    });

    test('short tap jumps lower than a held jump', () {
      double apex(bool hold) {
        final sim = simFor(flatLevel());
        run(sim, 20);
        var best = 1e9;
        sim.step(const InputFrame(jump: true));
        for (var i = 0; i < 60; i++) {
          sim.step(InputFrame(jump: hold));
          if (sim.player.body.y < best) best = sim.player.body.y;
        }
        return 400 - best;
      }

      expect(apex(true), greaterThan(apex(false) * 1.5));
    });

    test('jump buffer: pressing just before landing still jumps', () {
      final sim = simFor(flatLevel());
      run(sim, 20);
      sim.step(const InputFrame(jump: true));
      run(sim, 5, const InputFrame(jump: true));
      run(sim, 1);
      // Fall until a few ticks before landing, then press.
      while (sim.player.body.y < 385) {
        sim.step(InputFrame.none);
      }
      sim.step(const InputFrame(jump: true));
      run(sim, 8, const InputFrame(jump: true));
      expect(sim.player.body.y, lessThan(380));
    });

    test('dash is locked before level 3 and works after', () {
      final early = GameSim(level: flatLevel(), levelNumber: 1);
      run(early, 20);
      expect(
        sawEvent(early, 5, const InputFrame(dash: true), SimEventType.dash),
        isFalse,
      );
      final late = GameSim(level: flatLevel(), levelNumber: 3);
      run(late, 20);
      expect(
        sawEvent(late, 5, const InputFrame(dash: true), SimEventType.dash),
        isTrue,
      );
    });
  });

  group('combat', () {
    test('blaster kills a grunt; score and kill count go up', () {
      final sim = simFor(
        flatLevel(
          entities: [
            const EntityDef(
              type: 'enemy',
              x: 360,
              y: 400,
              props: {'kind': 'grunt'},
            ),
          ],
        ),
      );
      run(sim, 5);
      expect(sim.enemies, hasLength(1));
      run(sim, 90, const InputFrame(fire: true));
      expect(sim.kills, 1);
      expect(sim.score, greaterThanOrEqualTo(100));
    });

    test('bulwark shield blocks frontal shots but not grenades', () {
      final sim = simFor(
        flatLevel(
          entities: [
            const EntityDef(
              type: 'enemy',
              x: 330,
              y: 400,
              props: {'kind': 'bulwark'},
            ),
          ],
        ),
      );
      run(sim, 5);
      final e = sim.enemies.single;
      final hp = e.hp;
      // Keep the player alive for this test.
      sim.player.invuln = 100000;
      run(sim, 60, const InputFrame(fire: true));
      expect(e.hp, hp, reason: 'front shots are blocked');
      for (var i = 0; i < 4; i++) {
        sim.step(const InputFrame(grenade: true));
        run(sim, 70);
      }
      expect(e.hp, lessThan(hp));
    });

    test('every weapon fires and runs out of ammo back to the blaster', () {
      for (final w in WeaponKind.values.skip(1)) {
        final sim = simFor(flatLevel());
        run(sim, 5);
        sim.player.giveWeapon(w);
        expect(sim.player.weapon, w);
        run(sim, 3000, const InputFrame(fire: true));
        expect(sim.player.weapon, WeaponKind.blaster, reason: '$w');
      }
    });

    test('grenade explodes and damages in an area', () {
      final sim = simFor(flatLevel());
      run(sim, 5);
      expect(
        sawEvent(
          sim,
          120,
          const InputFrame(grenade: true),
          SimEventType.explosion,
        ),
        isTrue,
      );
      expect(sim.player.grenades, lessThan(5));
    });

    test('combo multiplier grows with quick kills', () {
      final sim = simFor(flatLevel());
      for (var i = 0; i < 4; i++) {
        sim.addScore(100, 0, 0, combos: true);
      }
      expect(sim.combo, 5);
      expect(sim.score, 100 + 200 + 300 + 400);
      run(sim, sim.balance.comboWindow + 1);
      expect(sim.combo, 1);
    });
  });

  group('life and death', () {
    test('normal: one hit kills, respawn under a second at the checkpoint', () {
      final sim = simFor(flatLevel());
      run(sim, 5);
      sim.player.hurt(0, 0);
      expect(sim.player.dead, isTrue);
      expect(sim.player.lives, 2);
      // Respawn delay + death hit-stop must stay under one second.
      var ticks = 0;
      while (sim.player.dead && ticks < 120) {
        sim.step(InputFrame.none);
        ticks++;
      }
      expect(sim.player.dead, isFalse);
      expect(ticks, lessThan(60));
      expect(sim.player.invuln, greaterThan(0));
    });

    test('easy: 3 hit points', () {
      final sim = simFor(flatLevel(), difficulty: Difficulty.easy);
      run(sim, 5);
      sim.player.hurt(0, 0);
      expect(sim.player.dead, isFalse);
      expect(sim.player.hp, 2);
    });

    test('losing every life is game over; continue restores 3 lives', () {
      final sim = simFor(flatLevel());
      run(sim, 5);
      for (var i = 0; i < 3; i++) {
        sim.player.invuln = 0;
        sim.player.hurt(0, 0);
        run(sim, 60);
      }
      expect(sim.state, SimState.gameOver);
      sim.continueGame();
      expect(sim.state, SimState.playing);
      expect(sim.player.lives, 3);
    });

    test('checkpoints move the respawn point', () {
      final sim = simFor(
        flatLevel(
          entities: [const EntityDef(type: 'checkpoint', x: 600, y: 400)],
        ),
      );
      run(sim, 5);
      run(sim, 400, const InputFrame(dx: 1));
      expect(sim.player.checkpointX, 600);
      sim.player.hurt(0, 0);
      run(sim, 60);
      expect(sim.player.body.x, closeTo(600, 2));
    });
  });

  group('items', () {
    test('hostage frees on touch, scores, drops its reward', () {
      final sim = simFor(
        flatLevel(
          entities: [
            const EntityDef(
              type: 'hostage',
              x: 300,
              y: 400,
              props: {'reward': 'S'},
            ),
          ],
        ),
      );
      run(sim, 5);
      run(sim, 200, const InputFrame(dx: 1));
      expect(sim.items.hostagesFreed, 1);
      expect(sim.score, greaterThanOrEqualTo(1000));
    });

    test('weapon pickup and cassette', () {
      final sim = simFor(
        flatLevel(
          entities: [
            const EntityDef(
              type: 'pickup',
              x: 250,
              y: 400,
              props: {'item': 'L'},
            ),
            const EntityDef(
              type: 'cassette',
              x: 400,
              y: 400,
              props: {'index': 2},
            ),
          ],
        ),
      );
      run(sim, 5);
      run(sim, 200, const InputFrame(dx: 1));
      expect(sim.player.weapon, WeaponKind.laser);
      expect(sim.items.cassettesFound, 4);
    });

    test('reaching the exit completes the level with a rank', () {
      final sim = simFor(flatLevel(exit: const RectDef(700, 300, 760, 400)));
      run(sim, 5);
      run(sim, 400, const InputFrame(dx: 1));
      expect(sim.state, SimState.complete);
      expect(sim.result, isNotNull);
      expect('SABCD', contains(sim.result!.rank));
      expect(sim.result!.noDeathBonus, sim.balance.noDeathBonus);
    });
  });

  group('rank', () {
    test('S needs target score, no deaths and all hostages', () {
      expect(
        GameSim.rankFor(
          total: 20000,
          target: 20000,
          deaths: 0,
          allHostages: true,
        ),
        'S',
      );
      expect(
        GameSim.rankFor(
          total: 20000,
          target: 20000,
          deaths: 1,
          allHostages: true,
        ),
        'A',
      );
      expect(
        GameSim.rankFor(
          total: 13000,
          target: 20000,
          deaths: 0,
          allHostages: true,
        ),
        'B',
      );
      expect(
        GameSim.rankFor(
          total: 1000,
          target: 20000,
          deaths: 0,
          allHostages: true,
        ),
        'D',
      );
    });
  });

  group('determinism', () {
    LevelData busyLevel() => flatLevel(
      planets: const [PlanetDef(cx: 1500, cy: 200, radius: 80, influence: 200)],
      platforms: [
        [pt(400, 330), pt(700, 330)],
      ],
      entities: [
        for (var i = 0; i < 12; i++)
          EntityDef(
            type: 'enemy',
            x: 300.0 + i * 180,
            y: i.isEven ? 400 : 250,
            props: {
              'kind': [
                'grunt',
                'rocket',
                'cyclops',
                'bulwark',
                'clerk',
                'drone',
                'turret',
                'roller',
                'sniper',
                'minimech',
                'jelly',
                'swarm',
              ][i],
            },
          ),
      ],
    );

    List<InputFrame> script(int n, int seed) {
      final r = DetRandom(seed);
      return List.generate(n, (_) => InputFrame.unpack(r.nextUint32() & 0xFF))
          .map(
            (f) => InputFrame(
              dx: f.dx.clamp(-1, 1),
              dy: f.dy.clamp(-1, 1),
              jump: f.jump,
              fire: f.fire,
              grenade: f.grenade,
              dash: f.dash,
            ),
          )
          .toList();
    }

    test('same seed + same inputs = identical state over 10,000 ticks', () {
      final inputs = script(10000, 99);
      int playHash() {
        final sim = GameSim(level: busyLevel(), seed: 7, levelNumber: 5);
        var h = 0;
        for (final f in inputs) {
          sim.step(f);
          if (sim.state == SimState.gameOver) sim.continueGame();
          if (sim.tick % 500 == 0) h = h * 31 + sim.stateHash();
        }
        return h ^ sim.stateHash();
      }

      expect(playHash(), playHash());
    });

    test('different inputs diverge', () {
      int hashFor(int s) {
        final sim = GameSim(level: busyLevel(), seed: 7);
        for (final f in script(600, s)) {
          sim.step(f);
        }
        return sim.stateHash();
      }

      expect(hashFor(1), isNot(hashFor(2)));
    });

    test('all 12 enemy types survive 3,000 ticks of chaos without errors', () {
      final sim = GameSim(level: busyLevel(), seed: 3, levelNumber: 9);
      for (final f in script(3000, 5)) {
        sim.step(f);
        if (sim.state == SimState.gameOver) sim.continueGame();
      }
      expect(sim.tick, 3000);
    });
  });
}
