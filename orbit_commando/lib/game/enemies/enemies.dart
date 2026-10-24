import 'dart:math' as math;

import '../../engine/physics/body.dart';
import '../../engine/physics/geometry.dart';
import '../levels/level_data.dart';
import '../sim/balance.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';
import '../weapons/weapons.dart';

/// All enemy types, in a fixed order (the index travels in events).
const enemyTypes = [
  'grunt', // pack: rifle trooper
  'rocket', // pack: hovering rocketeer
  'cyclops', // pack: heavy minigun walker
  'bulwark', // pack: shield + gatling
  'clerk', // Glorbo bureaucrat, throws stamped forms
  'drone', // fan drone, drops bombs
  'turret', // crawling turret, climbs curved surfaces
  'roller', // kamikaze roller
  'sniper', // long-range, visible laser sight
  'minimech', // jumping mini mech
  'jelly', // space jellyfish, electric pulse
  'swarm', // metal insects
];

const _flying = {'rocket', 'drone', 'jelly', 'swarm'};

enum EnemyMode { move, tell, attack, cooldown, special }

class Enemy {
  Enemy(this.sim, this.type, double x, double y, {this.facing = -1})
    : id = sim.nextId(),
      spec = sim.balance.enemies[type]!,
      typeIndex = enemyTypes.indexOf(type),
      flying = _flying.contains(type),
      body = Body(
        radius: sim.balance.enemies[type]!.radius,
        height: sim.balance.enemies[type]!.height,
      ) {
    body
      ..x = x
      ..y = y;
    body.updateFrame(sim.gravity);
    hp = spec.hp;
    homeX = x;
    homeY = y;
    timer = 30 + sim.rng.nextInt(60);
    phase = sim.rng.nextDouble() * math.pi * 2;
  }

  final GameSim sim;
  final String type;
  final int typeIndex;
  final int id;
  final EnemySpec spec;
  final bool flying;
  final Body body;

  double hp = 1;
  bool alive = true;

  /// Ticks left in the death animation before removal.
  int removeTimer = 36;
  int facing;
  EnemyMode mode = EnemyMode.move;
  int timer = 0;
  int shotsLeft = 0;
  int flash = 0;

  /// Ticks since this enemy last took damage (panic animation).
  int sinceHit = 999;
  double homeX = 0, homeY = 0;
  double phase = 0;

  /// Locked aim for snipers (shown as the laser sight).
  double aimX = 0, aimY = 0;

  /// Electric pulse active (jelly).
  bool pulsing = false;

  double get x => body.cx;
  double get cy => body.cy;
  double get feetX => body.x;
  double get feetY => body.y;
  double get angle => body.angle;

  double get _speed => spec.speed * sim.enemySpeedMult;

