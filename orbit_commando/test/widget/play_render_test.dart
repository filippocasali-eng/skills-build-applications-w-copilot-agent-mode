import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/game/input/input_source.dart';
import 'package:orbit_commando/game/levels/tiled_loader.dart';
import 'package:orbit_commando/game/play_config.dart';
import 'package:orbit_commando/game/play_game.dart';

Future<void> dump(PlayGame game, String? path) async {
  if (path == null) return;
  final rec = ui.PictureRecorder();
  game.render(ui.Canvas(rec));
  final img = await rec.endRecording().toImage(1920, 1080);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  img.dispose();
}

PlayGame gameFor(String id, {InputSource? input, bool rotating = true}) {
  final level = TiledLoader.parse(
    File('assets/levels/$id.tmj').readAsStringSync(),
  );
  return PlayGame(
    config: PlayConfig(level: level, levelNumber: 3, rotatingCamera: rotating),
    input: input,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['ORBIT_DUMP_DIR'];

  for (final id in ['w1_l1', 'w2_l1', 'w3_l1', 'w1_l5']) {
    testWithGame<PlayGame>(
      '$id renders while the autopilot plays',
      () => gameFor(id, input: AutoPilot()),
      (game) async {
        game.onGameResize(Vector2(1920, 1080));
        await game.ready();
        for (var shot = 0; shot < 4; shot++) {
          for (var i = 0; i < 150 * (shot + 1); i++) {
            game.update(1 / 60);
          }
          await dump(game, dir == null ? null : '$dir/${id}_$shot.png');
        }
        expect(game.sim.tick, greaterThan(1000));
        expect(game.sim.tick, greaterThan(0));
      },
    );
  }
}
