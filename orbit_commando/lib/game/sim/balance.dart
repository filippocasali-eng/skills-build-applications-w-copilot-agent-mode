/// Every gameplay number lives here, with defaults matching
/// `assets/data/balance.json`. The JSON overrides the defaults at startup, so
/// tuning never needs a code change. Units: pixels and ticks (60 per second).
library;

enum Difficulty { easy, normal, arcade }

enum WeaponKind { blaster, spread, laser, plasma, homing, flame, ricochet }

extension WeaponLetter on WeaponKind {
  String get letter => switch (this) {
    WeaponKind.blaster => '',
    WeaponKind.spread => 'S',
    WeaponKind.laser => 'L',
    WeaponKind.plasma => 'P',
    WeaponKind.homing => 'H',
    WeaponKind.flame => 'F',
    WeaponKind.ricochet => 'R',
  };
}

class WeaponSpec {
  const WeaponSpec({
    required this.cooldown,
    required this.speed,
    required this.damage,
    required this.ammo,
    this.pellets = 1,
    this.spread = 0,
    this.life = 70,
    this.gravity = 0,
    this.bounces = 0,
    this.blastRadius = 0,
    this.homing = 0,
    this.pierce = false,
  });

  factory WeaponSpec.fromJson(Map<String, dynamic> j, WeaponSpec d) =>
      WeaponSpec(
        cooldown: (j['cooldown'] as num?)?.toInt() ?? d.cooldown,
        speed: (j['speed'] as num?)?.toDouble() ?? d.speed,
        damage: (j['damage'] as num?)?.toDouble() ?? d.damage,
        ammo: (j['ammo'] as num?)?.toInt() ?? d.ammo,
        pellets: (j['pellets'] as num?)?.toInt() ?? d.pellets,
        spread: (j['spread'] as num?)?.toDouble() ?? d.spread,
        life: (j['life'] as num?)?.toInt() ?? d.life,
        gravity: (j['gravity'] as num?)?.toDouble() ?? d.gravity,
        bounces: (j['bounces'] as num?)?.toInt() ?? d.bounces,
        blastRadius: (j['blastRadius'] as num?)?.toDouble() ?? d.blastRadius,
        homing: (j['homing'] as num?)?.toDouble() ?? d.homing,
        pierce: j['pierce'] as bool? ?? d.pierce,
      );

  /// Ticks between shots.
  final int cooldown;
  final double speed;
  final double damage;

  /// Shots per pickup (0 = infinite). For the laser: ticks of beam.
  final int ammo;
  final int pellets;

  /// Total fan angle in radians for multi-pellet weapons.
  final double spread;
  final int life;

  /// Fraction of the local gravity applied to the projectile.
  final double gravity;
  final int bounces;
  final double blastRadius;

  /// Max turn per tick in radians (homing missiles).
  final double homing;
  final bool pierce;
}

/// Per-enemy-type numbers. Behaviour lives in code (enemies.dart).
class EnemySpec {
  const EnemySpec({
    required this.hp,
    required this.speed,
    required this.score,
    this.tell = 24,
    this.cooldown = 90,
    this.range = 260,
    this.bulletSpeed = 4,
    this.radius = 14,
    this.height = 60,
  });

  factory EnemySpec.fromJson(Map<String, dynamic> j, EnemySpec d) => EnemySpec(
    hp: (j['hp'] as num?)?.toDouble() ?? d.hp,
    speed: (j['speed'] as num?)?.toDouble() ?? d.speed,
    score: (j['score'] as num?)?.toInt() ?? d.score,
    tell: (j['tell'] as num?)?.toInt() ?? d.tell,
    cooldown: (j['cooldown'] as num?)?.toInt() ?? d.cooldown,
    range: (j['range'] as num?)?.toDouble() ?? d.range,
    bulletSpeed: (j['bulletSpeed'] as num?)?.toDouble() ?? d.bulletSpeed,
    radius: (j['radius'] as num?)?.toDouble() ?? d.radius,
    height: (j['height'] as num?)?.toDouble() ?? d.height,
  );

  final double hp;
  final double speed;
  final int score;

  /// Warning time before an attack, in ticks. Golden rule: >= 18 (300 ms).
  final int tell;
  final int cooldown;
  final double range;
  final double bulletSpeed;
  final double radius;
  final double height;
}

