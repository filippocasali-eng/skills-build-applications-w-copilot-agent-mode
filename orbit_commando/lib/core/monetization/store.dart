import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/math/det_random.dart';
import '../analytics/analytics.dart';
import '../meta/workshop.dart';
import '../profile/profile.dart';
import '../progress/progress.dart';
import '../settings/settings.dart';
import 'billing.dart';
import 'capsules.dart';
import 'catalog.dart';
import 'offers.dart';
import 'remote_config.dart';
import 'wallet.dart';

class StoreState {
  const StoreState({
    this.ready = false,
    this.available = false,
    this.pending,
    this.message = '',
    this.test = false,
  });

  final bool ready;
  final bool available;
  final String? pending;

  /// Last user-facing message key ('done', 'pending', 'limit', 'error').
  final String message;
  final bool test;

  StoreState copyWith({
    bool? ready,
    bool? available,
    String? pending,
    bool clearPending = false,
    String? message,
    bool? test,
  }) => StoreState(
    ready: ready ?? this.ready,
    available: available ?? this.available,
    pending: clearPending ? null : pending ?? this.pending,
    message: message ?? this.message,
    test: test ?? this.test,
  );
}

/// Why a capsule can't be opened with gems.
enum CapsuleBlock { none, minor, country, notEnoughGems }

final billingProvider = Provider<BillingService>((ref) {
  if (kTestStore) return TestBillingService();
  return PlayBillingService();
});

final validatorProvider = Provider<PurchaseValidator>(
  (ref) => const LocalReceiptValidator(),
);

final dropTableProvider = FutureProvider<DropTable>(
  (ref) async =>
      DropTable.parse(await rootBundle.loadString('assets/data/capsules.json')),
);

/// Orchestrates purchases, grants, gems spending and capsules.
class StoreController extends Notifier<StoreState> {
  StreamSubscription<PurchaseOutcome>? _sub;

  @override
  StoreState build() {
    ref.onDispose(() => _sub?.cancel());
    return const StoreState();
  }

  BillingService get _billing => ref.read(billingProvider);
  WalletController get _wallet => ref.read(walletProvider.notifier);

  Future<void> init() async {
    if (state.ready) return;
    final ok = await _billing.init();
    _sub ??= _billing.outcomes.listen(_onOutcome);
    final w = ref.read(walletProvider);
    if (w.firstLaunch.isEmpty) {
      await _wallet.set((x) => x.copyWith(firstLaunch: dayKey(DateTime.now())));
    }
    state = state.copyWith(ready: true, available: ok, test: _billing.isTest);
  }

  String priceOf(String sku) {
    final p = _billing.products[sku];
    return p?.price ?? Catalog.money(Catalog.byId(sku).cents);
  }

  /// Starts a real-money purchase (spending limit first).
  Future<bool> buy(String sku) async {
    final settings = ref.read(settingsProvider);
    final cents = _billing.products[sku]?.priceCents ?? Catalog.byId(sku).cents;
    if (!SpendGuard.allowed(
      wallet: ref.read(walletProvider),
      limitCents: settings.monthlySpendLimitCents,
      priceCents: cents,
      now: DateTime.now(),
    )) {
      state = state.copyWith(message: 'limit');
      return false;
    }
    if (!_billing.available) {
      state = state.copyWith(message: 'unavailable');
      return false;
    }
    ref.read(analyticsProvider).log('store_purchase_start', {'sku': sku});
    state = state.copyWith(pending: sku, message: '');
    await _billing.buy(sku);
    return true;
  }

  Future<void> restore() => _billing.restore();

  Future<void> _onOutcome(PurchaseOutcome o) async {
    switch (o.state) {
      case PurchaseState.pending:
        state = state.copyWith(message: 'pending');
        await _wallet.set(
          (w) => w.copyWith(
            history: [
              ...w.history,
              PurchaseRecord(
                sku: o.sku,
                priceCents: o.priceCents,
                time: DateTime.now(),
                status: 'pending',
              ),
            ],
          ),
        );
      case PurchaseState.purchased || PurchaseState.restored:
        // Play can deliver the same purchase twice (app restart before
        // completion): never grant a token again.
        final seen =
            o.token.isNotEmpty &&
            ref.read(walletProvider).history.any((h) => h.token == o.token);
        final valid = !seen && await ref.read(validatorProvider).validate(o);
        if (seen) {
          state = state.copyWith(clearPending: true, message: 'done');
          return;
        }
        if (!valid) {
          state = state.copyWith(clearPending: true, message: 'error');
          return;
        }
        await _grantSku(
          o.sku,
          restored: o.state == PurchaseState.restored,
          cents: o.priceCents,
          token: o.token,
        );
        ref.read(analyticsProvider).log('purchase', {
          'sku': o.sku,
          'cents': o.priceCents,
        });
        state = state.copyWith(clearPending: true, message: 'done');
      case PurchaseState.cancelled:
        state = state.copyWith(clearPending: true, message: '');
      case PurchaseState.error:
        state = state.copyWith(clearPending: true, message: 'error');
    }
  }

