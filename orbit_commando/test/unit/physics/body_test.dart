import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/physics/body.dart';
import 'package:orbit_commando/engine/physics/gravity.dart';
import 'package:orbit_commando/game/levels/level_data.dart';

import '../../helpers/levels.dart';

void main() {
  group('flat ground', () {
    final level = flatLevel();
    final world = level.buildWorld();
    final field = level.buildGravity();

    test('a dropped body lands on the ground and is grounded', () {
      final b = Body(radius: 11, height: 58)
        ..x = 200
        ..y = 200;
      for (var i = 0; i < 120; i++) {
        b.step(world, field, g: 0.42);
      }
      expect(b.grounded, isTrue);
      expect(b.y, closeTo(400, 0.5));
      expect(b.vu.abs(), lessThan(0.01));
    });

    test('walls stop horizontal motion', () {
      final lv = flatLevel(ground: true);
      final w = LevelData(
        id: 'w',
        name: '',
        world: 1,
        index: 1,
        theme: LevelTheme.asteroids,
        width: 3000,
        height: 600,
        solids: [...lv.solids, box(400, 200, 500, 400)],
        platforms: const [],
        planets: const [],
        zones: const [],
        entities: const [],
        exit: null,
      ).buildWorld();
      final b = Body(radius: 11, height: 58)
        ..x = 300
        ..y = 400;
      for (var i = 0; i < 120; i++) {
        b.setLocal(3, b.vu);
        b.step(w, field, g: 0.42);
      }
      expect(b.x, lessThanOrEqualTo(400 - 11 + 0.5));
      expect(b.hitWall, isTrue);
    });
  });

  group('one-way platforms', () {
    final level = flatLevel(
      platforms: [
        [pt(150, 340), pt(350, 340)],
      ],
    );
    final world = level.buildWorld();
    final field = level.buildGravity();

    test('can be jumped through from below and landed on', () {
      final b = Body(radius: 11, height: 58)
        ..x = 250
        ..y = 400;
      b.setLocal(0, 9);
      var maxUp = 400.0;
      for (var i = 0; i < 200; i++) {
        b.step(world, field, g: 0.42);
        maxUp = math.min(maxUp, b.y);
      }
      expect(maxUp, lessThan(340), reason: 'passed through from below');
      expect(b.y, closeTo(340, 0.5), reason: 'landed on top');
      expect(b.grounded, isTrue);
    });

    test('dropThrough lets the body fall down', () {
      final b = Body(radius: 11, height: 58)
        ..x = 250
        ..y = 340;
      for (var i = 0; i < 10; i++) {
        b.step(world, field, g: 0.42);
      }
      expect(b.y, closeTo(340, 0.5));
      b.dropThrough = 14;
      for (var i = 0; i < 120; i++) {
        b.step(world, field, g: 0.42);
      }
      expect(b.y, closeTo(400, 0.5));
    });
  });

  group('planetoids', () {
    const planet = PlanetDef(cx: 1000, cy: 1000, radius: 150, influence: 400);
    final level = flatLevel(
      ground: false,
      planets: const [planet],
      defaultGravity: GravityKind.zero,
    );
    final world = level.buildWorld();
    final field = level.buildGravity();

    test('up points away from the centre, everywhere on the surface', () {
      for (final deg in [0, 45, 90, 135, 180, 270]) {
        final a = deg * math.pi / 180;
        final b = Body(radius: 11, height: 58)
          ..x = 1000 + math.sin(a) * 200
          ..y = 1000 - math.cos(a) * 200;
        for (var i = 0; i < 90; i++) {
          b.step(world, field, g: 0.42);
        }
        expect(b.grounded, isTrue, reason: '$deg°');
        final dx = b.x - 1000, dy = b.y - 1000;
        final d = math.sqrt(dx * dx + dy * dy);
        expect(d, closeTo(150, 1), reason: 'feet on the surface at $deg°');
        expect(b.ux, closeTo(dx / d, 0.02));
        expect(b.uy, closeTo(dy / d, 0.02));
      }
    });

    test('running keeps the body on the surface all the way round', () {
      final b = Body(radius: 11, height: 58)
        ..x = 1000
        ..y = 850;
      b.updateFrame(field);
      var travelled = 0.0;
      var px = b.x, py = b.y;
      for (var i = 0; i < 600; i++) {
        b.setLocal(2.7, b.vu);
        b.step(world, field, g: 0.42);
        travelled += math.sqrt(
          (b.x - px) * (b.x - px) + (b.y - py) * (b.y - py),
        );
        px = b.x;
        py = b.y;
        final d = math.sqrt(
          (b.x - 1000) * (b.x - 1000) + (b.y - 1000) * (b.y - 1000),
        );
        expect(d, closeTo(150, 2.5), reason: 'tick $i');
      }
      // ~2.7 px/tick for 600 ticks: more than one full lap (2*pi*150 = 942).
      expect(travelled, greaterThan(1400));
    });

    test('jumping between planetoids switches the gravity field', () {
      const a = PlanetDef(cx: 500, cy: 500, radius: 100, influence: 260);
      // Surfaces 140 px apart: reachable with one jump (~86 px apex).
      const c = PlanetDef(cx: 840, cy: 500, radius: 100, influence: 260);
      final lv = flatLevel(
        ground: false,
        planets: const [a, c],
        defaultGravity: GravityKind.zero,
      );
      final w = lv.buildWorld();
      final f = lv.buildGravity();
      // Stand on the right side of planet A, facing planet C.
      final b = Body(radius: 11, height: 58)
        ..x = 600
        ..y = 500;
      for (var i = 0; i < 30; i++) {
        b.step(w, f, g: 0.42);
      }
      expect(b.gravity.radialIndex, 0);
      b.setLocal(0, 8.5);
      for (var i = 0; i < 400; i++) {
        b.step(w, f, g: 0.42);
        if (b.grounded && b.gravity.radialIndex == 1) break;
      }
      expect(b.gravity.radialIndex, 1);
      expect(b.grounded, isTrue);
      final d = math.sqrt(
        (b.x - 840) * (b.x - 840) + (b.y - 500) * (b.y - 500),
      );
      expect(d, closeTo(100, 2));
    });
  });

  group('gravity field', () {
    test('nearest surface wins where planetoids overlap', () {
      final f = GravityField(
        zones: const [
          GravityZone.radial(cx: 0, cy: 0, surface: 100, influence: 400),
          GravityZone.radial(cx: 300, cy: 0, surface: 50, influence: 400),
        ],
      );
      final s = GravitySample();
      f.sample(200, 0, s); // 100 from A's surface, 50 from B's
      expect(s.radialIndex, 1);
      expect(s.dx, closeTo(1, 1e-9));
    });

    test('rect zones override the default; zero-g has no pull', () {
      final f = GravityField(
        zones: const [GravityZone.zero(x0: 0, y0: 0, x1: 100, y1: 100)],
      );
      final s = GravitySample();
      f.sample(50, 50, s);
      expect(s.isZero, isTrue);
      f.sample(150, 50, s);
      expect(s.isZero, isFalse);
      expect(s.dy, 1);
    });
  });
}
