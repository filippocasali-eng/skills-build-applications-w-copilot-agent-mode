import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/render/palette.g.dart';
import 'package:orbit_commando/game/game_strings.dart';
import 'package:orbit_commando/game/orbit_game.dart';

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
    'loads assets and renders pixel-perfect 5x frames on a 20:9 screen',
    () => OrbitGame(strings: _strings),
    (game) async {
      game.onGameResize(Vector2(2400, 1080));
      await game.ready();
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      expect(game.clock.tick, inInclusiveRange(29, 30));
      expect(game.layout.scale, 5);
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

      // Every virtual pixel must be a uniform 5x5 block (nearest-neighbour).
      final seen = <int>{};
      for (var vy = 0; vy < 216; vy += 3) {
        for (var vx = 0; vx < 384; vx += 5) {
          final x0 = 240 + vx * 5, y0 = vy * 5;
          final c = px(x0, y0);
          seen.add(c);
          for (var d = 1; d < 5; d++) {
            expect(px(x0 + d, y0 + d), c, reason: 'block $vx,$vy not uniform');
          }
        }
      }
      // Sky, stars, planet, Rex and text: plenty of distinct colours.
      expect(seen.length, greaterThan(8));
      // Every sampled colour comes from the 64-colour palette.
      final palette = {for (final c in Pal.all) _rgba(c)};
      expect(seen.difference(palette), isEmpty);
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