  Future<void> _grantSku(
    String sku, {
    required bool restored,
    required int cents,
    String token = '',
  }) async {
    final s = Catalog.byId(sku);
    if (restored && s.kind == SkuKind.consumable) return;
    await _wallet.set((w) {
      final history = [
        // A pending entry for this SKU becomes the completed one.
        ...w.history.where((h) => !(h.sku == sku && h.status == 'pending')),
        if (!restored)
          PurchaseRecord(
            sku: sku,
            priceCents: cents,
            time: DateTime.now(),
            token: token,
          ),
      ];
      var next = w.copyWith(history: history);
      if (sku == Catalog.fullCartridge) {
        next = next.copyWith(fullCartridge: true);
      }
      if (sku == Catalog.seasonPass) next = next.copyWith(passPremium: true);
      if (s.kind == SkuKind.nonConsumable) {
        next = next.copyWith(owned: {...next.owned, sku});
      }
      if (s.gems > 0 && !(restored && w.owned.contains(sku))) {
        next = next.copyWith(gems: next.gems + s.gems);
      }
      final contents = Catalog.packContents[sku];
      if (contents != null) {
        next = next.copyWith(
          owned: {
            ...next.owned,
            ...contents.where(
              (c) =>
                  c.startsWith('skin_') ||
                  c.startsWith('crt_') ||
                  c.startsWith('track_'),
            ),
          },
        );
        if (sku == Catalog.starterPack) {
          final inv = {...next.inventory};
          inv['capsule'] = (inv['capsule'] ?? 0) + 3;
          next = next.copyWith(inventory: inv);
        }
      }
      return next;
    });
  }

  // ----------------------------------------------------------------- gems --

  Future<bool> spendGems(int amount) async {
    final w = ref.read(walletProvider);
    if (w.gems < amount) return false;
    await _wallet.set((x) => x.copyWith(gems: x.gems - amount));
    return true;
  }

  /// Buys a Workshop level with gems (pay-to-win, brief §8.7).
  Future<bool> buyUpgradeWithGems(String id) async {
    final p = ref.read(progressProvider);
    final u = Workshop.byId(id);
    final lv = p.upgrades[id] ?? 0;
    if (lv >= u.maxLevel) return false;
    if (!await spendGems(u.gemCosts[lv])) return false;
    await ref
        .read(progressProvider.notifier)
        .set((x) => x.copyWith(upgrades: {...x.upgrades, id: lv + 1}));
    return true;
  }

  // ------------------------------------------------------------- capsules --

  CapsuleBlock paidCapsuleBlock({required int price}) {
    final now = DateTime.now();
    if (!ref.read(profileProvider).isAdult(now)) return CapsuleBlock.minor;
    final rc = ref.read(remoteConfigProvider).value;
    if (rc != null &&
        rc.paidLootboxBlockedCountries.contains(deviceCountry())) {
      return CapsuleBlock.country;
    }
    if (ref.read(walletProvider).gems < price) {
      return CapsuleBlock.notEnoughGems;
    }
    return CapsuleBlock.none;
  }

  bool get freeCapsuleAvailable =>
      ref.read(walletProvider).freeCapsuleDay != dayKey(DateTime.now()) ||
      (ref.read(walletProvider).inventory['capsule'] ?? 0) > 0;

