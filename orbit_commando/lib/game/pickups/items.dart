import 'dart:math' as math;

import '../../engine/physics/body.dart';
import '../sim/balance.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';

/// A collectable lying in the level.
class Pickup {
  Pickup(this.item, this.x, this.y, {this.dropped = false});

  /// 'S','L','P','H','F','R' (weapons), 'grenade', 'life', 'medkit'.
  final String item;
  double x, y;
  final bool dropped;
  bool taken = false;

  /// Dropped pickups vanish after a while.
  int life = 900;
  int age = 0;
}

enum HostageState { tied, waving, leaving, gone }

/// A tied-up astronaut. Touch (or knife the ropes) to free: waves, drops a
/// reward and walks away.
class Hostage {
  Hostage(this.x, this.y, this.reward, double ux, double uy)
    : body = Body(radius: 9, height: 34) {
    body
      ..x = x
      ..y = y
      ..ux = ux
      ..uy = uy;
  }

  final double x, y;
  final String reward;
  final Body body;
  HostageState state = HostageState.tied;
  int timer = 0;
}

class Cassette {
  Cassette(this.index, this.x, this.y);

  final int index;
  final double x, y;
  bool taken = false;
}

class Checkpoint {
  Checkpoint(this.x, this.y);

  final double x, y;
  bool reached = false;
}

/// Pickups, hostages, cassettes and checkpoints.
class Items {
  Items(this.sim) {
    for (final e in sim.level.entities) {
      switch (e.type) {
        case 'pickup':
          pickups.add(Pickup(e.str('item', 'S'), e.x, e.y - 12));
        case 'hostage':
          final g = sim.gravity;
          final probe = Body(radius: 9, height: 34)
            ..x = e.x
            ..y = e.y;
          probe.updateFrame(g);
          hostages.add(
            Hostage(e.x, e.y, e.str('reward', 'grenade'), probe.ux, probe.uy),
          );
        case 'cassette':
          cassettes.add(Cassette(e.number('index').toInt(), e.x, e.y - 14));
        case 'checkpoint':
          checkpoints.add(Checkpoint(e.x, e.y));
      }
    }
  }

  final GameSim sim;
  final List<Pickup> pickups = [];
  final List<Hostage> hostages = [];
  final List<Cassette> cassettes = [];
  final List<Checkpoint> checkpoints = [];

  int get hostagesTotal => hostages.length;
  int get hostagesFreed =>
      hostages.where((h) => h.state != HostageState.tied).length;

  /// Bit mask of cassettes found this run (bit = cassette index).
  int get cassettesFound {
    var m = 0;
    for (final c in cassettes) {
      if (c.taken) m |= 1 << c.index;
    }
    return m;
  }

  void dropPickup(String item, double x, double y) {
    pickups.add(Pickup(item, x, y, dropped: true));
  }

  static const _weaponLetters = {
    'S': WeaponKind.spread,
    'L': WeaponKind.laser,
    'P': WeaponKind.plasma,
    'H': WeaponKind.homing,
    'F': WeaponKind.flame,
    'R': WeaponKind.ricochet,
  };

  void update() {
    final p = sim.player;
    final alive = !p.dead;

    for (final k in pickups) {
      if (k.taken) continue;
      k.age++;
      if (k.dropped && --k.life <= 0) {
        k.taken = true;
        continue;
      }
      if (!alive || p.inVehicle) continue;
      if (p.distanceTo(k.x, k.y) < 12) {
        k.taken = true;
        _give(k.item, k.x, k.y);
      }
    }
    pickups.removeWhere((k) => k.taken);

    for (final h in hostages) {
      switch (h.state) {
        case HostageState.tied:
          if (alive && p.distanceTo(h.body.cx, h.body.cy) < 14) {
            h.state = HostageState.waving;
            h.timer = 70;
            sim.addScore(sim.balance.hostageScore, h.x, h.y);
            sim.events.add(SimEventType.hostageFreed, h.body.cx, h.body.cy);
            dropPickup(
              h.reward,
              h.body.cx + h.body.ux * 20,
              h.body.cy + h.body.uy * 20,
            );
          }
        case HostageState.waving:
          if (--h.timer <= 0) {
            h.state = HostageState.leaving;
            h.timer = 120;
          }
        case HostageState.leaving:
          // Runs off-screen, away from the player.
          final dir =
              ((h.body.cx - p.cx) * h.body.rx +
                      (h.body.cy - p.cy) * h.body.ry) >=
                  0
              ? 1.0
              : -1.0;
          h.body.setLocal(dir * 2.4, h.body.vu);
          h.body.step(sim.world, sim.gravity, g: sim.balance.gravity);
          if (--h.timer <= 0) h.state = HostageState.gone;
        case HostageState.gone:
          break;
      }
    }

    for (final c in cassettes) {
      if (c.taken || !alive) continue;
      if (p.distanceTo(c.x, c.y) < 14) {
        c.taken = true;
        sim.addScore(sim.balance.cassetteScore, c.x, c.y);
        sim.events.add(SimEventType.cassette, c.x, c.y, a: c.index);
      }
    }

    for (final cp in checkpoints) {
      if (cp.reached || !alive) continue;
      final dx = cp.x - p.body.x, dy = cp.y - p.body.y;
      if (dx * dx + dy * dy < 48 * 48) {
        cp.reached = true;
        p.setCheckpoint(cp.x, cp.y);
        sim.events.add(SimEventType.checkpoint, cp.x, cp.y);
      }
    }
  }

  void _give(String item, double x, double y) {
    final p = sim.player;
    final w = _weaponLetters[item];
    if (w != null) {
      p.giveWeapon(w);
      sim.events.add(SimEventType.weaponPickup, x, y, a: w.index);
      return;
    }
    switch (item) {
      case 'grenade':
        p.grenades = math.min(p.grenades + 5, 30);
      case 'life':
        p.lives++;
        sim.events.add(SimEventType.oneUp, x, y);
      case 'medkit':
        p.hp = math.min(p.hp + 1, p.maxHp);
      case 'shield':
        p.shieldTicks = 600;
    }
    sim.events.add(SimEventType.pickup, x, y);
  }
}
