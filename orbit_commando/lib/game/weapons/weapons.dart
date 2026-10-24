import 'dart:math' as math;

import '../../engine/physics/geometry.dart';
import '../../engine/physics/gravity.dart';
import '../enemies/enemies.dart';
import '../player/player.dart';
import '../sim/balance.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';

/// What a projectile is, for behaviour and rendering.
enum ShotKind {
  blaster,
  spread,
  plasma,
  homing,
  flame,
  ricochet,
  grenade,
  vehicleShell,
  // enemy projectiles
  enemyBullet,
  enemyRocket,
  enemyForm,
  enemyBomb,
  sniperBolt,
  bossBullet,
}

class Bullet {
  bool active = false;
  bool hostile = false;
  ShotKind kind = ShotKind.blaster;
  double x = 0, y = 0, vx = 0, vy = 0;
  double damage = 1;
  double radius = 3;
  double gravityScale = 0;
  double blast = 0;
  double homing = 0;
  double drag = 1;
  int life = 0;
  int age = 0;
  int bounces = 0;
  bool pierce = false;

  /// Last enemy hit (pierce shots damage each enemy once).
  int lastHit = 0;
}

/// Fixed pool of projectiles plus the firing logic for every weapon.
class BulletPool {
  BulletPool(this.sim) : items = List.generate(capacity, (_) => Bullet());

  static const capacity = 400;
  final GameSim sim;
  final List<Bullet> items;
  final RayHit _ray = RayHit();
  final GravitySample _g = GravitySample();

  int get activeCount {
    var n = 0;
    for (final b in items) {
      if (b.active) n++;
    }
    return n;
  }

  Bullet? spawn({
    required ShotKind kind,
    required bool hostile,
    required double x,
    required double y,
    required double vx,
    required double vy,
    double damage = 1,
    int life = 90,
    double radius = 3,
    double gravityScale = 0,
    double blast = 0,
    double homing = 0,
    int bounces = 0,
    bool pierce = false,
    double drag = 1,
  }) {
    for (final b in items) {
      if (b.active) continue;
      b
        ..active = true
        ..hostile = hostile
        ..kind = kind
        ..x = x
        ..y = y
        ..vx = vx
        ..vy = vy
        ..damage = damage
        ..life = life
        ..age = 0
        ..radius = radius
        ..gravityScale = gravityScale
        ..blast = blast
        ..homing = homing
        ..bounces = bounces
        ..pierce = pierce
        ..drag = drag
        ..lastHit = 0;
      return b;
    }
    return null;
  }

  // ------------------------------------------------------------ player ---