  /// Opens a capsule. [paid] spends gems (age/country gated); otherwise
  /// uses a stored capsule or today's free one.
  Future<CapsuleResult?> openCapsule({required bool paid}) async {
    final table = await ref.read(dropTableProvider.future);
    final rc = await ref.read(remoteConfigProvider.future);
    final w = ref.read(walletProvider);
    if (paid) {
      final price = rc.gemPrice('capsule');
      if (paidCapsuleBlock(price: price) != CapsuleBlock.none) return null;
      await spendGems(price);
    } else {
      final stored = w.inventory['capsule'] ?? 0;
      if (stored > 0) {
        await _wallet.set(
          (x) => x.copyWith(inventory: {...x.inventory, 'capsule': stored - 1}),
        );
      } else if (w.freeCapsuleDay != dayKey(DateTime.now())) {
        await _wallet.set(
          (x) => x.copyWith(freeCapsuleDay: dayKey(DateTime.now())),
        );
      } else {
        return null;
      }
    }
    final rng = DetRandom(DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    final result = CapsuleEngine(table)
        .open(rng, ref.read(walletProvider).capsulePity);
    await _wallet.set((x) => x.copyWith(capsulePity: result.pityAfter));
    await grant(
      result.item.kind,
      result.item.id,
      result.item.amount,
      upgrade: result.item.upgrade,
    );
    ref.read(analyticsProvider).log('capsule_open', {
      'paid': paid,
      'rarity': result.rarity,
    });
    return result;
  }

  /// Applies any reward (capsules, login, pass, daily shop).
  Future<void> grant(
    String kind,
    String id,
    int amount, {
    String? upgrade,
  }) async {
    final progress = ref.read(progressProvider.notifier);
    switch (kind) {
      case 'tokens':
        await progress.addTokens(amount);
      case 'credits':
        await progress.addCredits(amount);
      case 'gems':
        await _wallet.set((x) => x.copyWith(gems: x.gems + amount));
      case 'capsule':
        await _wallet.set(
          (x) => x.copyWith(
            inventory: {
              ...x.inventory,
              'capsule': (x.inventory['capsule'] ?? 0) + amount,
            },
          ),
        );
      case 'fragment':
        // 10 fragments = one Workshop level.
        final key = 'frag_$upgrade';
        final have = (ref.read(walletProvider).inventory[key] ?? 0) + amount;
        final levels = have ~/ 10;
        await _wallet.set(
          (x) => x.copyWith(inventory: {...x.inventory, key: have % 10}),
        );
        if (levels > 0 && upgrade != null) {
          final u = Workshop.byId(upgrade);
          await progress.set((p) {
            final lv = ((p.upgrades[upgrade] ?? 0) + levels).clamp(
              0,
              u.maxLevel,
            );
            return p.copyWith(upgrades: {...p.upgrades, upgrade: lv});
          });
        }
      default:
        // skins, crt filters, weapons, collectibles: owned forever.
        await _wallet.set((x) => x.copyWith(owned: {...x.owned, id}));
    }
  }

  // -------------------------------------------------- daily / pass / login --

  Future<bool> buyDailySlot(Map<String, dynamic> slot) async {
    final key = '${dayKey(DateTime.now())}:${slot['id']}';
    if (ref.read(walletProvider).dailyBought.contains(key)) return false;
    final price = (slot['gems'] as num?)?.toInt() ?? 0;
    if (price > 0 && !await spendGems(price)) return false;
    await _wallet.set((x) => x.copyWith(dailyBought: {...x.dailyBought, key}));
    await grant(
      slot['kind'] as String,
      slot['id'] as String,
      (slot['amount'] as num?)?.toInt() ?? 1,
      upgrade: slot['upgrade'] as String?,
    );
    return true;
  }

  Future<Map<String, Object>?> claimDailyLogin() async {
    final now = DateTime.now();
    final w = ref.read(walletProvider);
    if (!DailyLogin.canClaim(w, now)) return null;
    final day = DailyLogin.nextDay(w, now);
    final r = DailyLogin.rewards[day];
    await _wallet.set(
      (x) => x.copyWith(loginDay: day, lastLoginDate: dayKey(now)),
    );
    await grant(
      r['kind']! as String,
      r['kind']! as String,
      r['amount']! as int,
    );
    return r;
  }

  Future<void> addPassXp(int xp) =>
      _wallet.set((x) => x.copyWith(passXp: x.passXp + xp));

  Future<bool> claimPassTier(
    Season s,
    int tier, {
    required bool premium,
  }) async {
    final w = ref.read(walletProvider);
    final key =
        '${s.id}:${s.index(DateTime.now())}:$tier:${premium ? 'p' : 'f'}';
    if (w.passClaimed.contains(key) || s.tier(w.passXp) < tier) return false;
    if (premium && !w.passPremium) return false;
    final r = Season.reward(tier, premium: premium);
    await _wallet.set((x) => x.copyWith(passClaimed: {...x.passClaimed, key}));
    await grant(
      r['kind']! as String,
      (r['id'] ?? r['kind'])! as String,
      (r['amount'] as int?) ?? 1,
    );
    return true;
  }

  bool starterPackAvailable(RemoteConfig rc) {
    final w = ref.read(walletProvider);
    if (w.owned.contains(Catalog.starterPack) || w.firstLaunch.isEmpty) {
      return false;
    }
    final first = DateTime.parse('${w.firstLaunch}T00:00:00Z');
    return DateTime.now().toUtc().difference(first).inDays <
        rc.intValue('starter_pack_days', 3);
  }
}

final storeProvider = NotifierProvider<StoreController, StoreState>(
  StoreController.new,
);
