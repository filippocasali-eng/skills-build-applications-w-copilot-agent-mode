/// Score and combo multiplier rules.
class ScoreSystem {
  static const int gatePoints = 100;
  static const int dropPoints = 10;
  static const int jumpPoints = 25;
  static const int nearMissPoints = 50;

  /// Combo thresholds (consecutive good gates) → multiplier.
  static const List<int> tierThresholds = [0, 5, 12, 22, 35];
  static const List<int> tierMultipliers = [1, 2, 3, 5, 8];

  int score = 0;
  int combo = 0;
  int maxCombo = 0;

  static int tierFor(int combo) {
    var tier = 0;
    for (var i = 0; i < tierThresholds.length; i++) {
      if (combo >= tierThresholds[i]) tier = i;
    }
    return tier;
  }

  int get tier => tierFor(combo);
  int get multiplier => tierMultipliers[tier];

  /// Registers a good gate. Returns true if a new combo tier was reached.
  bool gatePassed() {
    final before = tier;
    combo++;
    if (combo > maxCombo) maxCombo = combo;
    score += gatePoints * multiplier;
    return tier > before;
  }

  void add(int points) => score += points * multiplier;

  void breakCombo() => combo = 0;

  void reset() {
    score = 0;
    combo = 0;
    maxCombo = 0;
  }
}