  /// Distance from a point to this enemy's capsule axis (compare with
  /// `spec.radius + other radius`).
  double distanceTo(double px, double py) {
    final ax = body.x + body.ux * body.radius;
    final ay = body.y + body.uy * body.radius;
    final h = math.max(0.0, body.height - body.radius * 2);
    final t = ((px - ax) * body.ux + (py - ay) * body.uy).clamp(0.0, h);
    final qx = ax + body.ux * t, qy = ay + body.uy * t;
    return math.sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));
  }

  /// Player position relative to us, in our local frame.
  double get _pr =>
      (sim.player.cx - x) * body.rx + (sim.player.cy - cy) * body.ry;
  double get _pd {
    final dx = sim.player.cx - x, dy = sim.player.cy - cy;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool get _playerTargetable => !sim.player.dead;

  void update() {
    if (flash > 0) flash--;
    sinceHit++;
    if (timer > 0) timer--;
    switch (type) {
      case 'grunt':
        _walker(keepAway: 150, burst: 3, burstGap: 8);
      case 'cyclops':
        _walker(keepAway: 200, burst: 8, burstGap: 5, spread: 0.12);
      case 'bulwark':
        _walker(keepAway: 170, burst: 4, burstGap: 7);
      case 'clerk':
        _walker(keepAway: 180, burst: 1, burstGap: 1, lob: true);
      case 'turret':
        _turret();
      case 'roller':
        _roller();
      case 'sniper':
        _sniper();
      case 'minimech':
        _minimech();
      case 'rocket':
        _hover(altitude: 90, keepAway: 220);
      case 'drone':
        _drone();
      case 'jelly':
        _jelly();
      case 'swarm':
        _swarm();
    }
    _contactDamage();
  }

  // ------------------------------------------------------------ walkers ---

  void _walk(double vr) {
    body.setLocal(vr, body.vu);
    body.step(sim.world, sim.gravity, g: sim.balance.gravity);
  }

  void _faceToPlayer() {
    if (_pr.abs() > 4) facing = _pr > 0 ? 1 : -1;
  }

  void _walker({
    required double keepAway,
    required int burst,
    required int burstGap,
    double spread = 0,
    bool lob = false,
  }) {
    if (!_playerTargetable) {
      _walk(0);
      return;
    }
    switch (mode) {
      case EnemyMode.move:
        _faceToPlayer();
        final far = _pr.abs() > keepAway;
        var vr = far ? facing * _speed : 0.0;
        // Don't walk off ledges: probe ahead for ground.
        if (vr != 0 && !_groundAhead(facing)) vr = 0;
        _walk(vr);
        if (timer == 0 && _pd < spec.range) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        _faceToPlayer();
        _walk(0);
        if (timer == 0) {
          mode = EnemyMode.attack;
          shotsLeft = burst;
        }
      case EnemyMode.attack:
        _walk(0);
        if (timer == 0) {
          final mx = x + body.rx * facing * 22 + body.ux * 8;
          final my = cy + body.ry * facing * 22 + body.uy * 8;
          if (lob) {
            // Arcing form: aim above the player, gravity does the rest.
            final dx = sim.player.cx - mx, dy = sim.player.cy - my;
            sim.bullets.enemyShot(
              ShotKind.enemyForm,
              mx,
              my,
              dx + body.ux * 120,
              dy + body.uy * 120,
              spec.bulletSpeed,
              gravityScale: 0.5,
              blast: 18,
            );
          } else {
            final a = (sim.rng.nextDouble() - 0.5) * spread;
            final dx = sim.player.cx - mx, dy = sim.player.cy - my;
            final c = math.cos(a), s = math.sin(a);
            sim.bullets.enemyShot(
              ShotKind.enemyBullet,
              mx,
              my,
              dx * c - dy * s,
              dx * s + dy * c,
              spec.bulletSpeed,
            );
          }
          shotsLeft--;
          timer = burstGap;
          if (shotsLeft <= 0) {
            mode = EnemyMode.move;
            timer = spec.cooldown + sim.rng.nextInt(40);
          }
        }
      default:
        mode = EnemyMode.move;
    }
  }

  bool _groundAhead(int dir) {
    final px = body.x + body.rx * dir * (body.radius + 8) - body.ux * 12;
    final py = body.y + body.ry * dir * (body.radius + 8) - body.uy * 12;
    return sim.world.pointBlocked(px, py, 6);
  }

  void _turret() {
    // Crawls slowly along any surface (gravity keeps it attached).
    _faceToPlayer();
    final vr = mode == EnemyMode.move && _pd > 120 && _groundAhead(facing)
        ? facing * 0.35 * sim.enemySpeedMult
        : 0.0;
    _walk(vr);
    if (!_playerTargetable) return;
    _shootCycle(burst: 3, gap: 10, kind: ShotKind.enemyBullet);
  }

  void _shootCycle({
    required int burst,
    required int gap,
    required ShotKind kind,
    double homing = 0,
    double blast = 0,
  }) {
    switch (mode) {
      case EnemyMode.move:
        if (timer == 0 && _pd < spec.range) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        if (timer == 0) {
          mode = EnemyMode.attack;
          shotsLeft = burst;
        }
      case EnemyMode.attack:
        if (timer == 0) {
          sim.bullets.enemyShot(
            kind,
            x + body.ux * 6,
            cy + body.uy * 6,
            sim.player.cx - x,
            sim.player.cy - cy,
            spec.bulletSpeed,
            homing: homing,
            blast: blast,
            radius: kind == ShotKind.enemyRocket ? 6 : 4,
          );
          timer = gap;
          if (--shotsLeft <= 0) {
            mode = EnemyMode.move;
            timer = spec.cooldown + sim.rng.nextInt(40);
          }
        }
      default:
        mode = EnemyMode.move;
    }
  }

  void _roller() {
    if (!_playerTargetable) {
      _walk(0);
      return;
    }
    switch (mode) {
      case EnemyMode.move:
        if (_pd < spec.range) {
          // Spots the player: a little hop of excitement (the tell).
          _faceToPlayer();
          mode = EnemyMode.tell;
          timer = spec.tell;
          body.setLocal(0, 4);
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
        _walk(0);
      case EnemyMode.tell:
        _walk(0);
        if (timer == 0) mode = EnemyMode.attack;
      default:
        // Rolls around the planetoid towards the player.
        _faceToPlayer();
        _walk(facing * _speed);
        if (_pd < 26) {
          _die(silent: true);
          sim.explode(x, cy, 34, 1, byPlayer: false);
        }
    }
  }

  void _sniper() {
    _walk(0);
    if (!_playerTargetable) return;
    switch (mode) {
      case EnemyMode.move:
        _faceToPlayer();
        if (timer == 0 && _pd < spec.range && _lineOfSight()) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        // The sight tracks the player, then locks for the last 18 ticks.
        if (timer > 18) {
          aimX = sim.player.cx;
          aimY = sim.player.cy;
          _faceToPlayer();
        }
        if (timer == 0) {
          sim.bullets.enemyShot(
            ShotKind.sniperBolt,
            x,
            cy - 8,
            aimX - x,
            aimY - cy + 8,
            spec.bulletSpeed,
            radius: 3,
          );
          mode = EnemyMode.move;
          timer = spec.cooldown;
        }
      default:
        mode = EnemyMode.move;
    }
  }

  final RayHit _ray = RayHit();

  bool _lineOfSight() {
    final dx = sim.player.cx - x, dy = sim.player.cy - cy;
    final d = math.sqrt(dx * dx + dy * dy);
    return !sim.world.raycast(x, cy, dx / d, dy / d, d, _ray);
  }

  void _minimech() {
    if (!_playerTargetable) {
      _walk(0);
      return;
    }
    switch (mode) {
      case EnemyMode.move:
        _faceToPlayer();
        _walk(_groundAhead(facing) && _pr.abs() > 60 ? facing * _speed : 0);
        if (timer == 0 && body.grounded && _pd < spec.range) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        _walk(0);
        if (timer == 0) {
          mode = EnemyMode.special;
          body.setLocal(facing * 2.6, 8.5);
          body.step(sim.world, sim.gravity, g: sim.balance.gravity);
          timer = 10;
        }
      case EnemyMode.special:
        body.step(sim.world, sim.gravity, g: sim.balance.gravity);
        if (body.grounded && timer == 0) {
          sim.events.add(SimEventType.land, body.x, body.y, a: 1);
          sim.impact(stop: 2);
          // Two shots on landing.
          for (final off in const [-6.0, 6.0]) {
            sim.bullets.enemyShot(
              ShotKind.enemyBullet,
              x,
              cy + off,
              sim.player.cx - x,
              sim.player.cy - cy,
              spec.bulletSpeed,
            );
          }
          mode = EnemyMode.move;
          timer = spec.cooldown;
        }
      default:
        mode = EnemyMode.move;
    }
  }

  // ------------------------------------------------------------ fliers ---

  void _flyTo(double tx, double ty, double speed) {
    final dx = tx - body.x, dy = ty - body.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1) return;
    final s = math.min(speed, d);
    body
      ..vx = dx / d * s
      ..vy = dy / d * s;
    body.x += body.vx;
    body.y += body.vy;
    // Keep "up" from gravity for orientation, without falling.
    body.updateFrame(sim.gravity);
  }

  void _hover({required double altitude, required double keepAway}) {
    _faceToPlayer();
    final bob = math.sin(phase + sim.tick * 0.05) * 6;
    final side = _pr > 0 ? -1 : 1;
    // Target: beside the player at some altitude in the player's frame.
    final p = sim.player.body;
    final tx = p.x + p.rx * side * keepAway + p.ux * (altitude + bob);
    final ty = p.y + p.ry * side * keepAway + p.uy * (altitude + bob);
    _flyTo(tx, ty, mode == EnemyMode.move ? _speed : _speed * 0.2);
    if (!_playerTargetable) return;
    _shootCycle(
      burst: 1,
      gap: 1,
      kind: ShotKind.enemyRocket,
      homing: 0.02,
      blast: 22,
    );
  }

  void _drone() {
    final p = sim.player.body;
    final sway = math.sin(phase + sim.tick * 0.07) * 70;
    final tx = p.x + p.rx * sway + p.ux * 120;
    final ty = p.y + p.ry * sway + p.uy * 120;
    _flyTo(tx, ty, _speed);
    _faceToPlayer();
    if (!_playerTargetable) return;
    switch (mode) {
      case EnemyMode.move:
        if (timer == 0 && _pr.abs() < 40) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        if (timer == 0) {
          sim.bullets.enemyShot(
            ShotKind.enemyBomb,
            x,
            cy,
            -body.ux,
            -body.uy,
            0.5,
            gravityScale: 1,
            blast: 22,
          );
          mode = EnemyMode.move;
          timer = spec.cooldown;
        }
      default:
        mode = EnemyMode.move;
    }
  }

  void _jelly() {
    final drift = math.sin(phase + sim.tick * 0.03) * 0.4;
    final dx = sim.player.cx - body.x, dy = sim.player.cy - body.y;
    final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    body
      ..x += dx / d * _speed * 0.5 + drift
      ..y += dy / d * _speed * 0.5 + math.cos(phase + sim.tick * 0.04) * 0.4;
    pulsing = false;
    switch (mode) {
      case EnemyMode.move:
        if (timer == 0 && _pd < spec.range + 40) {
          mode = EnemyMode.tell;
          timer = spec.tell;
          sim.events.add(SimEventType.tell, x, cy, a: id);
        }
      case EnemyMode.tell:
        if (timer == 0) {
          mode = EnemyMode.attack;
          timer = 24;
        }
      case EnemyMode.attack:
        pulsing = true;
        if (_pd < spec.range) sim.player.hurt(x, cy);
        if (timer == 0) {
          mode = EnemyMode.move;
          timer = spec.cooldown;
        }
      default:
        mode = EnemyMode.move;
    }
  }

  void _swarm() {
    final dx = sim.player.cx - body.x, dy = sim.player.cy - body.y;
    final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final jx = math.sin(phase + sim.tick * 0.31) * 1.2;
    final jy = math.cos(phase * 1.3 + sim.tick * 0.27) * 1.2;
    final s = mode == EnemyMode.move ? _speed : _speed * 0.3;
    body
      ..vx = body.vx * 0.9 + (dx / d * s + jx) * 0.1
      ..vy = body.vy * 0.9 + (dy / d * s + jy) * 0.1;
    body.x += body.vx * 2;
    body.y += body.vy * 2;
    if (mode == EnemyMode.move && _pd < 160 && timer == 0) {
      // Brief hesitation (tell) before diving in.
      mode = EnemyMode.tell;
      timer = spec.tell;
    } else if (mode == EnemyMode.tell && timer == 0) {
      mode = EnemyMode.attack;
    }
    _faceToPlayer();
  }

  void _contactDamage() {
    final p = sim.player;
    if (p.dead || p.inVehicle || type == 'jelly') return;
    if (p.distanceTo(x, cy) < spec.radius - 2) {
      p.hurt(x, cy);
      if (type == 'swarm') _die();
    }
  }

  // ------------------------------------------------------------- damage ---

  /// Bulwark's shield blocks frontal non-explosive hits.
  bool _blocked(double fromX, double fromY, {bool explosive = false}) {
    if (type != 'bulwark' || explosive) return false;
    final side = (fromX - x) * body.rx + (fromY - cy) * body.ry;
    return side * facing > 0;
  }

  void damage(
    double amount,
    double fromX,
    double fromY, {
    bool explosive = false,
    bool beam = false,
    double fromVx = 0,
    double fromVy = 0,
  }) {
    if (!alive) return;
    // Use the projectile's origin side for the shield check.
    final ox = fromVx != 0 || fromVy != 0 ? fromX - fromVx * 4 : fromX;
    final oy = fromVx != 0 || fromVy != 0 ? fromY - fromVy * 4 : fromY;
    if (_blocked(ox, oy, explosive: explosive)) {
      if (!beam || sim.tick % 6 == 0) {
        sim.events.add(SimEventType.shieldHit, fromX, fromY);
      }
      return;
    }
    hp -= amount;
    flash = 4;
    sinceHit = 0;
    if (!beam || sim.tick % 4 == 0) {
      sim.events.add(SimEventType.hit, fromX, fromY, a: 2);
    }
    if (hp <= 0) _die();
  }

  void _die({bool silent = false}) {
    if (!alive) return;
    alive = false;
    removeTimer = 36;
    sim.kills++;
    if (!silent) sim.addScore(spec.score, x, cy, combos: true);
    sim.events.add(SimEventType.enemyDeath, x, cy, a: typeIndex);
    if (spec.hp >= 10) sim.impact(stop: 3);
    // Small chance of a grenade drop.
    if (sim.rng.nextInt(100) < 6) {
      sim.items.dropPickup('grenade', x, cy);
    }
  }
}

