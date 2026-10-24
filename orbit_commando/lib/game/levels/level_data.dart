import 'dart:math' as math;

import '../../engine/physics/geometry.dart';
import '../../engine/physics/gravity.dart';

/// Visual + audio theme of a level (one per world).
enum LevelTheme { asteroids, station, glorbo }

/// A point entity placed in the level editor.
class EntityDef {
  const EntityDef({
    required this.type,
    required this.x,
    required this.y,
    this.props = const {},
  });

  /// e.g. 'enemy', 'checkpoint', 'hostage', 'cassette', 'pickup', 'vehicle',
  /// 'boss', 'player', 'hint'.
  final String type;
  final double x, y;
  final Map<String, Object> props;

  String str(String k, [String d = '']) => props[k]?.toString() ?? d;
  double number(String k, [double d = 0]) {
    final v = props[k];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? d;
  }

  bool flag(String k) => props[k] == true || props[k] == 'true';
}

class PlanetDef {
  const PlanetDef({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.influence,
    this.strength = 1,
    this.style = 0,
  });

  final double cx, cy, radius, influence, strength;

  /// Which planetoid art to use.
  final int style;
}

class RectDef {
  const RectDef(this.x0, this.y0, this.x1, this.y1);

  final double x0, y0, x1, y1;
  bool contains(double x, double y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
}

/// A fully parsed level, independent of the file format.
class LevelData {
  LevelData({
    required this.id,
    required this.name,
    required this.world,
    required this.index,
    required this.theme,
    required this.width,
    required this.height,
    required this.solids,
    required this.platforms,
    required this.planets,
    required this.zones,
    required this.entities,
    required this.exit,
    this.defaultGravity = GravityKind.uniform,
    this.music = '',
    this.parTime = 240,
    this.targetScore = 20000,
    this.isBoss = false,
  });

  final String id;
  final String name;
  final int world;

  /// 1-based level number inside the world (5 = boss stage).
  final int index;
  final LevelTheme theme;
  final double width, height;

  /// Closed polygons of solid terrain (clockwise on screen: solid inside).
  final List<List<math.Point<double>>> solids;

  /// One-way platforms as polylines (walk on the top side).
  final List<List<math.Point<double>>> platforms;
  final List<PlanetDef> planets;
  final List<GravityZone> zones;
  final List<EntityDef> entities;
  final RectDef? exit;
  final GravityKind defaultGravity;
  final String music;

  /// Seconds; finishing faster earns a time bonus and the Speedrun medal.
  final int parTime;
  final int targetScore;
  final bool isBoss;

  Iterable<EntityDef> ofType(String type) =>
      entities.where((e) => e.type == type);

  EntityDef get playerStart => entities.firstWhere(
    (e) => e.type == 'player',
    orElse: () => EntityDef(type: 'player', x: 64, y: height - 64),
  );

  /// Builds collision geometry. Polygons are re-wound so the solid side is
  /// always on the right of each edge (see [Seg]).
  StaticWorld buildWorld() {
    final segs = <Seg>[];
    for (final poly in solids) {
      final pts = _clockwise(poly);
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        if (a == b) continue;
        segs.add(Seg(a.x, a.y, b.x, b.y));
      }
    }
    for (final line in platforms) {
      // Platforms are walked on from above: make sure they run left->right
      // so the free side (normal) points up.
      final pts = line.first.x <= line.last.x ? line : line.reversed.toList();
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        if (a == b) continue;
        segs.add(Seg(a.x, a.y, b.x, b.y, oneWay: true));
      }
    }
    final discs = [for (final p in planets) Disc(p.cx, p.cy, p.radius)];
    return StaticWorld(segments: segs, discs: discs);
  }

  GravityField buildGravity() => GravityField(
    zones: [
      ...zones,
      for (final p in planets)
        GravityZone.radial(
          cx: p.cx,
          cy: p.cy,
          surface: p.radius,
          influence: p.influence,
          strength: p.strength,
        ),
    ],
    defaultKind: defaultGravity,
  );

  /// Signed area > 0 means clockwise in screen coordinates (y down).
  static double signedArea(List<math.Point<double>> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[i], r = p[(i + 1) % p.length];
      a += q.x * r.y - r.x * q.y;
    }
    return a / 2;
  }

  static List<math.Point<double>> _clockwise(List<math.Point<double>> p) =>
      signedArea(p) >= 0 ? p : p.reversed.toList();
}
