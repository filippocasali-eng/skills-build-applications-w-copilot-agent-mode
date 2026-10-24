import 'profile.dart';

/// Local trophies. Each is a pure condition on the profile.
enum Achievement {
  firstRun(10),
  runs10(25),
  runs100(100),
  score1k(15),
  score5k(30),
  score10k(50),
  score25k(100),
  comboX5(30),
  comboX8(60),
  survive60(20),
  survive120(40),
  survive180(80),
  gates100(20),
  gates1000(60),
  firstMix(20),
  purple50(40),
  allSecondaries(40),
  nearMiss10(30),
  dailyFirst(15),
  daily7(50),
  academyAll(80),
  ghostBeaten(40),
  level5(20),
  level10(40),
  level20(80),
  collector5(30);

  const Achievement(this.reward);

  /// Stars granted when unlocked.
  final int reward;

  bool isMet(PlayerProfile p) {
    final s = p.stats;
    return switch (this) {
      firstRun => s.runs >= 1,
      runs10 => s.runs >= 10,
      runs100 => s.runs >= 100,
      score1k => s.bestScore >= 1000,
      score5k => s.bestScore >= 5000,
      score10k => s.bestScore >= 10000,
      score25k => s.bestScore >= 25000,
      comboX5 => s.bestMultiplier >= 5,
      comboX8 => s.bestMultiplier >= 8,
      survive60 => s.longestRunMs >= 60000,
      survive120 => s.longestRunMs >= 120000,
      survive180 => s.longestRunMs >= 180000,
      gates100 => s.gates >= 100,
      gates1000 => s.gates >= 1000,
      firstMix => s.mixGates >= 1,
      purple50 => s.okByColor[5] >= 50,
      allSecondaries =>
        s.okByColor[3] > 0 && s.okByColor[4] > 0 && s.okByColor[5] > 0,
      nearMiss10 => s.nearMisses >= 10,
      dailyFirst => s.dailyPlays >= 1,
      daily7 => s.dailyPlays >= 7,
      academyAll => p.academyStars.length >= 8,
      ghostBeaten => s.ghostWins >= 1,
      level5 => p.level >= 5,
      level10 => p.level >= 10,
      level20 => p.level >= 20,
      collector5 => p.unlocked.where((u) => u.startsWith('skin_')).length >= 5,
    };
  }
}
