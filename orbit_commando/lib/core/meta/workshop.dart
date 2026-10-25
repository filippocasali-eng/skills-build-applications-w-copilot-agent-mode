import '../../game/sim/balance.dart';
import '../../game/sim/game_sim.dart';
import '../progress/progress.dart';

/// Workshop upgrades: power levels bought with tokens (or gems).
class Upgrade {
  const Upgrade(this.id, this.maxLevel, this.tokenCosts, this.gemCosts);

  final String id;
  final int maxLevel;

  /// Cost of buying level i+1.
  final List<int> tokenCosts;
  final List<int> gemCosts;
}

class Workshop {
  static const upgrades = [
    Upgrade('damage', 5, [150, 300, 600, 1000, 1600], [40, 80, 150, 250, 400]),
    Upgrade('hp', 2, [800, 2000], [200, 450]),
    Upgrade('shield', 5, [120, 250, 450, 700, 1000], [30, 60, 110, 170, 250]),
    Upgrade(
      'fireRate',
      5,
      [200, 400, 700, 1100, 1700],
      [50, 100, 170, 270, 420],
    ),
    Upgrade('grenades', 5, [80, 160, 300, 500, 800], [20, 40, 75, 120, 200]),
  ];

  static Upgrade byId(String id) => upgrades.firstWhere((u) => u.id == id);

  /// Loadout for a run. Arcade difficulty ignores upgrades (brief §12);
  /// ranked modes follow balance.ranked_allow_paid_upgrades.
  static Loadout loadoutFor(
    Progress p, {
    required Difficulty difficulty,
    required bool ranked,
    required Balance balance,
    bool dashUnlocked = false,
    WeaponKind? forcedWeapon,
  }) {
    final use =
        difficulty != Difficulty.arcade &&
        (!ranked || balance.rankedAllowPaidUpgrades);
    int lv(String id) => use ? (p.upgrades[id] ?? 0) : 0;
    return Loadout(
      damageMult: 1 + 0.1 * lv('damage'),
      fireRateMult: 1 - 0.06 * lv('fireRate'),
      extraHp: lv('hp'),
      shieldTicks: lv('shield') * 120,
      extraGrenades: lv('grenades'),
      dashUnlocked: dashUnlocked,
      forcedWeapon: forcedWeapon,
    );
  }
}
