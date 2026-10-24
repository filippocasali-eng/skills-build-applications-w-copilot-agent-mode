import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/loop/fixed_tick.dart';
import '../../engine/math/det_random.dart';
import '../../engine/render/bitmap_font.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/sprite_atlas.dart';
import '../../engine/render/virtual_screen.dart';
import '../orbit_game.dart';

/// M1 pipeline showcase: starfield, a planetoid and Rex running around it.
/// Used as the title backdrop until the attract mode (M8) replaces it.
class DemoScene extends Component with HasGameReference<OrbitGame> {
  DemoScene({required this.showTitle});

  final bool showTitle;

  @override
  Future<void> onLoad() async {
    final res = game.resources;
    game.camera.backdrop.add(Starfield(seed: 1994));

    final planetAtlas = res.atlas('planetoid_small');
    final planetCenter = Vector2(0, 24);
    game.world.add(
      makeCrisp(
        SpriteComponent(
          sprite: planetAtlas.sprite(0),
          anchor: planetAtlas.anchor,
          position: planetCenter,
        ),
      ),
    );
    game.world.add(
      OrbitRunner(
        planetCenter: planetCenter,
        radius: planetAtlas.data.origin.dy - 2,
      ),
    );
    game.camera.viewport.add(TitleOverlay(showTitle: showTitle));
  }
}

/// Three parallax layers of stars, generated from a fixed seed.
class Starfield extends Component with FixedTick {
  Starfield({required int seed}) {
    final rng = DetRandom(seed);
    for (var i = 0; i < _count; i++) {
      _x[i] = rng.nextDouble() * VirtualScreen.width;
      _y[i] = rng.nextDouble() * VirtualScreen.height;
      _layer[i] = rng.nextInt(3);
      _phase[i] = rng.nextInt(64);
    }
  }

  static const _count = 120;
  static const _speeds = [0.05, 0.12, 0.3];
  static final _paints = [
    Paint()..color = Pal.space4,
    Paint()..color = Pal.space6,
    Paint()..color = Pal.ink7,
  ];
  static final _twinkle = Paint()..color = Pal.gold6;

  final _x = List<double>.filled(_count, 0);
  final _y = List<double>.filled(_count, 0);
  final _layer = List<int>.filled(_count, 0);
  final _phase = List<int>.filled(_count, 0);
  int _tick = 0;

  @override
  void fixedUpdate(int tick) {
    _tick = tick;
    for (var i = 0; i < _count; i++) {
      _x[i] -= _speeds[_layer[i]];
      if (_x[i] < 0) _x[i] += VirtualScreen.width;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawColor(Pal.space0, BlendMode.src);
    for (var i = 0; i < _count; i++) {
      final twinkle = _layer[i] == 2 && ((_tick + _phase[i] * 7) % 90) < 6;
      canvas.drawRect(
        Rect.fromLTWH(_x[i].floorToDouble(), _y[i].floorToDouble(), 1, 1),
        twinkle ? _twinkle : _paints[_layer[i]],
      );
    }
  }
}

/// Rex running around the planetoid: a preview of circular gravity (M3).
class OrbitRunner extends SpriteAnimationComponent
    with HasGameReference<OrbitGame>, FixedTick {
  OrbitRunner({required this.planetCenter, required this.radius});

  final Vector2 planetCenter;
  final double radius;
  double _theta = 0;

  @override
  Future<void> onLoad() async {
    final atlas = game.resources.atlas('player_rex');
    animation = atlas.animation('run');
    size = atlas.frameSize;
    anchor = atlas.anchor;
    makeCrisp(this);
    _place();
  }

  @override
  void fixedUpdate(int tick) {
    // ~1.1 px per tick along the surface: a brisk jog.
    _theta += 1.1 / radius;
    if (_theta > math.pi * 2) _theta -= math.pi * 2;
    _place();
  }

  void _place() {
    // "Up" points away from the planet centre, so the sprite stands on it.
    position.setValues(
      planetCenter.x + math.sin(_theta) * radius,
      planetCenter.y - math.cos(_theta) * radius,
    );
    angle = _theta;
  }
}

/// Title text drawn with the bitmap font at virtual resolution.
class TitleOverlay extends Component with HasGameReference<OrbitGame> {
  TitleOverlay({required this.showTitle});

  final bool showTitle;
  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    final font = game.resources.font;
    final s = game.strings;
    const cx = VirtualScreen.width / 2;
    if (showTitle) {
      font.draw(
        canvas,
        s.title,
        cx,
        14,
        color: Pal.gold6,
        shadow: Pal.ember2,
        align: PixelTextAlign.center,
      );
      if ((_time * 2).floor().isEven) {
        font.draw(
          canvas,
          s.pressStart,
          cx,
          186,
          color: Pal.ink7,
          shadow: Pal.space2,
          align: PixelTextAlign.center,
        );
      }
      font.draw(
        canvas,
        s.credits,
        VirtualScreen.width - 6,
        VirtualScreen.height - 12,
        color: Pal.ink5,
        align: PixelTextAlign.right,
      );
    } else {
      font.draw(canvas, s.sandbox, 6, 6, color: Pal.aqua6, shadow: Pal.ink0);
    }
    font.draw(
      canvas,
      '${game.fps.round()} FPS',
      6,
      VirtualScreen.height - 12,
      color: Pal.moss6,
    );
  }
}
