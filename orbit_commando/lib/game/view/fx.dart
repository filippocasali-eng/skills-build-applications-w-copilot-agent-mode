import 'dart:math' as math;
import 'dart:ui';

import '../../engine/render/bitmap_font.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/sprite_atlas.dart';
import '../game_resources.dart';

enum FxKind { anim, debris, text, shell, flash }

class Particle {
  FxKind kind = FxKind.anim;
  bool active = false;
  double x = 0, y = 0, vx = 0, vy = 0, gx = 0, gy = 0;
  double age = 0, life = 1, scale = 1, angle = 0, spin = 0;
  String atlas = 'fx';
  String anim = 'spark';
  String text = '';
  Color color = Pal.ink7;
}

/// Render-only particles (explosions, sparks, debris, score popups).
/// Fed from simulation events; never affects gameplay.
class Fx {
  Fx(this.res) : _pool = List.generate(_capacity, (_) => Particle());

  static const _capacity = 320;
  final GameResources res;
  final List<Particle> _pool;
  final math.Random _r = math.Random(7);

  /// Full-screen white flash (big explosions), seconds left.
  double flash = 0;

  /// Screen shake strength in pixels (decays).
  double shake = 0;

  Particle? _get() {
    for (final p in _pool) {
      if (!p.active) {
        p
          ..active = true
          ..age = 0
          ..vx = 0
          ..vy = 0
          ..gx = 0
          ..gy = 0
          ..scale = 1
          ..angle = 0
          ..spin = 0;
        return p;
      }
    }
    return null;
  }

  double _rand(double a, double b) => a + _r.nextDouble() * (b - a);

  void anim(String atlas, String name, double x, double y, {double scale = 1}) {
    final a = res.atlas(atlas).data.animations[name];
    if (a == null) return;
    final p = _get();
    if (p == null) return;
    p
      ..kind = FxKind.anim
      ..atlas = atlas
      ..anim = name
      ..x = x
      ..y = y
      ..scale = scale
      ..life = a.frames.length / a.fps;
  }

  void explosion(
    double x,
    double y, {
    int size = 1,
    double gx = 0,
    double gy = 0.2,
  }) {
    final s = size >= 2 ? 1.6 : (size <= 0 ? 0.6 : 1.0);
    anim('explosion', 'boom', x, y, scale: s);
    if (size >= 2) {
      for (var i = 0; i < 3; i++) {
        anim(
          'explosion',
          'boom',
          x + _rand(-24, 24),
          y + _rand(-24, 24),
          scale: 0.8,
        );
      }
      flash = math.max(flash, 0.06);
    }
    shake = math.max(shake, size >= 2 ? 6 : 3);
    debris(x, y, count: size >= 2 ? 10 : 5, gx: gx, gy: gy);
    smoke(x, y, count: size >= 2 ? 4 : 2);
  }

  void debris(
    double x,
    double y, {
    int count = 5,
    double gx = 0,
    double gy = 0.2,
  }) {
    for (var i = 0; i < count; i++) {
      final p = _get();
      if (p == null) return;
      final a = _rand(0, math.pi * 2);
      final sp = _rand(1.5, 4.5);
      p
        ..kind = FxKind.debris
        ..atlas = 'fx'
        ..anim = 'debris'
        ..x = x
        ..y = y
        ..vx = math.cos(a) * sp
        ..vy = math.sin(a) * sp - 2
        ..gx = gx
        ..gy = gy
        ..spin = _rand(-0.4, 0.4)
        ..life = _rand(0.5, 1.0);
    }
  }

  void smoke(double x, double y, {int count = 2}) {
    for (var i = 0; i < count; i++) {
      anim('fx', 'smoke', x + _rand(-12, 12), y + _rand(-12, 12));
    }
  }

  void spark(double x, double y) => anim('fx', 'spark', x, y);

  void muzzle(double x, double y) => anim('fx', 'muzzle', x, y);

  void shell(double x, double y, double ux, double uy) {
    final p = _get();
    if (p == null) return;
    p
      ..kind = FxKind.shell
      ..atlas = 'fx'
      ..anim = 'shell'
      ..x = x
      ..y = y
      ..vx = -ux * 1.5 + _rand(-1, 1)
      ..vy = -uy * 1.5 - 1.5
      ..gx = -ux * 0.25
      ..gy = -uy * 0.25
      ..spin = 0.5
      ..life = 0.6;
  }

  void text(String t, double x, double y, Color c, {double life = 0.9}) {
    final p = _get();
    if (p == null) return;
    p
      ..kind = FxKind.text
      ..text = t
      ..x = x
      ..y = y
      ..vy = -0.6
      ..color = c
      ..life = life;
  }

  void update(double dt) {
    final steps = dt * 60;
    if (flash > 0) flash -= dt;
    shake *= math.pow(0.0005, dt).toDouble();
    if (shake < 0.3) shake = 0;
    for (final p in _pool) {
      if (!p.active) continue;
      p.age += dt;
      if (p.age >= p.life) {
        p.active = false;
        continue;
      }
      p.vx += p.gx * steps;
      p.vy += p.gy * steps;
      p.x += p.vx * steps;
      p.y += p.vy * steps;
      p.angle += p.spin * steps;
    }
  }

  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  void render(Canvas canvas, BitmapFont font) {
    for (final p in _pool) {
      if (!p.active) continue;
      if (p.kind == FxKind.text) {
        if (p.age > p.life * 0.7 && ((p.age * 20).floor().isEven)) continue;
        font.draw(
          canvas,
          p.text,
          p.x,
          p.y,
          color: p.color,
          shadow: Pal.ink0,
          align: PixelTextAlign.center,
        );
        continue;
      }
      final atlas = res.atlas(p.atlas);
      final f = atlas.frameAt(p.anim, p.age);
      drawFrame(
        canvas,
        atlas,
        f,
        p.x,
        p.y,
        angle: p.angle,
        scale: p.scale,
        paint: _paint,
      );
    }
  }
}

/// Draws one atlas frame with its origin at (x,y), rotated and mirrored.
void drawFrame(
  Canvas canvas,
  SpriteAtlas atlas,
  int frame,
  double x,
  double y, {
  double angle = 0,
  bool flipX = false,
  double scale = 1,
  Paint? paint,
}) {
  final o = atlas.data.origin;
  final r = atlas.data.frames[frame];
  canvas.save();
  canvas.translate(x.roundToDouble(), y.roundToDouble());
  if (angle != 0) canvas.rotate(angle);
  if (flipX || scale != 1) canvas.scale(flipX ? -scale : scale, scale);
  canvas.drawImageRect(
    atlas.image,
    r,
    Rect.fromLTWH(-o.dx, -o.dy, r.width, r.height),
    paint ?? _crisp,
  );
  canvas.restore();
}

final Paint _crisp = Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;
