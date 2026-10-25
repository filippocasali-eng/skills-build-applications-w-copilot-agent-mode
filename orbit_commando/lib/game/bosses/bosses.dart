import 'dart:math' as math;

import '../../engine/physics/geometry.dart';
import '../levels/level_data.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';
import '../weapons/weapons.dart';

enum BossKind { stamper, washer, emperor }

/// A hittable piece of a boss. Weak points take full damage; armour takes
/// [armor] times the damage (0 = immune).
class BossPart {
  BossPart(this.name, this.ox, this.oy, this.radius, {this.armor = 0.25});

  final String name;

  /// Offset from the boss centre.
  double ox, oy;
  final double radius;
  double armor;

  /// Weak points with their own HP (emperor drawers); <0 = uses boss HP.
  double hp = -1;
  bool destroyed = false;
  bool open = false;
  int flash = 0;

  double x = 0, y = 0;
}

class Boss {
  Boss(this.kind, this.arena, double x, double y) : bx = x, by = y;

  final BossKind kind;
  final RectDef arena;
  double bx, by;
  double vx = 0, vy = 0;
  double hp = 1, maxHp = 1;
  int phase = 1;
  String state = 'intro';
  int timer = 90;
  int stateTicks = 0;
  bool active = false;
  bool dead = false;
  int deathTimer = 0;
  int facing = -1;
  final List<BossPart> parts = [];

  /// Bullets captured by the washing machine's drum.
  int captured = 0;
  double spinAngle = 0;

  /// Eye-laser sweep (emperor) for rendering and damage.
  bool laserOn = false;
  double laserX0 = 0, laserY0 = 0, laserX1 = 0, laserY1 = 0;

  /// Slam target X (stamper) for the shadow tell.
  double targetX = 0;

  BossPart part(String name) => parts.firstWhere((p) => p.name == name);

  double get hpFraction => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);
}

/// Boss logic. One boss per boss level, activated when the player enters
/// its arena.
class Bosses {
  Bosses(this.sim) {
    for (final e in sim.level.ofType('boss')) {
      final kind = BossKind.values.firstWhere(
        (k) => k.name == e.str('kind'),
        orElse: () => BossKind.stamper,
      );
      final w = e.number('arenaW', 600), h = e.number('arenaH', 330);
      final arena = RectDef(e.x - w / 2, e.y - h, e.x + w / 2, e.y);
      boss = Boss(kind, arena, e.x, e.y - h * 0.6);
      _setup(boss!);
    }
  }

  final GameSim sim;
  Boss? boss;
  final RayHit _ray = RayHit();

  bool get defeated => boss != null && boss!.dead && boss!.deathTimer <= 0;
  bool get fighting => boss != null && boss!.active && !boss!.dead;

  void _setup(Boss b) {
    switch (b.kind) {
      case BossKind.stamper:
        b.maxHp = 260;
        b.parts.addAll([
          BossPart('body', 0, 0, 62, armor: 0.2),
          BossPart('stamp', 0, 64, 24, armor: 1),
          BossPart('drawerL', -60, 22, 18, armor: 0.2),
          BossPart('drawerR', 60, 22, 18, armor: 0.2),
        ]);
      case BossKind.washer:
        b.maxHp = 240;
        b.by = b.arena.y1 - 90;
        // The control panel sticks out above the body so diagonal shots
        // reach it; the body only takes chip damage.
        b.parts.addAll([
          BossPart('body', 0, 20, 58, armor: 0.25),
          BossPart('panel', 0, -72, 30, armor: 1),
          BossPart('drum', 0, 10, 40, armor: 0),
        ]);
      case BossKind.emperor:
        b.maxHp = 120 + 120 + 100; // 4 drawers, core, saucer: one HP bar
        b.bx = b.arena.x1 - 150;
        b.by = b.arena.y1 - 110;
        b.parts.addAll([
          BossPart('body', 20, 10, 70, armor: 0),
          for (var i = 0; i < 4; i++)
            BossPart('drawer$i', -62, -60 + i * 38.0, 18, armor: 1)..hp = 30,
          BossPart('core', 0, -10, 26, armor: 0)..hp = 120,
          BossPart('saucer', 0, -90, 28, armor: 0)..hp = 100,
        ]);
    }
    b.hp = b.maxHp;
    _placeParts(b);
  }