class Balance {
  const Balance({
    this.gravity = 0.42,
    this.maxFall = 9,
    this.runSpeed = 2.7,
    this.runAccel = 0.45,
    this.airAccel = 0.3,
    this.friction = 0.55,
    this.jumpSpeed = 8.6,
    this.jumpCut = 0.45,
    this.coyoteTicks = 5,
    this.jumpBufferTicks = 6,
    this.jetpackAccel = 0.16,
    this.jetpackMax = 3.2,
    this.jetpackDrag = 0.985,
    this.dashSpeed = 7.5,
    this.dashTicks = 10,
    this.dashCooldown = 40,
    this.dashUnlockLevel = 3,
    this.respawnTicks = 45,
    this.invulnTicks = 120,
    this.hurtInvulnTicks = 90,
    this.startLives = 3,
    this.easyHp = 3,
    this.easyEnemySpeed = 0.8,
    this.startGrenades = 5,
    this.grenadeSpeed = 6.5,
    this.grenadeDamage = 8,
    this.grenadeRadius = 44,
    this.grenadeFuse = 70,
    this.meleeRange = 30,
    this.meleeDamage = 6,
    this.comboWindow = 90,
    this.comboMax = 10,
    this.hostageScore = 1000,
    this.cassetteScore = 2000,
    this.noDeathBonus = 5000,
    this.timeBonusPerSecond = 50,
    this.activationRange = 460,
    this.assistDeaths = 5,
    this.assistShieldTicks = 600,
    this.rankedAllowPaidUpgrades = true,
    this.weapons = defaultWeapons,
    this.enemies = defaultEnemies,
  });

  factory Balance.fromJson(Map<String, dynamic> j) {
    const d = Balance();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    final w = (j['weapons'] as Map<String, dynamic>?) ?? const {};
    final e = (j['enemies'] as Map<String, dynamic>?) ?? const {};
    return Balance(
      gravity: n('gravity', d.gravity),
      maxFall: n('maxFall', d.maxFall),
      runSpeed: n('runSpeed', d.runSpeed),
      runAccel: n('runAccel', d.runAccel),
      airAccel: n('airAccel', d.airAccel),
      friction: n('friction', d.friction),
      jumpSpeed: n('jumpSpeed', d.jumpSpeed),
      jumpCut: n('jumpCut', d.jumpCut),
      coyoteTicks: i('coyoteTicks', d.coyoteTicks),
      jumpBufferTicks: i('jumpBufferTicks', d.jumpBufferTicks),
      jetpackAccel: n('jetpackAccel', d.jetpackAccel),
      jetpackMax: n('jetpackMax', d.jetpackMax),
      jetpackDrag: n('jetpackDrag', d.jetpackDrag),
      dashSpeed: n('dashSpeed', d.dashSpeed),
      dashTicks: i('dashTicks', d.dashTicks),
      dashCooldown: i('dashCooldown', d.dashCooldown),
      dashUnlockLevel: i('dashUnlockLevel', d.dashUnlockLevel),
      respawnTicks: i('respawnTicks', d.respawnTicks),
      invulnTicks: i('invulnTicks', d.invulnTicks),
      hurtInvulnTicks: i('hurtInvulnTicks', d.hurtInvulnTicks),
      startLives: i('startLives', d.startLives),
      easyHp: i('easyHp', d.easyHp),
      easyEnemySpeed: n('easyEnemySpeed', d.easyEnemySpeed),
      startGrenades: i('startGrenades', d.startGrenades),
      grenadeSpeed: n('grenadeSpeed', d.grenadeSpeed),
      grenadeDamage: n('grenadeDamage', d.grenadeDamage),
      grenadeRadius: n('grenadeRadius', d.grenadeRadius),
      grenadeFuse: i('grenadeFuse', d.grenadeFuse),
      meleeRange: n('meleeRange', d.meleeRange),
      meleeDamage: n('meleeDamage', d.meleeDamage),
      comboWindow: i('comboWindow', d.comboWindow),
      comboMax: i('comboMax', d.comboMax),
      hostageScore: i('hostageScore', d.hostageScore),
      cassetteScore: i('cassetteScore', d.cassetteScore),
      noDeathBonus: i('noDeathBonus', d.noDeathBonus),
      timeBonusPerSecond: i('timeBonusPerSecond', d.timeBonusPerSecond),
      activationRange: n('activationRange', d.activationRange),
      assistDeaths: i('assistDeaths', d.assistDeaths),
      assistShieldTicks: i('assistShieldTicks', d.assistShieldTicks),
      rankedAllowPaidUpgrades:
          j['ranked_allow_paid_upgrades'] as bool? ?? d.rankedAllowPaidUpgrades,
      weapons: {
        for (final k in WeaponKind.values)
          k: w[k.name] is Map<String, dynamic>
              ? WeaponSpec.fromJson(
                  w[k.name] as Map<String, dynamic>,
                  defaultWeapons[k]!,
                )
              : defaultWeapons[k]!,
      },
      enemies: {
        for (final entry in defaultEnemies.entries)
          entry.key: e[entry.key] is Map<String, dynamic>
              ? EnemySpec.fromJson(
                  e[entry.key] as Map<String, dynamic>,
                  entry.value,
                )
              : entry.value,
      },
    );
  }