  void playerFire(Player p) {
    if (p.fireCooldown > 0) return;
    // Automatic knife when an enemy is right in front.
    final target = _meleeTarget(p);
    if (target != null) {
      p.fireCooldown = 16;
      p.meleeTimer = 12;
      target.damage(
        sim.balance.meleeDamage * sim.loadout.damageMult,
        p.cx,
        p.cy,
      );
      sim.events.add(SimEventType.melee, target.x, target.cy, a: p.facing);
      sim.impact(stop: 3);
      return;
    }

    final spec = sim.balance.weapons[p.weapon]!;
    final dmg = spec.damage * sim.loadout.damageMult;
    final ax = p.aimX, ay = p.aimY;
    final mx = p.muzzleX, my = p.muzzleY;
    p.fireCooldown = math.max(
      1,
      (spec.cooldown * sim.loadout.fireRateMult).round(),
    );

    switch (p.weapon) {
      case WeaponKind.laser:
        _laser(p, mx, my, ax, ay, dmg);
      case WeaponKind.blaster:
        spawn(
          kind: ShotKind.blaster,
          hostile: false,
          x: mx,
          y: my,
          vx: ax * spec.speed,
          vy: ay * spec.speed,
          damage: dmg,
          life: spec.life,
        );
      case WeaponKind.spread:
        for (var i = 0; i < spec.pellets; i++) {
          final t = spec.pellets == 1 ? 0.0 : i / (spec.pellets - 1) - 0.5;
          final a = t * spec.spread;
          final c = math.cos(a), s = math.sin(a);
          spawn(
            kind: ShotKind.spread,
            hostile: false,
            x: mx,
            y: my,
            vx: (ax * c - ay * s) * spec.speed,
            vy: (ax * s + ay * c) * spec.speed,
            damage: dmg,
            life: spec.life,
          );
        }
      case WeaponKind.plasma:
        spawn(
          kind: ShotKind.plasma,
          hostile: false,
          x: mx,
          y: my,
          vx: ax * spec.speed,
          vy: ay * spec.speed,
          damage: dmg,
          life: spec.life,
          radius: 6,
          gravityScale: spec.gravity,
          blast: spec.blastRadius,
        );
      case WeaponKind.homing:
        spawn(
          kind: ShotKind.homing,
          hostile: false,
          x: mx,
          y: my,
          vx: ax * spec.speed,
          vy: ay * spec.speed,
          damage: dmg,
          life: spec.life,
          radius: 4,
          homing: spec.homing,
          blast: spec.blastRadius,
        );
      case WeaponKind.flame:
        final a = (sim.rng.nextDouble() - 0.5) * spec.spread;
        final c = math.cos(a), s = math.sin(a);
        final sp = spec.speed * (0.8 + sim.rng.nextDouble() * 0.4);
        spawn(
          kind: ShotKind.flame,
          hostile: false,
          x: mx,
          y: my,
          vx: (ax * c - ay * s) * sp + p.body.vx * 0.5,
          vy: (ax * s + ay * c) * sp + p.body.vy * 0.5,
          damage: dmg,
          life: spec.life,
          radius: 7,
          pierce: true,
          drag: 0.93,
        );
      case WeaponKind.ricochet:
        spawn(
          kind: ShotKind.ricochet,
          hostile: false,
          x: mx,
          y: my,
          vx: ax * spec.speed,
          vy: ay * spec.speed,
          damage: dmg,
          life: spec.life,
          bounces: spec.bounces,
        );
    }
    if (p.weapon != WeaponKind.laser || sim.tick % 6 == 0) {
      sim.events.add(SimEventType.shot, mx, my, a: p.weapon.index);
    }
    if (spec.ammo > 0) {
      p.ammo--;
      if (p.ammo <= 0) {
        p.weapon = WeaponKind.blaster;
        p.ammo = 0;
      }
    }
  }

  void _laser(
    Player p,
    double mx,
    double my,
    double ax,
    double ay,
    double dmg,
  ) {
    const range = 420.0;
    final len = sim.world.raycast(mx, my, ax, ay, range, _ray) ? _ray.t : range;
    p
      ..laserOn = true
      ..laserX0 = mx
      ..laserY0 = my
      ..laserX1 = mx + ax * len
      ..laserY1 = my + ay * len;
    for (final e in sim.enemies) {
      if (!e.alive) continue;
      // Distance from enemy centre to the beam.
      final t = ((e.x - mx) * ax + (e.cy - my) * ay).clamp(0.0, len);
      final qx = mx + ax * t, qy = my + ay * t;
      final dx = e.x - qx, dy = e.cy - qy;
      if (dx * dx + dy * dy < (e.spec.radius + 4) * (e.spec.radius + 4)) {
        e.damage(dmg, qx, qy, beam: true);
      }
    }
    sim.bosses.damageSegment(mx, my, p.laserX1, p.laserY1, dmg);
  }

  Enemy? _meleeTarget(Player p) {
    final r = sim.balance.meleeRange;
    for (final e in sim.enemies) {
      if (!e.alive || e.flying && e.type == 'swarm') continue;
      final dx = e.x - p.cx, dy = e.cy - p.cy;
      final along = dx * p.body.rx + dy * p.body.ry;
      if (along * p.facing < -4) continue; // behind us
      if (dx * dx + dy * dy < (r + e.spec.radius) * (r + e.spec.radius)) {
        return e;
      }
    }
    return null;
  }