  void _placeParts(Boss b) {
    for (final p in b.parts) {
      p.x = b.bx + p.ox;
      p.y = b.by + p.oy;
    }
  }

  // --------------------------------------------------------------- update ---

  void update() {
    final b = boss;
    if (b == null) return;
    for (final p in b.parts) {
      if (p.flash > 0) p.flash--;
    }
    if (!b.active) {
      if (b.arena.contains(sim.player.cx, sim.player.cy)) {
        b.active = true;
        b.state = 'intro';
        b.timer = 80;
        sim.events.add(SimEventType.bossPhase, b.bx, b.by, a: 0);
      }
      return;
    }
    if (b.dead) {
      if (b.deathTimer > 0) {
        b.deathTimer--;
        if (b.deathTimer % 8 == 0) {
          final ox = (sim.rng.nextDouble() - 0.5) * 160;
          final oy = (sim.rng.nextDouble() - 0.5) * 120;
          sim.events.add(
            SimEventType.explosion,
            b.bx + ox,
            b.by + oy,
            a: 2,
            b: 40,
          );
        }
      }
      return;
    }
    _keepPlayerInArena(b);
    b.stateTicks++;
    if (b.timer > 0) b.timer--;
    b.laserOn = false;
    switch (b.kind) {
      case BossKind.stamper:
        _stamper(b);
      case BossKind.washer:
        _washer(b);
      case BossKind.emperor:
        _emperor(b);
    }
    _placeParts(b);
    _contact(b);
  }

  /// Invisible arena walls while the fight is on.
  void _keepPlayerInArena(Boss b) {
    final body = sim.player.body;
    final x0 = b.arena.x0 + 14, x1 = b.arena.x1 - 14;
    if (body.x < x0) {
      body.x = x0;
      if (body.vx < 0) body.vx = 0;
    } else if (body.x > x1) {
      body.x = x1;
      if (body.vx > 0) body.vx = 0;
    }
  }

  void _go(Boss b, String state, int timer) {
    b
      ..state = state
      ..timer = timer
      ..stateTicks = 0;
  }

  void _tell(Boss b, double x, double y) =>
      sim.events.add(SimEventType.tell, x, y, a: -1);

  double get _px => sim.player.cx;
  double get _py => sim.player.cy;