/// Activates the level's enemy spawns as the player approaches.
class Spawner {
  Spawner(this.sim)
    : _pending = sim.level.ofType('enemy').toList(growable: true);

  final GameSim sim;
  final List<EntityDef> _pending;

  int get remaining => _pending.length;

  void update() {
    if (_pending.isEmpty || sim.player.dead) return;
    final r = sim.balance.activationRange;
    final px = sim.player.cx, py = sim.player.cy;
    for (var i = _pending.length - 1; i >= 0; i--) {
      final s = _pending[i];
      final dx = s.x - px, dy = s.y - py;
      if (dx * dx + dy * dy > r * r) continue;
      _pending.removeAt(i);
      spawn(s);
    }
  }

  void spawn(EntityDef s) {
    final kind = s.str('kind', 'grunt');
    if (!enemyTypes.contains(kind)) return;
    final count = kind == 'swarm' ? s.number('count', 6).toInt() : 1;
    for (var i = 0; i < count; i++) {
      final ox = count > 1 ? (i - count / 2) * 9.0 : 0.0;
      final oy = count > 1 ? (i % 2) * 9.0 : 0.0;
      sim.enemies.add(
        Enemy(
          sim,
          kind,
          s.x + ox,
          s.y + oy,
          facing: s.str('facing', 'left') == 'right' ? 1 : -1,
        ),
      );
    }
  }
}