  /// Easy-mode aim assist: snap to the nearest enemy within 50 degrees.
  void applyAutoAim(Player p) {
    final ax = p.aimX, ay = p.aimY;
    Enemy? best;
    var bestD = 340.0 * 340.0;
    for (final e in sim.enemies) {
      if (!e.alive) continue;
      final dx = e.x - p.cx, dy = e.cy - p.cy;
      final d2 = dx * dx + dy * dy;
      if (d2 >= bestD) continue;
      final d = math.sqrt(d2);
      if ((dx * ax + dy * ay) / d < 0.64) continue;
      best = e;
      bestD = d2;
    }
    if (best == null) return;
    final dx = best.x - p.cx, dy = best.cy - p.cy;
    final d = math.sqrt(dx * dx + dy * dy);
    final wx = dx / d, wy = dy / d;
    p.aimR = wx * p.body.rx + wy * p.body.ry;
    p.aimU = wx * p.body.ux + wy * p.body.uy;
  }

  void throwGrenade(Player p) {
    final b = sim.balance;
    // Thrown forward and up in the local frame.
    final r = p.facing * 0.75, u = 0.66;
    spawn(
      kind: ShotKind.grenade,
      hostile: false,
      x: p.cx + p.body.ux * 14,
      y: p.cy + p.body.uy * 14,
      vx: (p.body.rx * r + p.body.ux * u) * b.grenadeSpeed + p.body.vx * 0.5,
      vy: (p.body.ry * r + p.body.uy * u) * b.grenadeSpeed + p.body.vy * 0.5,
      damage: b.grenadeDamage * sim.loadout.damageMult,
      life: b.grenadeFuse,
      radius: 4,
      gravityScale: 1,
      blast: b.grenadeRadius,
      bounces: 2,
    );
    sim.events.add(SimEventType.grenadeThrow, p.cx, p.cy);
  }

  // ------------------------------------------------------------- enemy ---