  // ----- Timbratore Supremo: flying office that stamps and throws forms ----
  void _stamper(Boss b) {
    final top = b.arena.y0 + 95;
    final fast = b.phase >= 2 ? 1.4 : 1.0;
    switch (b.state) {
      case 'intro':
        b.by += (top - b.by) * 0.05;
        if (b.timer == 0) _go(b, 'hover', 70);
      case 'hover':
        final tx = (_px).clamp(b.arena.x0 + 110, b.arena.x1 - 110);
        b.bx += (tx - b.bx) * 0.02 * fast;
        b.by += (top + math.sin(b.stateTicks * 0.06) * 10 - b.by) * 0.1;
        if (b.timer == 0) {
          final roll = sim.rng.nextInt(b.phase >= 2 ? 3 : 2);
          if (roll == 0) {
            _go(b, 'formsTell', 30);
            b.part('drawerL').open = true;
            b.part('drawerR').open = true;
            _tell(b, b.bx, b.by);
          } else if (roll == 1) {
            _go(b, 'slamTrack', 55);
            _tell(b, b.bx, b.by);
          } else {
            _go(b, 'planesTell', 24);
            _tell(b, b.bx, b.by);
          }
        }
      case 'formsTell':
        if (b.timer == 0) _go(b, 'forms', 50);
      case 'forms':
        if (b.stateTicks % 10 == 0) {
          for (final side in const ['drawerL', 'drawerR']) {
            final p = b.part(side);
            final dx = _px - p.x;
            sim.bullets.enemyShot(
              ShotKind.enemyForm,
              p.x,
              p.y,
              dx * 0.012 + (side == 'drawerL' ? -0.6 : 0.6),
              -1.2,
              4.2,
              gravityScale: 0.45,
              blast: 22,
              life: 260,
            );
          }
        }
        if (b.timer == 0) {
          b.part('drawerL').open = false;
          b.part('drawerR').open = false;
          _go(b, 'hover', (80 / fast).round());
        }
      case 'slamTrack':
        // Follows the player; the shadow on the ground is the tell.
        b.targetX = _px.clamp(b.arena.x0 + 90, b.arena.x1 - 90);
        b.bx += (b.targetX - b.bx) * 0.08;
        if (b.timer == 0) {
          _go(b, 'slam', 90);
          b.vy = 1;
        }
      case 'slam':
        b.vy = math.min(b.vy + 0.8, 11);
        final stampBottom = b.by + 64 + 24;
        final hitGround = sim.world.raycast(
          b.bx,
          stampBottom,
          0,
          1,
          b.vy + 1,
          _ray,
        );
        if (hitGround || stampBottom > b.arena.y1 - 2) {
          b.by += hitGround ? _ray.t - 1 : 0;
          sim.explode(b.bx, stampBottom, 80, 1, byPlayer: false, size: 2);
          sim.impact(stop: 5);
          b.part('stamp').open = true; // exposed
          _go(b, 'stuck', b.phase >= 2 ? 55 : 75);
        } else {
          b.by += b.vy;
        }
      case 'stuck':
        if (b.timer == 0) {
          b.part('stamp').open = false;
          _go(b, 'rise', 60);
        }
      case 'rise':
        b.by += (top - b.by) * 0.06;
        if (b.timer == 0) _go(b, 'hover', 50);
      case 'planesTell':
        if (b.timer == 0) {
          for (var i = -3; i <= 3; i++) {
            final a = math.atan2(_py - b.by, _px - b.bx) + i * 0.16;
            sim.bullets.enemyShot(
              ShotKind.bossBullet,
              b.bx,
              b.by + 30,
              math.cos(a),
              math.sin(a),
              4.5,
            );
          }
          _go(b, 'hover', 70);
        }
    }
    if (b.phase == 1 && b.hp < b.maxHp * 0.5) {
      b.phase = 2;
      sim.events.add(SimEventType.bossPhase, b.bx, b.by, a: 2);
    }
  }

  // ----- La Grande Lavatrice Cosmica: absorbs bullets, spins them back -----
  void _washer(Boss b) {
    final floor = b.arena.y1 - 90;
    final drum = b.part('drum');
    switch (b.state) {
      case 'intro':
        if (b.timer == 0) _go(b, 'idle', 60);
      case 'idle':
        b.spinAngle += 0.05;
        if (b.timer == 0) {
          final roll = sim.rng.nextInt(b.phase >= 2 ? 3 : 2);
          if (roll == 0) {
            _go(b, 'openTell', 40);
            _tell(b, b.bx, b.by);
          } else if (roll == 1) {
            _go(b, 'sudsTell', 30);
            _tell(b, b.bx, b.by);
          } else {
            _go(b, 'hopTell', 30);
            _tell(b, b.bx, b.by);
          }
        }
      case 'openTell':
        if (b.timer == 0) {
          drum.open = true;
          b.captured = 0;
          _go(b, 'absorb', 150);
        }
      case 'absorb':
        b.spinAngle += 0.25;
        _absorbBullets(b, drum);
        if (b.timer == 0) _go(b, 'spinTell', 28);
      case 'spinTell':
        b.spinAngle += 0.45;
        if (b.timer == 0) {
          _go(b, 'spin', 60);
        }
      case 'spin':
        b.spinAngle += 0.5;
        final n = (b.captured.clamp(10, 36));
        if (b.stateTicks % 2 == 0 && b.stateTicks ~/ 2 < n) {
          final a = b.stateTicks * 0.45;
          sim.bullets.enemyShot(
            ShotKind.bossBullet,
            drum.x,
            drum.y,
            math.cos(a),
            math.sin(a),
            3.6,
          );
        }
        if (b.timer == 0) {
          drum.open = false;
          _go(b, 'idle', b.phase >= 2 ? 50 : 80);
        }
      case 'sudsTell':
        if (b.timer == 0) {
          for (var i = 0; i < 3; i++) {
            sim.bullets.enemyShot(
              ShotKind.enemyBomb,
              b.bx,
              b.by - 80,
              (_px - b.bx) * 0.01 + (i - 1) * 0.8,
              -1.6,
              4 + i * 0.6,
              gravityScale: 0.6,
              blast: 24,
              radius: 8,
            );
          }
          _go(b, 'idle', 70);
        }
      case 'hopTell':
        if (b.timer == 0) {
          b.vy = -9;
          b.vx = (_px - b.bx).sign * 3.2;
          _go(b, 'hop', 200);
        }
      case 'hop':
        b.vy += 0.4;
        b.bx = (b.bx + b.vx).clamp(b.arena.x0 + 80, b.arena.x1 - 80);
        b.by += b.vy;
        if (b.by >= floor && b.vy > 0) {
          b.by = floor;
          sim.explode(b.bx, floor + 90, 70, 1, byPlayer: false, size: 2);
          _go(b, 'idle', 50);
        }
    }
    if (b.phase == 1 && b.hp < b.maxHp * 0.5) {
      b.phase = 2;
      sim.events.add(SimEventType.bossPhase, b.bx, b.by, a: 2);
    }
  }

