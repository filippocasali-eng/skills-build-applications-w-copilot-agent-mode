import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/physics/gravity.dart';
import '../../engine/render/bitmap_font.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/sprite_atlas.dart';
import '../bosses/bosses.dart';
import '../enemies/enemies.dart';
import '../levels/level_data.dart';
import '../pickups/items.dart';
import '../play_game.dart';
import '../player/player.dart';
import '../sim/balance.dart';
import '../vehicles/vehicles.dart';
import '../weapons/weapons.dart';
import 'fx.dart';

/// Draws the level and every simulated entity, in world space.
/// Immediate mode: reads the simulation each frame, owns no game state
/// except purely visual smoothing (sprite angles, animation clocks).
class WorldRenderer extends Component with HasGameReference<PlayGame> {
  late final List<Path> _solidPaths;
  late final List<_Edge> _edges;
  late final Paint _terrain;
  late final Color _edgeColor;
  late final Color _edgeShade;

  final Paint _p = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _flash = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(
      Color(0xFFFFFFFF),
      BlendMode.srcATop,
    );
  final Paint _line = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke;
  final Paint _fill = Paint()..isAntiAlias = false;

  /// Smoothed visual angles per body (sprites turn gently).
  final Map<Object, double> _angles = {};

  /// Gravity "up" angle at fixed props (beacons, hints, exit).
  final Map<Object, double> _propAngles = {};
  final GravitySample _gs = GravitySample();

