import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/monetization/offers.dart';
import 'package:orbit_commando/core/monetization/remote_config.dart';
import 'package:orbit_commando/core/monetization/wallet.dart';

void main() {
  final rc = RemoteConfig.parse(
    File('assets/data/remote_defaults.json').readAsStringSync(),
  );

  test(
    'daily shop: 4 distinct slots, same all day, refresh at UTC midnight',
    () {
      final morning = DateTime.utc(2026, 10, 25, 1);
      final evening = DateTime.utc(2026, 10, 25, 23, 59);
      final a = DailyShop.slots(rc, morning).map((s) => s['id']).toList();
      final b = DailyShop.slots(rc, evening).map((s) => s['id']).toList();
      expect(a, hasLength(4));
      expect(a.toSet(), hasLength(4));
      expect(a, b);
      expect(DailyShop.refreshAt(evening), DateTime.utc(2026, 10, 26));
      final days = {
        for (var d = 0; d < 7; d++)
          DailyShop.slots(
            rc,
            morning.add(Duration(days: d)),
          ).map((s) => s['id']).join(),
      };
      expect(days.length, greaterThan(3), reason: 'rotates');
    },
  );

  test('countdown text is the real remaining time', () {
    expect(
      formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 9)),
      '2:05:09',
    );
    expect(formatCountdown(const Duration(days: 3, hours: 4)), '3d 4h');
  });

  test('flash offers expire after their configured hours', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final o = FlashOffers.forTrigger(rc, 'boss_fail_3', now)!;
    expect(o.expires, now.add(const Duration(hours: 4)));
    expect(o.active(now.add(const Duration(hours: 3, minutes: 59))), isTrue);
    expect(o.active(now.add(const Duration(hours: 4))), isFalse);
  });

  test('daily login: consecutive days advance, a missed day resets', () {
    final d1 = DateTime(2026, 3, 1, 10);
    var w = const Wallet();
    expect(DailyLogin.nextDay(w, d1), 0);
    w = w.copyWith(loginDay: 0, lastLoginDate: dayKey(d1));
    expect(DailyLogin.canClaim(w, d1), isFalse);
    final d2 = d1.add(const Duration(days: 1));
    expect(DailyLogin.nextDay(w, d2), 1);
    final d4 = d1.add(const Duration(days: 3));
    expect(DailyLogin.nextDay(w, d4), 0);
  });

  test('season pass: tiers from XP, real end date', () {
    final s = Season.from(rc);
    expect(s.tier(0), 0);
    expect(s.tier(s.xpPerTier * 3 + 1), 3);
    expect(s.tier(1 << 30), s.tiers);
    final now = s.start.add(const Duration(days: 45));
    expect(s.endsAt(now), s.start.add(Duration(days: s.days * 2)));
  });

  test('monthly spending limit blocks purchases over the cap', () {
    final now = DateTime(2026, 5, 20);
    final w = Wallet(
      history: [
        PurchaseRecord(
          sku: 'gems_550',
          priceCents: 499,
          time: DateTime(2026, 5, 2),
        ),
        PurchaseRecord(
          sku: 'gems_550',
          priceCents: 499,
          time: DateTime(2026, 4, 30),
        ),
        PurchaseRecord(
          sku: 'gems_100',
          priceCents: 99,
          time: DateTime(2026, 5, 3),
          status: 'pending',
        ),
      ],
    );
    expect(w.spentThisMonth(now), 499);
    expect(
      SpendGuard.allowed(
        wallet: w,
        limitCents: 1000,
        priceCents: 499,
        now: now,
      ),
      isTrue,
    );
    expect(
      SpendGuard.allowed(
        wallet: w,
        limitCents: 1000,
        priceCents: 999,
        now: now,
      ),
      isFalse,
    );
    expect(
      SpendGuard.allowed(
        wallet: w,
        limitCents: null,
        priceCents: 99999,
        now: now,
      ),
      isTrue,
    );
  });

  test('Belgium is blocked for paid capsules by default', () {
    expect(rc.paidLootboxBlockedCountries, contains('BE'));
    expect(rc.gemsToCents(550), closeTo(500, 10));
  });
}