  void _absorbBullets(Boss b, BossPart drum) {
    for (final s in sim.bullets.items) {
      if (!s.active || s.hostile) continue;
      final dx = s.x - drum.x, dy = s.y - drum.y;
      if (dx * dx + dy * dy < (drum.radius + 10) * (drum.radius + 10)) {
        s.active = false;
        b.captured++;
      }
    }
  }

  // ----- Imperatore Glorbo and his chest-of-drawers throne robot -----------
  void _emperor(Boss b) {
    switch (b.phase) {
      case 1:
        // Drawers open one at a time and launch slow homing missiles.
        if (b.state == 'intro') {
          if (b.timer == 0) _go(b, 'wait', 50);
          return;
        }
        final drawers = [for (var i = 0; i < 4; i++) b.part('drawer$i')]
            .where((d) => !d.destroyed)
            .toList();
        if (drawers.isEmpty) {
          b.phase = 2;
          b.part('core').armor = 1;
          sim.events.add(SimEventType.bossPhase, b.bx, b.by, a: 2);
          _go(b, 'walk', 90);
          return;
        }
        switch (b.state) {
          case 'wait':
            if (b.timer == 0) {
              final d = drawers[sim.rng.nextInt(drawers.length)];
              d.open = true;
              _tell(b, d.x, d.y);
              _go(b, 'drawerTell', 30);
            }
          case 'drawerTell':
            if (b.timer == 0) _go(b, 'drawerFire', 70);
          case 'drawerFire':
            for (final d in drawers) {
              if (!d.open) continue;
              if (b.stateTicks % 22 == 1) {
                sim.bullets.enemyShot(
                  ShotKind.enemyRocket,
                  d.x - 10,
                  d.y,
                  -1,
                  (_py - d.y) * 0.004,
                  2.8,
                  homing: 0.022,
                  blast: 22,
                  radius: 6,
                );
              }
            }
            if (b.timer == 0) {
              for (final d in drawers) {
                d.open = false;
              }
              _go(b, 'wait', 40);
            }
        }
      case 2:
        // The throne walks, stomps and sweeps its eye laser.
        final floorY = b.arena.y1 - 110;
        switch (b.state) {
          case 'walk':
            final tx = _px.clamp(b.arena.x0 + 120, b.arena.x1 - 120);
            b.facing = tx < b.bx ? -1 : 1;
            b.bx += (tx - b.bx).sign * 1.1;
            b.by = floorY + (math.sin(b.stateTicks * 0.2).abs() * -4);
            if (b.timer == 0) {
              _go(b, sim.rng.nextInt(2) == 0 ? 'laserTell' : 'stompTell', 45);
              _tell(b, b.bx, b.by - 60);
            }
          case 'laserTell':
            // Aim line shown by the renderer (state name).
            b
              ..laserX0 = b.bx
              ..laserY0 = b.by - 60
              ..laserX1 = _px
              ..laserY1 = _py;
            if (b.timer == 0) _go(b, 'laser', 60);
          case 'laser':
            final t = b.stateTicks / 60;
            final sweepX = b.facing < 0
                ? b.arena.x1 - t * (b.arena.x1 - b.arena.x0)
                : b.arena.x0 + t * (b.arena.x1 - b.arena.x0);
            final x0 = b.bx, y0 = b.by - 60;
            final dx = sweepX - x0, dy = b.arena.y1 - y0;
            final d = math.sqrt(dx * dx + dy * dy);
            final len = sim.world.raycast(x0, y0, dx / d, dy / d, 900, _ray)
                ? _ray.t
                : 900;
            b
              ..laserOn = true
              ..laserX0 = x0
              ..laserY0 = y0
              ..laserX1 = x0 + dx / d * len
              ..laserY1 = y0 + dy / d * len;
            _laserHurt(b);
            if (b.timer == 0) _go(b, 'walk', 80);
          case 'stompTell':
            if (b.timer == 0) {
              b.vy = -8;
              _go(b, 'stomp', 160);
            }
          case 'stomp':
            b.vy += 0.4;
            b.by += b.vy;
            if (b.by >= floorY && b.vy > 0) {
              b.by = floorY;
              sim.explode(b.bx, b.arena.y1, 90, 1, byPlayer: false, size: 2);
              _go(b, 'walk', 70);
            }
        }
        if (b.part('core').destroyed) {
          b.phase = 3;
          b.part('saucer').armor = 1;
          sim.events.add(SimEventType.bossPhase, b.bx, b.by, a: 3);
          _go(b, 'fly', 60);
        }
      case 3:
        // The emperor flees the throne in his saucer.
        final s = b.part('saucer');
        final t = b.stateTicks * 0.03;
        final cx = (b.arena.x0 + b.arena.x1) / 2;
        final tx = cx + math.cos(t) * (b.arena.x1 - b.arena.x0) * 0.38;
        final ty = b.arena.y0 + 90 + math.sin(t * 2) * 40;
        s.ox += (tx - (b.bx + s.ox)) * 0.06;
        s.oy += (ty - (b.by + s.oy)) * 0.06;
        if (b.timer == 0) {
          _tell(b, s.x, s.y);
          _go(b, 'saucerFire', 20);
        }
        if (b.state == 'saucerFire' && b.timer == 0) {
          for (var i = -2; i <= 2; i++) {
            final a = math.atan2(_py - s.y, _px - s.x) + i * 0.2;
            sim.bullets.enemyShot(
              ShotKind.bossBullet,
              s.x,
              s.y,
              math.cos(a),
              math.sin(a),
              4.2,
            );
          }
          _go(b, 'fly', 50);
        }
    }
  }

