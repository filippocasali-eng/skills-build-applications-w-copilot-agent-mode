import 'dart:math' as math;

import 'package:orbit_commando/engine/physics/gravity.dart';
import 'package:orbit_commando/game/levels/level_data.dart';

math.Point<double> pt(double x, double y) => math.Point(x, y);

List<math.Point<double>> box(double x0, double y0, double x1, double y1) => [
  pt(x0, y0),
  pt(x1, y0),
  pt(x1, y1),
  pt(x0, y1),
];

/// Flat ground at y=400, 3000 px wide, player at x=100.
LevelData flatLevel({
  List<EntityDef> entities = const [],
  List<List<math.Point<double>>> platforms = const [],
  List<PlanetDef> planets = const [],
  List<GravityZone> zones = const [],
  RectDef? exit,
  GravityKind defaultGravity = GravityKind.uniform,
  bool ground = true,
}) => LevelData(
  id: 'test',
  name: 'Test',
  world: 1,
  index: 1,
  theme: LevelTheme.asteroids,
  width: 3000,
  height: 600,
  solids: ground ? [box(-200, 400, 3200, 600)] : const [],
  platforms: platforms,
  planets: planets,
  zones: zones,
  entities: [
    const EntityDef(type: 'player', x: 100, y: 400),
    ...entities,
  ],
  exit: exit,
  defaultGravity: defaultGravity,
);
