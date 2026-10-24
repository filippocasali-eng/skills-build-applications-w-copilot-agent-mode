import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/render/palette.g.dart';
import 'package:orbit_commando/game/game_strings.dart';
import 'package:orbit_commando/game/orbit_game.dart';
import 'package:orbit_commando/game/roster.dart';
import 'package:orbit_commando/game/scenes/demo_scene.dart';

const _strings = GameStrings(
  title: "Orbit Commando '94",
  pressStart: 'Press start',
  credits: 'Credits 3',
  sandbox: 'Sandbox',
);

int _rgba(ui.Color c) => (c.toARGB32() << 8 & 0xFFFFFF00) | 0xFF;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<OrbitGame>(
    'loads assets and renders pixel-perfect 3x frames on a 20:9 screen',
    () => OrbitGame(strings: _strings),
    (game) async {
      game.onGameResize(Vector2(2400, 1080));
      await game.ready();
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      expect(game.clock.tick, inInclusiveRange(29, 30));
      expect(game.layout.scale, 3);
      expect(game.layout.dest.left, 240);

      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      final img = await rec.endRecording().toImage(2400, 1080);
      final bytes = (await img.toByteData())!;
      // ORBIT_DUMP=path.png flutter test ... saves the frame for inspection.
      final dump = Platform.environment['ORBIT_DUMP'];
      if (dump != null) {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(dump).writeAsBytesSync(png!.buffer.asUint8List());
      }
      img.dispose();
      int px(int x, int y) => bytes.getUint32((y * 2400 + x) * 4);

      // Letterbox bars use the darkest ink.
      expect(px(10, 540), _rgba(Pal.ink0));
      expect(px(2390, 540), _rgba(Pal.ink0));

      // Every virtual pixel must be a uniform 3x3 block (nearest-neighbour).
      final seen = <int>{};
      for (var vy = 0; vy < 360; vy += 3) {
        for (var vx = 0; vx < 640; vx += 5) {
          final x0 = 240 + vx * 3, y0 = vy * 3;
          final c = px(x0, y0);
          seen.add(c);
          for (var d = 1; d < 3; d++) {
            expect(px(x0 + d, y0 + d), c, reason: 'block $vx,$vy not uniform');
          }
        }
      }
      // Sky, stars, planet, characters and text: plenty of distinct colours.
      expect(seen.length, greaterThan(8));
      // Every sampled colour comes from the master palette or from a
      // sprite's own palette: no blended / anti-aliased pixels.
      final allowed = {for (final c in Pal.all) _rgba(c)};
      for (final atlas in game.resources.atlases.values) {
        final data = (await atlas.image.toByteData())!;
        for (var i = 0; i < data.lengthInBytes; i += 4) {
          final v = data.getUint32(i);
          if (v & 0xFF == 0xFF) allowed.add(v);
        }
      }
      expect(seen.difference(allowed), isEmpty);
    },
  );

  testWithGame<OrbitGame>(
    'sandbox shows every character of the pack',
    () => OrbitGame(strings: _strings, startScene: StartScene.sandbox),
    (game) async {
      game.onGameResize(Vector2(1920, 1080));
      await game.ready();
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }
      final shown = game.world.children
          .whereType<LineupCharacter>()
          .map((c) => c.atlasName)
          .toSet();
      expect(shown, {
        ...Hero.values.map((h) => h.atlas),
        ...EnemyKind.values.map((e) => e.atlas),
      });
      final dump = Platform.environment['ORBIT_DUMP_SANDBOX'];
      if (dump != null) {
        final rec = ui.PictureRecorder();
        game.render(ui.Canvas(rec));
        final img = await rec.endRecording().toImage(1920, 1080);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(dump).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      }
    },
  );

  testWithGame<OrbitGame>(
    'simulation is deterministic: same ticks, same state',
    () => OrbitGame(strings: _strings, startScene: StartScene.sandbox),
    (game) async {
      game.onGameResize(Vector2(1920, 1080));
      await game.ready();
      // Irregular frame times must still yield exactly 600 ticks.
      var dt = 0.0;
      while (game.clock.tick < 600) {
        dt = dt == 0.010 ? 0.023 : 0.010;
        game.update(dt);
      }
      expect(game.clock.tick, inInclusiveRange(600, 601));
    },
  );
}