  @override
  Future<void> onLoad() async {
    final level = game.sim.level;
    _solidPaths = [
      for (final poly in level.solids)
        Path()..addPolygon([for (final p in poly) Offset(p.x, p.y)], true),
    ];
    _edges = [];
    for (final poly in level.solids) {
      final pts = LevelData.signedArea(poly) >= 0
          ? poly
          : poly.reversed.toList();
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        final dx = b.x - a.x, dy = b.y - a.y;
        final l = math.sqrt(dx * dx + dy * dy);
        if (l < 1) continue;
        _edges.add(_Edge(a.x, a.y, b.x, b.y, dy / l, -dx / l));
      }
    }
    final theme = level.theme.name;
    final tex = game.textureFor(theme);
    _terrain = Paint()
      ..isAntiAlias = false
      ..shader = ImageShader(
        tex,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: FilterQuality.none,
      );
    final (edge, shade) = switch (level.theme) {
      LevelTheme.asteroids => (Pal.clay6, Pal.clay4),
      LevelTheme.station => (Pal.ink5, Pal.gold5),
      LevelTheme.glorbo => (Pal.moss6, Pal.moss4),
    };
    _edgeColor = edge;
    _edgeShade = shade;
  }

  double _smooth(Object key, double target, {double rate = 0.25}) {
    final cur = _angles[key];
    if (cur == null) {
      _angles[key] = target;
      return target;
    }
    var d = target - cur;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    // Big flips (field switches) snap faster.
    final v = cur + d * (d.abs() > 1.2 ? 0.35 : rate);
    _angles[key] = v;
    return v;
  }

  double _upAngleAt(Object key, double x, double y) =>
      _propAngles.putIfAbsent(key, () {
        game.sim.gravity.sample(x, y - 4, _gs);
        if (_gs.isZero) return 0;
        return math.atan2(-_gs.dx, _gs.dy);
      });

  double get _t => game.time;

  late final bool _bigHeads = game.config.cheats.contains('bigHeads');

  void _drawChar(
    Canvas canvas,
    SpriteAtlas atlas,
    int frame,
    double x,
    double y, {
    double angle = 0,
    bool flipX = false,
    Paint? paint,
  }) => (_bigHeads ? drawFrameBigHead : drawFrame)(
    canvas,
    atlas,
    frame,
    x,
    y,
    angle: angle,
    flipX: flipX,
    paint: paint,
  );

  @override
  void render(Canvas canvas) {
    final sim = game.sim;
    _drawZones(canvas);
    _drawPlanets(canvas);
    _drawTerrain(canvas);
    _drawProps(canvas);
    for (final h in sim.items.hostages) {
      _drawHostage(canvas, h);
    }
    for (final k in sim.items.pickups) {
      _drawPickup(canvas, k);
    }
    for (final c in sim.items.cassettes) {
      if (!c.taken) _drawCassette(canvas, c);
    }
    for (final v in sim.vehicles.list) {
      if (!v.destroyed) _drawVehicle(canvas, v);
    }
    for (final e in sim.enemies) {
      _drawEnemy(canvas, e);
    }
    final b = sim.bosses.boss;
    if (b != null) _drawBoss(canvas, b);
    _drawGhost(canvas);
    _drawPlayer(canvas, sim.player);
    _drawBullets(canvas);
    game.fx.render(canvas, game.res.font);
  }

  // ---------------------------------------------------------------- level --

  void _drawZones(Canvas canvas) {
    for (final z in game.sim.level.zones) {
      if (z.kind == GravityKind.zero) {
        // Floating dust motes.
        _fill.color = Pal.space3;
        final w = z.x1 - z.x0, h = z.y1 - z.y0;
        for (var i = 0; i < (w * h / 9000).clamp(8, 120); i++) {
          final px = z.x0 + ((i * 97.13 + _t * 6 * (1 + i % 3)) % w);
          final py = z.y0 + ((i * 53.71 + math.sin(_t + i) * 8) % h);
          canvas.drawRect(
            Rect.fromLTWH(px.floorToDouble(), py.floorToDouble(), 1, 1),
            _fill,
          );
        }
      } else if (z.kind == GravityKind.uniform && z.gy < 0) {
        // Gravity-flip zone: chevrons pointing up.
        _line
          ..color = Pal.neon2
          ..strokeWidth = 1;
        for (var x = z.x0 + 20; x < z.x1 - 10; x += 48) {
          final y = (z.y0 + z.y1) / 2 - ((_t * 30) % 24);
          canvas.drawLine(Offset(x - 6, y + 6), Offset(x, y), _line);
          canvas.drawLine(Offset(x, y), Offset(x + 6, y + 6), _line);
        }
      }
    }
  }

  void _drawPlanets(Canvas canvas) {
    for (final p in game.sim.level.planets) {
      final img = game.planetImage(p);
      if (img == null) {
        _fill.color = Pal.clay3;
        canvas.drawCircle(Offset(p.cx, p.cy), p.radius, _fill);
        continue;
      }
      canvas.drawImage(
        img,
        Offset(p.cx - img.width / 2, p.cy - img.height / 2),
        _p,
      );
    }
  }

  void _drawTerrain(Canvas canvas) {
    for (final path in _solidPaths) {
      canvas.drawPath(path, _terrain);
    }
    // Lit top edges, shaded under-sides, dark outline.
    _line.strokeWidth = 3;
    for (final e in _edges) {
      if (e.ny < -0.6) {
        _line.color = _edgeColor;
        canvas.drawLine(Offset(e.ax, e.ay + 1), Offset(e.bx, e.by + 1), _line);
      } else if (e.ny > 0.6) {
        _line.color = _edgeShade;
        canvas.drawLine(Offset(e.ax, e.ay - 1), Offset(e.bx, e.by - 1), _line);
      }
    }
    _line
      ..strokeWidth = 1
      ..color = Pal.ink0;
    for (final e in _edges) {
      canvas.drawLine(Offset(e.ax, e.ay), Offset(e.bx, e.by), _line);
    }
    // One-way platforms: girders.
    for (final line in game.sim.level.platforms) {
      for (var i = 0; i + 1 < line.length; i++) {
        final a = line[i], b = line[i + 1];
        _line
          ..strokeWidth = 6
          ..color = Pal.ink3;
        canvas.drawLine(Offset(a.x, a.y + 3), Offset(b.x, b.y + 3), _line);
        _line
          ..strokeWidth = 2
          ..color = _edgeColor;
        canvas.drawLine(Offset(a.x, a.y + 1), Offset(b.x, b.y + 1), _line);
        _line.color = Pal.ink0;
        _line.strokeWidth = 1;
        for (var x = math.min(a.x, b.x) + 6; x < math.max(a.x, b.x); x += 12) {
          canvas.drawLine(Offset(x, a.y + 2), Offset(x + 6, a.y + 6), _line);
        }
      }
    }
  }

  void _drawProps(Canvas canvas) {
    final sim = game.sim;
    final beacon = game.res.atlas('beacon');
    for (final cp in sim.items.checkpoints) {
      final f = beacon.frameAt(cp.reached ? 'on' : 'off', _t);
      drawFrame(
        canvas,
        beacon,
        f,
        cp.x,
        cp.y,
        angle: _upAngleAt(cp, cp.x, cp.y),
      );
    }
    final exit = sim.level.exit;
    if (exit != null) {
      final sign = game.res.atlas('exit_sign');
      final x = (exit.x0 + exit.x1) / 2;
      drawFrame(
        canvas,
        sign,
        sign.frameAt('idle', _t),
        x,
        exit.y1,
        angle: _upAngleAt(exit, x, exit.y1),
      );
    }
    // Contextual tutorial icons (disappear after first use).
    final icons = game.res.atlas('icons');
    for (final h in sim.level.ofType('hint')) {
      final icon = h.str('icon');
      if (game.hintDone(icon)) continue;
      if (!icons.has(icon)) continue;
      final bob = math.sin(_t * 4) * 3;
      final a = _upAngleAt(h, h.x, h.y);
      final ox = math.sin(a) * (60 + bob), oy = -math.cos(a) * (60 + bob);
      if ((_t * 3).floor() % 4 == 3) continue;
      drawFrame(
        canvas,
        icons,
        icons.frameAt(icon, 0),
        h.x + ox,
        h.y + oy,
        angle: a,
      );
    }
  }

  // ------------------------------------------------------------- entities --

  void _drawHostage(Canvas canvas, Hostage h) {
    if (h.state == HostageState.gone) return;
    final a = game.res.atlas('hostage');
    final anim = switch (h.state) {
      HostageState.tied => 'tied',
      HostageState.waving => 'wave',
      _ => 'run',
    };
    final ang = _smooth(h, h.body.angle);
    final flip = h.state == HostageState.leaving && h.body.vr < 0;
    drawFrame(
      canvas,
      a,
      a.frameAt(anim, _t),
      h.body.x,
      h.body.y,
      angle: ang,
      flipX: flip,
    );
    if (h.state == HostageState.tied && (_t * 2).floor().isEven) {
      final ox = math.sin(ang) * 46, oy = -math.cos(ang) * 46;
      game.res.font.draw(
        canvas,
        'HELP!',
        h.body.x + ox,
        h.body.y + oy - 4,
        color: Pal.gold7,
        shadow: Pal.ink0,
        align: PixelTextAlign.center,
      );
    }
  }

  void _drawPickup(Canvas canvas, Pickup k) {
    if (k.dropped && k.life < 120 && (k.life ~/ 4).isEven) return;
    final a = game.res.atlas('items');
    final name = a.has(k.item) ? k.item : 'grenade';
    final bob = math.sin(_t * 5 + k.x) * 2;
    drawFrame(canvas, a, a.frameAt(name, 0), k.x, k.y + 12 + bob);
  }

  void _drawCassette(Canvas canvas, Cassette c) {
    final a = game.res.atlas('items');
    final bob = math.sin(_t * 3 + c.index) * 3;
    drawFrame(canvas, a, a.frameAt('cassette', 0), c.x, c.y + 12 + bob);
    // sparkle
    if ((_t * 6 + c.index).floor() % 6 == 0) game.fx.spark(c.x + 8, c.y - 4);
  }

  void _drawVehicle(Canvas canvas, Vehicle v) {
    final name = v.kind.name;
    final a = game.res.atlas(name);
    final ang = _smooth(v, v.body.angle);
    String anim;
    switch (v.kind) {
      case VehicleKind.mech:
        anim = v.squash > 0
            ? 'squash'
            : !v.body.grounded
            ? 'jump'
            : v.body.vr.abs() > 0.3
            ? 'run'
            : 'idle';
      case VehicleKind.bike:
        anim = v.occupied ? 'run' : 'idle';
      case VehicleKind.shuttle:
        anim = 'idle';
    }
    final paint = v.flash > 0 ? _flash : _p;
    final flip = v.facing < 0;
    if (v.kind == VehicleKind.bike && v.occupied) {
      // Rider sits on the seat.
      final hero = game.res.atlas(game.heroAtlas);
      final ox = math.sin(ang) * 22, oy = -math.cos(ang) * 22;
      drawFrame(
        canvas,
        hero,
        hero.frameAt('jump', 0),
        v.body.x + ox,
        v.body.y + oy,
        angle: ang,
        flipX: flip,
      );
    }
    if (v.kind == VehicleKind.shuttle) {
      drawFrame(
        canvas,
        a,
        a.frameAt(anim, _t),
        v.cx,
        v.cy,
        angle: ang,
        paint: paint,
      );
    } else {
      drawFrame(
        canvas,
        a,
        a.frameAt(anim, _t),
        v.body.x,
        v.body.y,
        angle: ang,
        flipX: flip,
        paint: paint,
      );
    }
    if (!v.occupied && !game.sim.player.inVehicle && (_t * 2).floor().isEven) {
      final ox = math.sin(ang) * (v.body.height + 18);
      final oy = -math.cos(ang) * (v.body.height + 18);
      game.res.font.draw(
        canvas,
        'GET IN!',
        v.body.x + ox,
        v.body.y + oy,
        color: Pal.aqua7,
        shadow: Pal.ink0,
        align: PixelTextAlign.center,
      );
    }
  }

  void _drawEnemy(Canvas canvas, Enemy e) {
    if (!e.alive && e.removeTimer < 30) return; // exploded
    final atlas = game.res.atlas(e.type);
    final ang = _smooth(e, e.body.angle);
    String anim;
    switch (e.mode) {
      case EnemyMode.tell:
        anim = atlas.has('tell') ? 'tell' : 'attack';
      case EnemyMode.attack:
        anim = 'attack';
      case EnemyMode.special:
        anim = atlas.has('jump') ? 'jump' : 'run';
      default:
        anim = (e.flying || e.body.vr.abs() > 0.15) ? 'run' : 'idle';
    }
    var time = _t + e.id * 0.37;
    // Pack sprites: tell = first attack frame, frozen.
    if (e.mode == EnemyMode.tell && !atlas.has('tell')) time = 0;
    final paint = e.flash > 0 || !e.alive ? _flash : _p;
    final x = e.flying ? e.x : e.feetX;
    final y = e.flying ? e.cy : e.feetY;
    _drawChar(
      canvas,
      atlas,
      atlas.frameAt(anim, time),
      x,
      y,
      angle: ang,
      flipX: e.facing < 0,
      paint: paint,
    );

    if (!e.alive) return;
    // Attack tell: blinking "!" above the head (>= 300 ms by design).
    if (e.mode == EnemyMode.tell && (_t * 10).floor().isEven) {
      final h = e.spec.height + 14;
      final ox = math.sin(ang) * h, oy = -math.cos(ang) * h;
      game.res.font.draw(
        canvas,
        '!',
        x + ox,
        y + oy - 5,
        color: Pal.ember5,
        shadow: Pal.ink0,
        align: PixelTextAlign.center,
        scale: 2,
      );
    }
    if (e.type == 'sniper' && e.mode == EnemyMode.tell) {
      final locked = e.timer <= 18;
      if (!locked || (_t * 16).floor().isEven) {
        _line
          ..strokeWidth = 1
          ..color = locked ? Pal.ember6 : Pal.ember4;
        canvas.drawLine(Offset(e.x, e.cy - 8), Offset(e.aimX, e.aimY), _line);
      }
    }
    if (e.type == 'jelly' && (e.pulsing || e.mode == EnemyMode.tell)) {
      _line
        ..strokeWidth = e.pulsing ? 2 : 1
        ..color = e.pulsing ? Pal.aqua6 : Pal.aqua3;
      final r = e.pulsing
          ? e.spec.range
          : e.spec.range * (1 - e.timer / e.spec.tell);
      canvas.drawCircle(Offset(e.x, e.cy), r, _line);
    }
  }

  final Paint _ghostPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(
      Color(0x8871E2D2),
      BlendMode.srcATop,
    );

  /// The weekly-challenge ghost: your best run, replayed as a cyan shadow.
  void _drawGhost(Canvas canvas) {
    final g = game.ghost;
    if (g == null || g.isEmpty) return;
    final i = (game.sim.tick ~/ 4) * 3;
    if (i + 2 >= g.length) return;
    if ((game.sim.tick ~/ 2).isEven) return; // flicker, 90s style
    final hero = game.res.atlas(game.heroAtlas);
    drawFrame(
      canvas,
      hero,
      hero.frameAt('run', _t),
      g[i],
      g[i + 1],
      angle: g[i + 2],
      paint: _ghostPaint,
    );
  }

  void _drawPlayer(Canvas canvas, Player p) {
    if (p.inVehicle) return;
    final hero = game.res.atlas(game.heroAtlas);
    final ang = _smooth(p, p.body.angle, rate: 0.3);
    if (p.dead) return;
    if (p.invuln > 0 && (p.invuln ~/ 3).isEven) return;
    final recentlyFired = game.ticksSinceShot < 10;
    String anim;
    switch (p.state) {
      case PlayerState.run:
        anim = 'run';
      case PlayerState.jump || PlayerState.fall || PlayerState.jetpack:
        anim = 'jump';
      case PlayerState.dash:
        anim = 'run';
      default:
        anim = recentlyFired ? 'attack' : 'idle';
    }
    final flip = p.facing < 0;
    final crouch = p.crouching ? 0.82 : 1.0;
    canvas.save();
    if (crouch != 1) {
      // Squash towards the feet for the crouch pose.
      canvas.translate(p.body.x, p.body.y);
      canvas.rotate(ang);
      canvas.scale(1, crouch);
      canvas.rotate(-ang);
      canvas.translate(-p.body.x, -p.body.y);
    }
    final paint = p.hurtTimer > 0 ? _flash : _p;
    _drawChar(
      canvas,
      hero,
      hero.frameAt(anim, game.time),
      p.body.x,
      p.body.y,
      angle: ang,
      flipX: flip,
      paint: paint,
    );
    canvas.restore();
    if (p.dashing) {
      // after-images
      for (var i = 1; i <= 2; i++) {
        _fill.color = Pal.aqua4.withValues(alpha: 0.4 / i);
        final bx = p.body.x - p.body.rx * p.facing * 14 * i;
        final by = p.body.y - p.body.ry * p.facing * 14 * i;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(bx + p.body.ux * 30, by + p.body.uy * 30),
            width: 10,
            height: 40,
          ),
          _fill,
        );
      }
    }
    if (p.shieldTicks > 0) {
      _line
        ..strokeWidth = 2
        ..color = (p.shieldTicks < 120 && (p.shieldTicks ~/ 6).isEven)
            ? Pal.aqua3
            : Pal.aqua6;
      canvas.drawCircle(Offset(p.cx, p.cy), 40, _line);
    }
    if (p.laserOn) {
      _line
        ..strokeWidth = 5
        ..color = (_t * 30).floor().isEven ? Pal.aqua5 : Pal.aqua4;
      canvas.drawLine(
        Offset(p.laserX0, p.laserY0),
        Offset(p.laserX1, p.laserY1),
        _line,
      );
      _line
        ..strokeWidth = 1
        ..color = Pal.ink7;
      canvas.drawLine(
        Offset(p.laserX0, p.laserY0),
        Offset(p.laserX1, p.laserY1),
        _line,
      );
    }
    // Aim indicator when aiming off-horizontal (no dedicated aim frames yet).
    if (p.aimU.abs() > 0.1 && !p.crouching) {
      _fill.color = Pal.gold6;
      final mx = p.muzzleX + p.aimX * 6, my = p.muzzleY + p.aimY * 6;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(mx, my), width: 3, height: 3),
        _fill,
      );
    }
  }

  void _drawBullets(Canvas canvas) {
    for (final b in game.sim.bullets.items) {
      if (!b.active) continue;
      final c = Offset(b.x, b.y);
      final sp = math.sqrt(b.vx * b.vx + b.vy * b.vy);
      final dx = sp > 0 ? b.vx / sp : 1.0, dy = sp > 0 ? b.vy / sp : 0.0;
      switch (b.kind) {
        case ShotKind.blaster || ShotKind.ricochet:
          _streak(
            canvas,
            c,
            dx,
            dy,
            7,
            b.kind == ShotKind.ricochet ? Pal.aqua6 : Pal.gold6,
          );
        case ShotKind.spread:
          _dot(canvas, c, 3, Pal.ember5, Pal.gold7);
        case ShotKind.plasma:
          _dot(canvas, c, 6 + (b.age % 6 < 3 ? 1 : 0), Pal.neon5, Pal.neon7);
        case ShotKind.homing:
          _streak(canvas, c, dx, dy, 8, Pal.ink6);
          _dot(
            canvas,
            Offset(b.x - dx * 6, b.y - dy * 6),
            2,
            Pal.gold6,
            Pal.gold7,
          );
        case ShotKind.flame:
          final t = b.age / 20;
          final col = t < 0.3
              ? Pal.gold7
              : (t < 0.6 ? Pal.gold5 : (t < 0.85 ? Pal.ember4 : Pal.ink3));
          _fill.color = col;
          canvas.drawCircle(c, 3 + t * 8, _fill);
        case ShotKind.grenade:
          _dot(canvas, c, 4, Pal.moss4, Pal.moss6);
        case ShotKind.vehicleShell:
          _dot(canvas, c, 5, Pal.gold5, Pal.gold7);
        case ShotKind.enemyBullet || ShotKind.bossBullet:
          _dot(
            canvas,
            c,
            b.kind == ShotKind.bossBullet ? 5 : 4,
            b.kind == ShotKind.bossBullet ? Pal.neon5 : Pal.ember5,
            Pal.gold7,
          );
        case ShotKind.enemyRocket:
          _streak(canvas, c, dx, dy, 10, Pal.ink5);
          _dot(
            canvas,
            Offset(b.x - dx * 7, b.y - dy * 7),
            3,
            Pal.ember5,
            Pal.gold7,
          );
        case ShotKind.enemyForm:
          canvas.save();
          canvas.translate(b.x, b.y);
          canvas.rotate(b.age * 0.3);
          _fill.color = Pal.ink0;
          canvas.drawRect(const Rect.fromLTWH(-6, -8, 12, 16), _fill);
          _fill.color = Pal.ink7;
          canvas.drawRect(const Rect.fromLTWH(-5, -7, 10, 14), _fill);
          _fill.color = Pal.ember4;
          canvas.drawRect(const Rect.fromLTWH(-3, 1, 6, 4), _fill);
          canvas.restore();
        case ShotKind.enemyBomb:
          _dot(canvas, c, b.radius, Pal.ink2, Pal.ember5);
        case ShotKind.sniperBolt:
          _streak(canvas, c, dx, dy, 18, Pal.ember6);
      }
    }
  }

  void _dot(Canvas canvas, Offset c, double r, Color body, Color core) {
    _fill.color = Pal.ink0;
    canvas.drawCircle(c, r + 1, _fill);
    _fill.color = body;
    canvas.drawCircle(c, r, _fill);
    _fill.color = core;
    canvas.drawCircle(c - const Offset(1, 1), math.max(1, r / 2.5), _fill);
  }

  void _streak(
    Canvas canvas,
    Offset c,
    double dx,
    double dy,
    double len,
    Color col,
  ) {
    _line
      ..strokeWidth = 4
      ..color = Pal.ink0;
    canvas.drawLine(c - Offset(dx * len, dy * len), c, _line);
    _line
      ..strokeWidth = 2
      ..color = col;
    canvas.drawLine(c - Offset(dx * len, dy * len), c, _line);
    _fill.color = Pal.ink7;
    canvas.drawRect(Rect.fromCenter(center: c, width: 2, height: 2), _fill);
  }

  // ------------------------------------------------------------------ boss --

  void _drawBoss(Canvas canvas, Boss b) {
    if (b.dead && b.deathTimer <= 0) return;
    final res = game.res;
    final flashAll = b.dead && (b.deathTimer ~/ 3).isEven;
    Paint paintFor(BossPart p) => p.flash > 0 || flashAll ? _flash : _p;
    switch (b.kind) {
      case BossKind.stamper:
        if (b.state == 'slamTrack') {
          _fill.color = Pal.ink0.withValues(alpha: 0.6);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(b.targetX, b.arena.y1 - 2),
              width: 120,
              height: 10,
            ),
            _fill,
          );
        }
        final body = res.atlas('stamper_body');
        final parts = res.atlas('stamper_parts');
        final stamp = b.part('stamp');
        drawFrame(
          canvas,
          parts,
          parts.frameAt(stamp.open ? 'stamp_hot' : 'stamp', _t),
          stamp.x,
          stamp.y,
          paint: paintFor(stamp),
        );
        for (final side in const ['drawerL', 'drawerR']) {
          final d = b.part(side);
          drawFrame(
            canvas,
            parts,
            parts.frameAt(d.open ? 'drawer_open' : 'drawer', 0),
            d.x,
            d.y,
            flipX: side == 'drawerL',
            paint: paintFor(d),
          );
        }
        drawFrame(
          canvas,
          body,
          body.frameAt('idle', _t),
          b.bx,
          b.by,
          paint: paintFor(b.part('body')),
        );
      case BossKind.washer:
        final body = res.atlas('washer_body');
        final drum = res.atlas('washer_drum');
        final panel = res.atlas('washer_panel');
        final shaking =
            b.state == 'openTell' ||
            b.state == 'spinTell' ||
            b.state == 'hopTell';
        drawFrame(
          canvas,
          body,
          body.frameAt(shaking ? 'shake' : 'idle', _t),
          b.bx,
          b.by,
          paint: paintFor(b.part('body')),
        );
        final d = b.part('drum');
        canvas.save();
        canvas.translate(d.x, d.y);
        canvas.rotate(b.spinAngle);
        drawFrame(
          canvas,
          drum,
          drum.frameAt(d.open ? 'open' : 'spin', _t),
          0,
          0,
          paint: paintFor(d),
        );
        canvas.restore();
        final pn = b.part('panel');
        drawFrame(
          canvas,
          panel,
          panel.frameAt('blink', _t),
          pn.x,
          pn.y,
          paint: paintFor(pn),
        );
        if (b.captured > 0 && d.open) {
          res.font.draw(
            canvas,
            '${b.captured}',
            d.x,
            d.y - 4,
            color: Pal.gold7,
            shadow: Pal.ink0,
            align: PixelTextAlign.center,
          );
        }
      case BossKind.emperor:
        final throne = res.atlas('emperor_throne');
        final parts = res.atlas('emperor_parts');
        if (b.phase < 3 || !b.dead) {
          drawFrame(
            canvas,
            throne,
            throne.frameAt(
              b.phase == 2 && b.state == 'walk' ? 'walk' : 'idle',
              _t,
            ),
            b.bx,
            b.by,
            flipX: b.facing > 0,
            paint: flashAll ? _flash : _p,
          );
        }
        for (var i = 0; i < 4; i++) {
          final d = b.part('drawer$i');
          final anim = d.destroyed
              ? 'drawer_broken'
              : d.open
              ? 'drawer_open'
              : 'drawer';
          drawFrame(
            canvas,
            parts,
            parts.frameAt(anim, 0),
            d.x,
            d.y,
            paint: paintFor(d),
          );
        }
        final core = b.part('core');
        if (!core.destroyed) {
          drawFrame(
            canvas,
            parts,
            parts.frameAt(
              b.phase == 2 ? 'core' : 'core',
              b.phase == 2 ? _t : 0.9,
            ),
            core.x,
            core.y,
            paint: paintFor(core),
          );
        }
        final s = b.part('saucer');
        drawFrame(
          canvas,
          parts,
          parts.frameAt('saucer', _t),
          s.x,
          s.y,
          paint: paintFor(s),
        );
        if (b.state == 'laserTell' && (_t * 12).floor().isEven) {
          _line
            ..strokeWidth = 1
            ..color = Pal.ember4;
          canvas.drawLine(
            Offset(b.laserX0, b.laserY0),
            Offset(b.laserX1, b.laserY1),
            _line,
          );
        }
        if (b.laserOn) {
          _line
            ..strokeWidth = 7
            ..color = Pal.ember5;
          canvas.drawLine(
            Offset(b.laserX0, b.laserY0),
            Offset(b.laserX1, b.laserY1),
            _line,
          );
          _line
            ..strokeWidth = 2
            ..color = Pal.gold7;
          canvas.drawLine(
            Offset(b.laserX0, b.laserY0),
            Offset(b.laserX1, b.laserY1),
            _line,
          );
        }
    }
  }
}

class _Edge {
  const _Edge(this.ax, this.ay, this.bx, this.by, this.nx, this.ny);

  final double ax, ay, bx, by, nx, ny;
}

/// Commando atlas helper, exported for HUD icons.
SpriteAtlas heroAtlasOf(PlayGame g) => g.res.atlas(g.heroAtlas);

/// Weapon colour used by HUD and pickups.
Color weaponColor(WeaponKind w) => switch (w) {
  WeaponKind.blaster => Pal.ink6,
  WeaponKind.spread => Pal.ember5,
  WeaponKind.laser => Pal.aqua5,
  WeaponKind.plasma => Pal.neon5,
  WeaponKind.homing => Pal.moss5,
  WeaponKind.flame => Pal.gold5,
  WeaponKind.ricochet => Pal.space5,
};
