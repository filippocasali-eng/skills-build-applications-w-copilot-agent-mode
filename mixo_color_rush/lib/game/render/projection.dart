/// Pseudo-3D projection: lanes converge to a vanishing point.
class Projection {
  static const double focal = 7;

  double width = 1;
  double height = 1;
  double horizonY = 0;
  double groundY = 0;
  double laneWidth = 1;
  int lanes = 3;

  void resize(double w, double h, int laneCount) {
    width = w;
    height = h;
    lanes = laneCount;
    horizonY = h * 0.30;
    groundY = h * 0.84;
    laneWidth = (w * 0.86) / laneCount;
  }

  double get centerX => width / 2;

  /// Scale factor for something [z] units ahead of Mixo.
  double scale(double z) =>
      focal / (focal + (z < -focal + 0.5 ? -focal + 0.5 : z));

  /// Screen y of the floor at [z].
  double floorY(double z) => horizonY + (groundY - horizonY) * scale(z);

  /// Screen x of the centre of (possibly fractional) [lane] at scale [s].
  double laneX(double lane, double s) =>
      centerX + (lane - (lanes - 1) / 2) * laneWidth * s;
}
