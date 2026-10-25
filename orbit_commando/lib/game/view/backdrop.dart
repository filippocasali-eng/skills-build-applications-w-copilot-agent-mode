import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/render/palette.g.dart';
import '../../engine/render/virtual_screen.dart';
import '../levels/level_data.dart';
import '../play_game.dart';

/// Screen-space parallax background for the level's theme. Not rotated by
/// the camera, so it stays calm while the world turns.
class Backdrop extends Component with HasGameReference<PlayGame> {
  late final Image _image;
  final Paint _p = Paint()..filterQuality = FilterQuality.none;
  final Paint _star = Paint()..isAntiAlias = false;

  @override
  Future<void> onLoad() async {
    final path = switch (game.sim.level.theme) {
      LevelTheme.asteroids => 'sprites/bg_asteroids.png',
      LevelTheme.station => 'sprites/bg_station.png',
      LevelTheme.glorbo => 'sprites/bg_glorbo.png',
    };
    _image = game.res.image(path);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawColor(Pal.space0, BlendMode.src);
    final cam = game.camera.viewfinder.position;
    final w = _image.width.toDouble();
    // Far layer: 8% parallax, wraps horizontally.
    final ox = -((cam.x * 0.08) % w);
    final oy = (-(cam.y - 600) * 0.04).clamp(-40.0, 0.0);
    for (var x = ox; x < VirtualScreen.width; x += w) {
      canvas.drawImage(
        _image,
        Offset(x.floorToDouble(), oy.floorToDouble()),
        _p,
      );
    }
    // Near star layer (asteroids only): 25% parallax.
    if (game.sim.level.theme == LevelTheme.asteroids) {
      for (var i = 0; i < 70; i++) {
        final sx = (i * 137.0 - cam.x * 0.25) % VirtualScreen.width;
        final sy = (i * 71.0 - cam.y * 0.05) % VirtualScreen.height;
        _star.color = i % 7 == 0
            ? Pal.gold6
            : (i % 3 == 0 ? Pal.ink7 : Pal.space5);
        canvas.drawRect(
          Rect.fromLTWH(
            (sx < 0 ? sx + VirtualScreen.width : sx).floorToDouble(),
            (sy < 0 ? sy + VirtualScreen.height : sy).floorToDouble(),
            1,
            1,
          ),
          _star,
        );
      }
    }
  }
}
