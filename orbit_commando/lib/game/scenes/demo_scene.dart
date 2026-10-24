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
import '../roster.dart';

/// Pipeline showcase.
///
/// Title: Roxy chased by a Grunt around a planetoid (preview of circular
/// gravity, M3). Sandbox: every character of the pack lined up, alternating
/// run and attack, to check the imported sprites on a real screen.
class DemoScene extends Component with HasGameReference<OrbitGame> {
  DemoScene({required this.showTitle});

  final bool showTitle;

  @override
  Future<void> onLoad() async {
    game.camera.backdrop.add(Starfield(seed: 1994));
    if (showTitle) {
      _addPlanetChase();
    } else {
      _addLineup();
    }
    game.camera.viewport.add(TitleOverlay(showTitle: showTitle));
  }

  void _addPlanetChase() {
    final planet = game.resources.atlas('planetoid_medium');
    final center = Vector2(0, 52);
    game.world.add(
      makeCrisp(
        SpriteComponent(
          sprite: planet.sprite(0),
          anchor: planet.anchor,
          position: center,
        ),
      ),
    );
    // Sprite radius minus the outline: feet rest on the surface.
    final radius = planet.data.origin.dy - 2;
    game.world.addAll([
      OrbitRunner(
        atlasName: EnemyKind.grunt.atlas,
        planetCenter: center,
        radius: radius,
        startAngle: -0.75,
      ),
      OrbitRunner(
        atlasName: Hero.roxy.atlas,
        planetCenter: center,
        radius: radius,
      ),
    ]);
  }

  void _addLineup() {
    const groundY = 80.0;
    const spacing = 92.0;
    for (final (i, h) in Hero.values.indexed) {
      game.world.add(
        LineupCharacter(
          atlasName: h.atlas,
          label: h.displayName,
          position: Vector2(-138 + i * spacing, groundY - 76),
          phase: i,
        ),
      );
    }
    for (final (i, e) in EnemyKind.values.indexed) {
      game.world.add(
        LineupCharacter(
          atlasName: e.atlas,
          label: e.displayName,
          position: Vector2(-138 + i * spacing, groundY),
          phase: i + 2,
          facingLeft: true,
        ),
      );
    }
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

/// A character running around a planetoid: a preview of circular gravity.
class OrbitRunner extends SpriteAnimationComponent
    with HasGameReference<OrbitGame>, FixedTick {
  OrbitRunner({
    required this.atlasName,
    required this.planetCenter,
    required this.radius,
    double startAngle = 0,
  }) : _theta = startAngle;

  final String atlasName;
  final Vector2 planetCenter;
  final double radius;
  double _theta;

  @override
  Future<void> onLoad() async {
    final atlas = game.resources.atlas(atlasName);
    animation = atlas.animation('run');
    size = atlas.frameSize;
    anchor = atlas.anchor;
    makeCrisp(this);
    _place();
  }

  @override
  void fixedUpdate(int tick) {
    // ~1.2 px per tick along the surface: a brisk run.
    _theta += 1.2 / radius;
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

/// One character of the sandbox lineup: alternates run and attack loops.
class LineupCharacter extends SpriteAnimationGroupComponent<String>
    with HasGameReference<OrbitGame>, FixedTick {
  LineupCharacter({
    required this.atlasName,
    required this.label,
    required super.position,
    required this.phase,
    this.facingLeft = false,
  });

  final String atlasName;
  final String label;
  final int phase;
  final bool facingLeft;

  @override
  Future<void> onLoad() async {
    final atlas = game.resources.atlas(atlasName);
    animations = {
      for (final name in atlas.data.animations.keys)
        name: atlas.animation(name),
    };
    current = 'run';
    size = atlas.frameSize;
    anchor = atlas.anchor;
    makeCrisp(this);
    // Atlases face right; enemies face the heroes.
    if (facingLeft) flipHorizontally();
  }

  @override
  void fixedUpdate(int tick) {
    // Switch every 2 s, staggered per character.
    current = ((tick ~/ 120) + phase).isEven ? 'run' : 'attack';
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final font = game.resources.font;
    // Label under the feet, in local (unflipped) space.
    canvas.save();
    if (facingLeft) {
      canvas
        ..translate(size.x, 0)
        ..scale(-1, 1);
    }
    font.draw(
      canvas,
      label,
      anchor.x * size.x,
      size.y + 2,
      color: Pal.ink6,
      align: PixelTextAlign.center,
    );
    canvas.restore();
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
        12,
        color: Pal.gold6,
        shadow: Pal.ember2,
        align: PixelTextAlign.center,
      );
      if ((_time * 2).floor().isEven) {
        font.draw(
          canvas,
          s.pressStart,
          cx,
          28,
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
