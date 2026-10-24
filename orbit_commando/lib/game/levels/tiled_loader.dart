import 'dart:convert';
import 'dart:math' as math;

import '../../engine/physics/gravity.dart';
import 'level_data.dart';

/// Parses levels saved by the Tiled editor (JSON map format, `.tmj`/`.json`).
///
/// Expected object layers (by name):
/// - `terrain`   polygons = solid ground (any winding).
/// - `platforms` polylines = one-way platforms.
/// - `planets`   ellipses (circles) = planetoids. Properties: `influence`
///               (gravity radius, default 2.2x radius), `strength`, `style`.
/// - `gravity`   rectangles with `kind` = `uniform` | `zero`; uniform zones
///               take `gx`,`gy` (direction, default 0,1) and `strength`.
/// - `entities`  points (or rectangles) whose Tiled *class/type* names the
///               entity (`player`, `enemy`, `checkpoint`, `hostage`,
///               `cassette`, `pickup`, `vehicle`, `boss`, `hint`, `exit`).
///               Custom properties are passed through.
///
/// Map properties: `id`, `name`, `world`, `index`, `theme`, `gravity`
/// (`uniform` | `zero`), `music`, `parTime`, `targetScore`, `boss`.
class TiledLoader {
  static LevelData parse(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);

  static LevelData fromJson(Map<String, dynamic> map) {
    final props = _props(map['properties']);
    final tw = (map['tilewidth'] as num?)?.toDouble() ?? 16;
    final th = (map['tileheight'] as num?)?.toDouble() ?? 16;
    final width = ((map['width'] as num?)?.toDouble() ?? 0) * tw;
    final height = ((map['height'] as num?)?.toDouble() ?? 0) * th;

    final solids = <List<math.Point<double>>>[];
    final platforms = <List<math.Point<double>>>[];
    final planets = <PlanetDef>[];
    final zones = <GravityZone>[];
    final entities = <EntityDef>[];
    RectDef? exit;

    for (final layer in (map['layers'] as List<dynamic>? ?? const [])) {
      final l = layer as Map<String, dynamic>;
      if (l['type'] != 'objectgroup') continue;
      final name = (l['name'] as String? ?? '').toLowerCase();
      for (final o in (l['objects'] as List<dynamic>? ?? const [])) {
        final obj = o as Map<String, dynamic>;
        final ox = (obj['x'] as num?)?.toDouble() ?? 0;
        final oy = (obj['y'] as num?)?.toDouble() ?? 0;
        final w = (obj['width'] as num?)?.toDouble() ?? 0;
        final h = (obj['height'] as num?)?.toDouble() ?? 0;
        final p = _props(obj['properties']);
        final cls = (obj['type'] ?? obj['class'] ?? '') as String;
        switch (name) {
          case 'terrain':
            final poly = _points(obj['polygon'], ox, oy);
            if (poly != null && poly.length >= 3) {
              solids.add(poly);
            } else if (w > 0 && h > 0) {
              solids.add(_rect(ox, oy, w, h));
            }
          case 'platforms':
            final line =
                _points(obj['polyline'], ox, oy) ??
                (w > 0 ? [math.Point(ox, oy), math.Point(ox + w, oy)] : null);
            if (line != null && line.length >= 2) platforms.add(line);
          case 'planets':
            final r = math.min(w, h) / 2;
            planets.add(
              PlanetDef(
                cx: ox + w / 2,
                cy: oy + h / 2,
                radius: r,
                influence: _num(p['influence']) ?? r * 2.2,
                strength: _num(p['strength']) ?? 1,
                style: (_num(p['style']) ?? 0).toInt(),
              ),
            );
          case 'gravity':
            final kind = (p['kind'] ?? cls).toString();
            if (kind == 'zero') {
              zones.add(
                GravityZone.zero(x0: ox, y0: oy, x1: ox + w, y1: oy + h),
              );
            } else {
              final gx = _num(p['gx']) ?? 0, gy = _num(p['gy']) ?? 1;
              final len = math.sqrt(gx * gx + gy * gy);
              zones.add(
                GravityZone.uniform(
                  x0: ox,
                  y0: oy,
                  x1: ox + w,
                  y1: oy + h,
                  gx: len == 0 ? 0 : gx / len,
                  gy: len == 0 ? 1 : gy / len,
                ),
              );
            }
          case 'entities':
            final type = cls.isNotEmpty
                ? cls
                : (p['type'] ?? obj['name'] ?? '').toString();
            if (type == 'exit') {
              exit = RectDef(ox, oy, ox + w, oy + h);
              continue;
            }
            // Rectangles anchor at their bottom-centre (feet).
            final ex = w > 0 ? ox + w / 2 : ox;
            final ey = h > 0 ? oy + h : oy;
            entities.add(EntityDef(type: type, x: ex, y: ey, props: p));
        }
      }
    }

    final themeName = (props['theme'] ?? 'asteroids').toString();
    return LevelData(
      id: (props['id'] ?? 'level').toString(),
      name: (props['name'] ?? '').toString(),
      world: (_num(props['world']) ?? 1).toInt(),
      index: (_num(props['index']) ?? 1).toInt(),
      theme: LevelTheme.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => LevelTheme.asteroids,
      ),
      width: width,
      height: height,
      solids: solids,
      platforms: platforms,
      planets: planets,
      zones: zones,
      entities: entities,
      exit: exit,
      defaultGravity: props['gravity'] == 'zero'
          ? GravityKind.zero
          : GravityKind.uniform,
      music: (props['music'] ?? '').toString(),
      parTime: (_num(props['parTime']) ?? 240).toInt(),
      targetScore: (_num(props['targetScore']) ?? 20000).toInt(),
      isBoss: props['boss'] == true || props['boss'] == 'true',
    );
  }

  static Map<String, Object> _props(Object? raw) {
    final out = <String, Object>{};
    if (raw is List) {
      for (final e in raw) {
        final m = e as Map<String, dynamic>;
        final v = m['value'];
        if (v != null) out[m['name'] as String] = v as Object;
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) out[k.toString()] = v as Object;
      });
    }
    return out;
  }

  static double? _num(Object? v) => v is num
      ? v.toDouble()
      : (v == null ? null : double.tryParse(v.toString()));

  static List<math.Point<double>>? _points(Object? raw, double ox, double oy) {
    if (raw is! List) return null;
    return [
      for (final p in raw)
        math.Point(
          ox + ((p as Map<String, dynamic>)['x'] as num).toDouble(),
          oy + (p['y'] as num).toDouble(),
        ),
    ];
  }

  static List<math.Point<double>> _rect(
    double x,
    double y,
    double w,
    double h,
  ) => [
    math.Point(x, y),
    math.Point(x + w, y),
    math.Point(x + w, y + h),
    math.Point(x, y + h),
  ];
}