  void _laserHurt(Boss b) {
    final p = sim.player;
    final dx = b.laserX1 - b.laserX0, dy = b.laserY1 - b.laserY0;
    final l2 = dx * dx + dy * dy;
    if (l2 < 1) return;
    final t = (((p.cx - b.laserX0) * dx + (p.cy - b.laserY0) * dy) / l2).clamp(
      0.0,
      1.0,
    );
    final qx = b.laserX0 + dx * t, qy = b.laserY0 + dy * t;
    if (p.distanceTo(qx, qy) < 6) p.hurt(qx, qy);
  }

  void _contact(Boss b) {
    final p = sim.player;
    if (p.dead) return;
    for (final part in b.parts) {
      if (part.destroyed) continue;
      if (b.kind == BossKind.emperor && part.name == 'saucer' && b.phase < 3) {
        continue;
      }
      if (p.distanceTo(part.x, part.y) < part.radius - 6) {
        p.hurt(part.x, part.y);
        return;
      }
    }
  }

  // --------------------------------------------------------------- damage ---

  bool _hittable(Boss b, BossPart p) {
    if (p.destroyed) return false;
    if (b.kind == BossKind.emperor) {
      if (p.name == 'saucer') return b.phase == 3;
      if (p.name == 'core') return b.phase == 2;
      if (p.name.startsWith('drawer')) return b.phase == 1;
      if (p.name == 'body') return b.phase < 3;
    }
    return true;
  }

