import 'dart:math' as math;

import '../../engine/physics/body.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';
import '../sim/input_frame.dart';
import '../weapons/weapons.dart';

enum VehicleKind { mech, bike, shuttle }

class Vehicle {
  Vehicle(this.kind, double x, double y)
    : body = switch (kind) {
        VehicleKind.mech => Body(radius: 18, height: 84),
        VehicleKind.bike => Body(radius: 14, height: 40),
        VehicleKind.shuttle => Body(radius: 16, height: 34),
      },
      maxHp = switch (kind) {
        VehicleKind.mech => 14,
        VehicleKind.bike => 8,
        VehicleKind.shuttle => 10,
      } {
    body
      ..x = x
      ..y = y;
    hp = maxHp;
  }

  final VehicleKind kind;
  final Body body;
  final int maxHp;

  /// Where the level placed it (vehicles come back after a death).
  double spawnX = 0, spawnY = 0;
  int hp = 1;
  bool occupied = false;
  bool destroyed = false;
  int facing = 1;
  int cooldown = 0;
  int hurtCooldown = 0;
  int flash = 0;

  /// Mech stomp / jump squash, for animation.
  int squash = 0;

  double get cx => body.cx;
  double get cy => body.cy;
}

/// Mech (spring jumps, stomps), rocket bike (fast runs) and shuttle
/// (free-flight shoot'em up sections).
class Vehicles {
  Vehicles(this.sim) {
    for (final e in sim.level.ofType('vehicle')) {
      final kind = VehicleKind.values.firstWhere(
        (k) => k.name == e.str('kind', 'mech'),
        orElse: () => VehicleKind.mech,
      );
      final v = Vehicle(kind, e.x, e.y)
        ..spawnX = e.x
        ..spawnY = e.y;
      v.body.updateFrame(sim.gravity);
      list.add(v);
    }
  }

  final GameSim sim;
  final List<Vehicle> list = [];

  Vehicle? get current {
    for (final v in list) {
      if (v.occupied) return v;
    }
    return null;
  }

  /// Called when the player respawns: lost vehicles return, at their
  /// spawn point or at the checkpoint if that is further along.
  void onPlayerRespawn() {
    final p = sim.player;
    for (final v in list) {
      if (!v.destroyed) continue;
      final atCheckpoint = p.checkpointX > v.spawnX;
      v
        ..destroyed = false
        ..occupied = false
        ..hp = v.maxHp
        ..flash = 0;
      v.body
        ..x = atCheckpoint ? p.checkpointX + 50 : v.spawnX
        ..y = atCheckpoint ? p.checkpointY - 4 : v.spawnY
        ..vx = 0
        ..vy = 0;
      v.body.updateFrame(sim.gravity);
    }
  }

  void update(InputFrame input) {
    final p = sim.player;
    for (final v in list) {
      if (v.destroyed) continue;
      if (v.flash > 0) v.flash--;
      if (v.hurtCooldown > 0) v.hurtCooldown--;
      if (v.cooldown > 0) v.cooldown--;
      if (v.squash > 0) v.squash--;
      if (!v.occupied) {
        if (v.kind != VehicleKind.shuttle) {
          v.body.setLocal(0, v.body.vu);
          v.body.step(sim.world, sim.gravity, g: sim.balance.gravity);
        }
        if (!p.dead && !p.inVehicle && p.distanceTo(v.cx, v.cy) < 24) {
          v.occupied = true;
          p.inVehicle = true;
          v.facing = p.facing;
          sim.events.add(
            SimEventType.vehicleEnter,
            v.cx,
            v.cy,
            a: v.kind.index,
          );
        }
        continue;
      }
      _drive(v, input);
      // Fell out of the level: the vehicle is lost with its pilot.
      final lv = sim.level;
      if (v.body.y > lv.height + 200 ||
          v.body.x < -600 ||
          v.body.x > lv.width + 600) {
        v
          ..destroyed = true
          ..occupied = false;
        p.inVehicle = false;
        p.die(force: true);
        continue;
      }
      // The pilot rides along: keeps camera, pickups and checkpoints working.
      p.body
        ..x = v.body.x
        ..y = v.body.y
        ..ux = v.body.ux
        ..uy = v.body.uy
        ..vx = v.body.vx
        ..vy = v.body.vy;
      p.facing = v.facing;
      _crush(v);
    }
  }