  void enemyShot(
    ShotKind kind,
    double x,
    double y,
    double dx,
    double dy,
    double speed, {
    double gravityScale = 0,
    double homing = 0,
    double blast = 0,
    int life = 200,
    double radius = 4,
  }) {
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1e-6) return;
    spawn(
      kind: kind,
      hostile: true,
      x: x,
      y: y,
      vx: dx / d * speed,
      vy: dy / d * speed,
      life: life,
      radius: radius,
      gravityScale: gravityScale,
      homing: homing,
      blast: blast,
    );
    sim.events.add(SimEventType.enemyShot, x, y, a: kind.index);
  }

  // ------------------------------------------------------------ update ---

  void update() {
    final g = sim.balance.gravity;
    for (final b in items) {
      if (!b.active) continue;
      b.age++;
      if (--b.life <= 0) {
        _expire(b);
        continue;
      }
      if (b.gravityScale > 0) {
        sim.gravity.sample(b.x, b.y, _g);
        if (!_g.isZero) {
          b.vx += _g.dx * g * _g.scale * b.gravityScale;
          b.vy += _g.dy * g * _g.scale * b.gravityScale;
        }
      }
      if (b.homing > 0) _steer(b);
      if (b.drag != 1) {
        b.vx *= b.drag;
        b.vy *= b.drag;
      }
      _move(b);
      if (!b.active) continue;
      if (b.hostile) {
        final p = sim.player;
        if (!p.dead && !p.inVehicle && p.distanceTo(b.x, b.y) < b.radius) {
          if (b.blast > 0) {
            _detonate(b);
          } else {
            b.active = false;
            p.hurt(b.x, b.y);
          }
        } else if (sim.vehicles.hitByEnemyShot(b)) {
          b.active = false;
        }
      } else if (b.kind != ShotKind.grenade) {
        _hitEnemies(b);
      } else if (_touchesEnemy(b)) {
        _detonate(b);
      }
    }
  }

  void _move(Bullet b) {
    final sp = math.sqrt(b.vx * b.vx + b.vy * b.vy);
    if (sp < 1e-6) return;
    final dx = b.vx / sp, dy = b.vy / sp;
    if (sim.world.raycast(b.x, b.y, dx, dy, sp + b.radius, _ray)) {
      if (b.bounces > 0) {
        b.bounces--;
        // Reflect around the surface normal; works on curved surfaces too.
        final dot = b.vx * _ray.nx + b.vy * _ray.ny;
        b
          ..vx =
              (b.vx - 2 * dot * _ray.nx) *
              (b.kind == ShotKind.grenade ? 0.55 : 1)
          ..vy =
              (b.vy - 2 * dot * _ray.ny) *
              (b.kind == ShotKind.grenade ? 0.55 : 1)
          ..x = _ray.x + _ray.nx * (b.radius + 0.5)
          ..y = _ray.y + _ray.ny * (b.radius + 0.5);
        sim.events.add(SimEventType.hit, _ray.x, _ray.y, a: 0);
        return;
      }
      b
        ..x = _ray.x
        ..y = _ray.y;
      if (b.blast > 0) {
        _detonate(b);
      } else {
        b.active = false;
        sim.events.add(SimEventType.hit, b.x, b.y, a: b.hostile ? 1 : 0);
      }
      return;
    }
    b
      ..x += b.vx
      ..y += b.vy;
  }

  void _steer(Bullet b) {
    double tx, ty;
    if (b.hostile) {
      tx = sim.player.cx;
      ty = sim.player.cy;
    } else {
      Enemy? best;
      var bestD = 300.0 * 300.0;
      for (final e in sim.enemies) {
        if (!e.alive) continue;
        final d2 = (e.x - b.x) * (e.x - b.x) + (e.cy - b.y) * (e.cy - b.y);
        if (d2 < bestD) {
          bestD = d2;
          best = e;
        }
      }
      final boss = sim.bosses.nearestWeakPoint(b.x, b.y);
      if (best == null && boss == null) return;
      if (best != null) {
        tx = best.x;
        ty = best.cy;
      } else {
        tx = boss!.x;
        ty = boss.y;
      }
    }
    final sp = math.sqrt(b.vx * b.vx + b.vy * b.vy);
    final cur = math.atan2(b.vy, b.vx);
    final want = math.atan2(ty - b.y, tx - b.x);
    var diff = want - cur;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    final turn = diff.clamp(-b.homing, b.homing);
    final a = cur + turn;
    b
      ..vx = math.cos(a) * sp
      ..vy = math.sin(a) * sp;
  }

  bool _touchesEnemy(Bullet b) {
    for (final e in sim.enemies) {
      if (e.alive && e.distanceTo(b.x, b.y) < b.radius + e.spec.radius) {
        return true;
      }
    }
    return sim.bosses.pointHits(b.x, b.y, b.radius);
  }

  void _hitEnemies(Bullet b) {
    for (final e in sim.enemies) {
      if (!e.alive || e.id == b.lastHit) continue;
      if (e.distanceTo(b.x, b.y) >= b.radius + e.spec.radius) continue;
      if (b.blast > 0) {
        _detonate(b);
        return;
      }
      e.damage(b.damage, b.x, b.y, fromVx: b.vx, fromVy: b.vy);
      if (b.pierce) {
        b.lastHit = e.id;
        continue;
      }
      b.active = false;
      return;
    }
    if (sim.bosses.hitByShot(b)) {
      if (b.blast > 0) {
        _detonate(b);
      } else if (!b.pierce) {
        b.active = false;
      }
    }
  }

  void _expire(Bullet b) {
    if (b.blast > 0) {
      _detonate(b);
    } else {
      b.active = false;
    }
  }

  void _detonate(Bullet b) {
    b.active = false;
    sim.explode(
      b.x,
      b.y,
      b.blast,
      b.damage,
      byPlayer: !b.hostile,
      size: b.kind == ShotKind.grenade ? 2 : 1,
    );
  }
}