  void _applyDamage(Boss b, BossPart p, double dmg, double x, double y) {
    var mult = p.armor;
    if (b.kind == BossKind.stamper && p.name == 'stamp' && p.open) mult = 2;
    if (b.kind == BossKind.emperor && p.name.startsWith('drawer') && p.open) {
      mult = 1.5;
    }
    if (mult <= 0) {
      sim.events.add(SimEventType.shieldHit, x, y);
      return;
    }
    final amount = dmg * mult;
    p.flash = 4;
    sim.events.add(SimEventType.hit, x, y, a: 4);
    if (p.hp >= 0) {
      p.hp -= amount;
      if (p.hp <= 0) {
        p.destroyed = true;
        sim.explode(p.x, p.y, 30, 0, byPlayer: true, size: 2);
        sim.addScore(2000, p.x, p.y);
      }
    }
    b.hp -= amount;
    if (b.hp <= 0 ||
        (b.kind == BossKind.emperor && p.name == 'saucer' && p.destroyed)) {
      _kill(b);
    }
  }

  void _kill(Boss b) {
    if (b.dead) return;
    b
      ..hp = 0
      ..dead = true
      ..deathTimer = 150;
    sim.slowMo = 120;
    sim.addScore(50000, b.bx, b.by);
    sim.events.add(SimEventType.bossDefeated, b.bx, b.by, a: b.kind.index);
    sim.impact(stop: 8);
  }

  bool pointHits(double x, double y, double r) {
    final b = boss;
    if (b == null || !b.active || b.dead) return false;
    for (final p in b.parts) {
      if (!_hittable(b, p)) continue;
      final dx = x - p.x, dy = y - p.y;
      if (dx * dx + dy * dy < (p.radius + r) * (p.radius + r)) return true;
    }
    return false;
  }

  /// Returns true if the shot hit (and was handled).
  bool hitByShot(Bullet s) {
    final b = boss;
    if (b == null || !b.active || b.dead) return false;
    // Weak points first so a stamp hit isn't eaten by the body armour.
    BossPart? hit;
    for (final p in b.parts) {
      if (!_hittable(b, p)) continue;
      final dx = s.x - p.x, dy = s.y - p.y;
      if (dx * dx + dy * dy < (p.radius + s.radius) * (p.radius + s.radius)) {
        if (hit == null || p.armor > hit.armor) hit = p;
      }
    }
    if (hit == null) return false;
    if (b.kind == BossKind.washer && hit.name == 'drum' && hit.open) {
      return false; // the drum swallows it in _absorbBullets
    }
    if (s.blast <= 0) _applyDamage(b, hit, s.damage, s.x, s.y);
    return true;
  }

  void damageArea(double x, double y, double r, double dmg) {
    final b = boss;
    if (b == null || !b.active || b.dead || dmg <= 0) return;
    BossPart? hit;
    for (final p in b.parts) {
      if (!_hittable(b, p)) continue;
      final dx = x - p.x, dy = y - p.y;
      if (dx * dx + dy * dy < (p.radius + r) * (p.radius + r)) {
        if (hit == null || p.armor > hit.armor) hit = p;
      }
    }
    if (hit != null) _applyDamage(b, hit, dmg, x, y);
  }

  void damageSegment(double x0, double y0, double x1, double y1, double dmg) {
    final b = boss;
    if (b == null || !b.active || b.dead) return;
    final dx = x1 - x0, dy = y1 - y0;
    final l2 = dx * dx + dy * dy;
    if (l2 < 1) return;
    BossPart? hit;
    for (final p in b.parts) {
      if (!_hittable(b, p)) continue;
      final t = (((p.x - x0) * dx + (p.y - y0) * dy) / l2).clamp(0.0, 1.0);
      final qx = x0 + dx * t, qy = y0 + dy * t;
      if ((p.x - qx) * (p.x - qx) + (p.y - qy) * (p.y - qy) <
          p.radius * p.radius) {
        if (hit == null || p.armor > hit.armor) hit = p;
      }
    }
    if (hit != null && sim.tick % 2 == 0) {
      _applyDamage(b, hit, dmg * 2, hit.x, hit.y);
    }
  }

  BossPart? nearestWeakPoint(double x, double y) {
    final b = boss;
    if (b == null || !b.active || b.dead) return null;
    BossPart? best;
    var bestD = double.infinity;
    for (final p in b.parts) {
      if (!_hittable(b, p) || p.armor < 1) continue;
      final d = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }
}
