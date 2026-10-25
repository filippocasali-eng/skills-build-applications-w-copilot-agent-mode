import '../../engine/math/det_random.dart';
import 'remote_config.dart';
import 'wallet.dart';

String dayKey(DateTime t) {
  final u = t.toUtc();
  return '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
}

/// Next UTC midnight: the real expiry of everything "daily".
DateTime nextUtcMidnight(DateTime now) {
  final u = now.toUtc();
  return DateTime.utc(u.year, u.month, u.day).add(const Duration(days: 1));
}

String formatCountdown(Duration d) {
  if (d.isNegative) return '0:00:00';
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  if (h >= 24) return '${d.inDays}d ${h % 24}h';
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// "Shop of the day": 4 slots, rotating every 24h at UTC midnight. The
/// selection is a pure function of the day, so every player sees the same
/// shop and the timer is the real expiry.
class DailyShop {
  static List<Map<String, dynamic>> slots(RemoteConfig rc, DateTime now) {
    final pool = rc.list('daily_shop_pool');
    if (pool.isEmpty) return const [];
    final u = now.toUtc();
    final seed = u.year * 1000 + u.month * 40 + u.day;
    final rng = DetRandom(seed);
    final picked = <Map<String, dynamic>>[];
    final idx = List<int>.generate(pool.length, (i) => i);
    for (var i = 0; i < 4 && idx.isNotEmpty; i++) {
      picked.add(pool[idx.removeAt(rng.nextInt(idx.length))]);
    }
    return picked;
  }

  static DateTime refreshAt(DateTime now) => nextUtcMidnight(now);
}

/// Time-limited offer created by a trigger (e.g. 3 failed boss attempts).
class FlashOffer {
  const FlashOffer(this.id, this.expires, this.config);

  final String id;
  final DateTime expires;
  final Map<String, dynamic> config;

  bool active(DateTime now) => now.isBefore(expires);
}

class FlashOffers {
  /// Returns the offer for [trigger] if one is defined.
  static FlashOffer? forTrigger(RemoteConfig rc, String trigger, DateTime now) {
    for (final o in rc.list('flash_offers')) {
      if (o['trigger'] == trigger) {
        final hours = (o['hours'] as num?)?.toInt() ?? 4;
        return FlashOffer(
          o['id'] as String,
          now.add(Duration(hours: hours)),
          o,
        );
      }
    }
    return null;
  }
}

/// 30-day season pass with a free and a premium track.
class Season {
  const Season({
    required this.id,
    required this.start,
    required this.days,
    required this.tiers,
    required this.xpPerTier,
    required this.sku,
  });

  factory Season.from(RemoteConfig rc) {
    final s = rc.map('season');
    return Season(
      id: s['id'] as String? ?? 's1',
      start: DateTime.parse('${s['start'] ?? '2026-10-01'}T00:00:00Z'),
      days: (s['days'] as num?)?.toInt() ?? 30,
      tiers: (s['tiers'] as num?)?.toInt() ?? 30,
      xpPerTier: (s['xp_per_tier'] as num?)?.toInt() ?? 400,
      sku: s['sku'] as String? ?? 'season_pass_s1',
    );
  }

  final String id;
  final DateTime start;
  final int days, tiers, xpPerTier;
  final String sku;

  /// Seasons repeat back to back from [start].
  int index(DateTime now) => now.toUtc().difference(start).inDays ~/ days;
  DateTime endsAt(DateTime now) =>
      start.add(Duration(days: days * (index(now) + 1)));
  int tier(int xp) => (xp ~/ xpPerTier).clamp(0, tiers);

  /// Reward for a tier on a track (deterministic table).
  static Map<String, Object> reward(int tier, {required bool premium}) {
    if (premium) {
      if (tier % 10 == 0) return {'kind': 'skin', 'id': 'skin_season_$tier'};
      if (tier % 5 == 0) return {'kind': 'capsule', 'amount': 2};
      return {'kind': 'gems', 'amount': 15};
    }
    if (tier % 5 == 0) return {'kind': 'capsule', 'amount': 1};
    if (tier.isEven) return {'kind': 'tokens', 'amount': 150};
    return {'kind': 'credits', 'amount': 1};
  }
}

/// 7-day login calendar with growing rewards; missing a day resets.
class DailyLogin {
  static const rewards = <Map<String, Object>>[
    {'kind': 'tokens', 'amount': 100},
    {'kind': 'credits', 'amount': 2},
    {'kind': 'tokens', 'amount': 250},
    {'kind': 'capsule', 'amount': 1},
    {'kind': 'tokens', 'amount': 500},
    {'kind': 'gems', 'amount': 20},
    {'kind': 'capsule', 'amount': 3},
  ];

  static bool canClaim(Wallet w, DateTime now) =>
      w.lastLoginDate != dayKey(now);

  /// Day index (0..6) that would be claimed now.
  static int nextDay(Wallet w, DateTime now) {
    if (w.lastLoginDate.isEmpty) return 0;
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    if (w.lastLoginDate == yesterday) return (w.loginDay + 1) % 7;
    if (w.lastLoginDate == dayKey(now)) return w.loginDay;
    return 0; // streak broken
  }
}

/// Spending limit and age/country checks (brief §8.6, §8.9).
class SpendGuard {
  static bool allowed({
    required Wallet wallet,
    required int? limitCents,
    required int priceCents,
    required DateTime now,
  }) =>
      limitCents == null ||
      wallet.spentThisMonth(now) + priceCents <= limitCents;
}