  final double gravity, maxFall;
  final double runSpeed, runAccel, airAccel, friction;
  final double jumpSpeed, jumpCut;
  final int coyoteTicks, jumpBufferTicks;
  final double jetpackAccel, jetpackMax, jetpackDrag;
  final double dashSpeed;
  final int dashTicks, dashCooldown, dashUnlockLevel;
  final int respawnTicks, invulnTicks, hurtInvulnTicks;
  final int startLives, easyHp;
  final double easyEnemySpeed;
  final int startGrenades;
  final double grenadeSpeed, grenadeDamage, grenadeRadius;
  final int grenadeFuse;
  final double meleeRange, meleeDamage;
  final int comboWindow, comboMax;
  final int hostageScore, cassetteScore, noDeathBonus, timeBonusPerSecond;
  final double activationRange;
  final int assistDeaths, assistShieldTicks;

  /// Whether paid Workshop upgrades apply in ranked modes (brief §7).
  final bool rankedAllowPaidUpgrades;
  final Map<WeaponKind, WeaponSpec> weapons;
  final Map<String, EnemySpec> enemies;

  static const defaultWeapons = <WeaponKind, WeaponSpec>{
    WeaponKind.blaster: WeaponSpec(cooldown: 9, speed: 9, damage: 1, ammo: 0),
    WeaponKind.spread: WeaponSpec(
      cooldown: 16,
      speed: 8,
      damage: 1,
      ammo: 40,
      pellets: 5,
      spread: 0.55,
      life: 45,
    ),
    WeaponKind.laser: WeaponSpec(
      cooldown: 1,
      speed: 0,
      damage: 0.3,
      ammo: 360,
      life: 1,
      pierce: true,
    ),
    WeaponKind.plasma: WeaponSpec(
      cooldown: 20,
      speed: 4.2,
      damage: 2,
      ammo: 30,
      life: 150,
      gravity: 0.35,
      blastRadius: 30,
    ),
    WeaponKind.homing: WeaponSpec(
      cooldown: 18,
      speed: 5.5,
      damage: 3,
      ammo: 30,
      life: 120,
      homing: 0.09,
      blastRadius: 16,
    ),
    WeaponKind.flame: WeaponSpec(
      cooldown: 3,
      speed: 6,
      damage: 0.55,
      ammo: 160,
      life: 20,
      spread: 0.25,
      pierce: true,
    ),
    WeaponKind.ricochet: WeaponSpec(
      cooldown: 11,
      speed: 8.5,
      damage: 1.6,
      ammo: 60,
      life: 110,
      bounces: 3,
    ),
  };

  static const defaultEnemies = <String, EnemySpec>{
    'grunt': EnemySpec(hp: 3, speed: 0.9, score: 100, tell: 24, cooldown: 110),
    'rocket': EnemySpec(
      hp: 4,
      speed: 1.1,
      score: 200,
      tell: 30,
      cooldown: 150,
      bulletSpeed: 3.2,
    ),
    'cyclops': EnemySpec(
      hp: 18,
      speed: 0.5,
      score: 600,
      tell: 36,
      cooldown: 170,
      radius: 18,
      height: 70,
    ),
    'bulwark': EnemySpec(
      hp: 12,
      speed: 0.6,
      score: 500,
      tell: 30,
      cooldown: 130,
      radius: 18,
      height: 72,
    ),
    'clerk': EnemySpec(
      hp: 3,
      speed: 0.8,
      score: 120,
      tell: 30,
      cooldown: 120,
      bulletSpeed: 4.5,
      height: 40,
      radius: 11,
    ),
    'drone': EnemySpec(
      hp: 2,
      speed: 1.4,
      score: 150,
      tell: 20,
      cooldown: 100,
      radius: 11,
      height: 22,
    ),
    'turret': EnemySpec(
      hp: 6,
      speed: 0,
      score: 250,
      tell: 30,
      cooldown: 120,
      range: 320,
      radius: 12,
      height: 22,
    ),
    'roller': EnemySpec(
      hp: 2,
      speed: 2.2,
      score: 150,
      tell: 24,
      radius: 10,
      height: 20,
    ),
    'sniper': EnemySpec(
      hp: 4,
      speed: 0,
      score: 400,
      tell: 70,
      cooldown: 160,
      range: 520,
      bulletSpeed: 10,
      height: 44,
      radius: 11,
    ),
    'minimech': EnemySpec(
      hp: 10,
      speed: 1.2,
      score: 450,
      tell: 30,
      cooldown: 100,
      radius: 15,
      height: 46,
    ),
    'jelly': EnemySpec(
      hp: 5,
      speed: 0.6,
      score: 300,
      tell: 40,
      cooldown: 150,
      range: 70,
      radius: 14,
      height: 30,
    ),
    'swarm': EnemySpec(
      hp: 1,
      speed: 1.9,
      score: 50,
      tell: 18,
      radius: 6,
      height: 10,
    ),
  };
}