  void _drive(Vehicle v, InputFrame input) {
    final g = sim.balance.gravity;
    final b = v.body;
    if (input.dx != 0) v.facing = input.dx;
    switch (v.kind) {
      case VehicleKind.mech:
        var vr = b.vr;
        final target = input.dx * 2.3;
        vr += (target - vr) * 0.25;
        var vu = b.vu;
        if (input.jump && b.grounded) {
          vu = 11.5; // the spring!
          v.squash = 10;
          sim.events.add(SimEventType.jump, b.x, b.y, a: 1);
        }
        b.setLocal(vr, vu);
        final wasAir = !b.grounded;
        b.step(sim.world, sim.gravity, g: g * 1.1);
        if (wasAir && b.grounded) {
          v.squash = 8;
          sim.events.add(SimEventType.land, b.x, b.y, a: 2);
          sim.impact(stop: 2);
        }
        if (input.fire && v.cooldown == 0) {
          _fire(v, ShotKind.vehicleShell, 8.5, 3, input, height: 62);
          v.cooldown = 14;
        }
      case VehicleKind.bike:
        final target = switch (input.dx) {
          1 => 6.2,
          -1 => 2.4,
          _ => 4.6,
        };
        var vr = b.vr;
        vr += (target - vr) * 0.08;
        var vu = b.vu;
        if (input.jump && (b.grounded || b.airTicks < 5) && vu <= 0.5) {
          vu = 9;
          sim.events.add(SimEventType.jump, b.x, b.y);
        }
        b.setLocal(vr, vu);
        b.step(sim.world, sim.gravity, g: g);
        v.facing = 1;
        if (input.fire && v.cooldown == 0) {
          _fire(
            v,
            ShotKind.blaster,
            10,
            1.4,
            const InputFrame(dx: 1),
            height: 26,
          );
          v.cooldown = 7;
        }
      case VehicleKind.shuttle:
        // Free flight in screen-ish axes of the current frame, no gravity.
        final ax = input.dx * 0.45, ay = input.dy * 0.45;
        var vr = b.vr * 0.88 + ax, vu = b.vu * 0.88 + ay;
        final sp = math.sqrt(vr * vr + vu * vu);
        if (sp > 3.8) {
          vr *= 3.8 / sp;
          vu *= 3.8 / sp;
        }
        b.setLocal(vr, vu);
        // Integrate manually (no gravity), but still collide.
        b.x += b.vx;
        b.y += b.vy;
        if (sim.world.pointBlocked(b.cx, b.cy, 14)) {
          b.x -= b.vx;
          b.y -= b.vy;
          b.vx = 0;
          b.vy = 0;
          _damage(v, 1);
        }
        v.facing = 1;
        if (input.fire && v.cooldown == 0) {
          for (final off in const [-7.0, 7.0]) {
            sim.bullets.spawn(
              kind: ShotKind.blaster,
              hostile: false,
              x: b.cx + b.rx * 22 + b.ux * off,
              y: b.cy + b.ry * 22 + b.uy * off,
              vx: b.rx * 10,
              vy: b.ry * 10,
              damage: 1.3 * sim.loadout.damageMult,
              life: 60,
            );
          }
          sim.events.add(SimEventType.shot, b.cx, b.cy, a: 0);
          v.cooldown = 7;
        }
    }
  }

  void _fire(
    Vehicle v,
    ShotKind kind,
    double speed,
    double dmg,
    InputFrame input, {
    required double height,
  }) {
    final b = v.body;
    var ar = input.dx == 0 && input.dy == 0
        ? v.facing.toDouble()
        : input.dx.toDouble();
    final au = input.dy.toDouble().clamp(0.0, 1.0); // no shooting down
    if (ar == 0 && au == 0) ar = v.facing.toDouble();
    final l = math.sqrt(ar * ar + au * au);
    final dx = (b.rx * ar + b.ux * au) / l, dy = (b.ry * ar + b.uy * au) / l;
    final mx = b.x + b.ux * height + dx * 30;
    final my = b.y + b.uy * height + dy * 30;
    sim.bullets.spawn(
      kind: kind,
      hostile: false,
      x: mx,
      y: my,
      vx: dx * speed,
      vy: dy * speed,
      damage: dmg * sim.loadout.damageMult,
      life: 80,
      radius: kind == ShotKind.vehicleShell ? 6 : 3,
      blast: kind == ShotKind.vehicleShell ? 26 : 0,
    );
    sim.events.add(
      SimEventType.shot,
      mx,
      my,
      a: kind == ShotKind.vehicleShell ? 3 : 0,
    );
  }

  /// Mech stomps and bike rams; any vehicle takes contact damage.
  void _crush(Vehicle v) {
    for (final e in sim.enemies) {
      if (!e.alive) continue;
      final d = e.distanceTo(v.cx, v.cy);
      if (d > v.body.radius + e.spec.radius + 10) continue;
      final below =
          ((e.x - v.cx) * v.body.ux + (e.cy - v.cy) * v.body.uy) < -10;
      if (v.kind == VehicleKind.mech && below && v.body.vu < 0) {
        e.damage(50, e.x, e.cy, explosive: true);
        sim.impact(stop: 3);
      } else if (v.kind == VehicleKind.bike && v.body.vr > 4) {
        e.damage(4, e.x, e.cy, explosive: true);
        _damage(v, 1);
      } else {
        _damage(v, 1);
      }
    }
  }

  bool hitByEnemyShot(Bullet b) {
    final v = current;
    if (v == null) return false;
    final dx = b.x - v.cx, dy = b.y - v.cy;
    final r = v.body.height * 0.5;
    if (dx * dx + dy * dy > r * r) return false;
    _damage(v, b.blast > 0 ? 2 : 1, force: true);
    if (b.blast > 0) {
      sim.events.add(SimEventType.explosion, b.x, b.y, a: 1, b: b.blast);
    }
    return true;
  }

  void _damage(Vehicle v, int amount, {bool force = false}) {
    if (!force && v.hurtCooldown > 0) return;
    v.hurtCooldown = 30;
    v.hp -= amount;
    v.flash = 6;
    sim.events.add(SimEventType.hit, v.cx, v.cy, a: 3);
    if (v.hp <= 0) _eject(v);
  }

  void _eject(Vehicle v) {
    v
      ..destroyed = true
      ..occupied = false;
    final p = sim.player;
    p.inVehicle = false;
    p.body
      ..x = v.cx
      ..y = v.cy;
    p.body.setLocal(-v.facing * 2.0, 9);
    p.invuln = 120;
    sim.explode(v.cx, v.cy, 40, 4, byPlayer: true, size: 2);
    sim.events.add(SimEventType.vehicleEject, v.cx, v.cy, a: v.kind.index);
  }
}
