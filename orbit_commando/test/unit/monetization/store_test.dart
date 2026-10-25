import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/monetization/billing.dart';
import 'package:orbit_commando/core/monetization/store.dart';
import 'package:orbit_commando/core/monetization/wallet.dart';
import 'package:orbit_commando/core/providers.dart';
import 'package:orbit_commando/core/storage/save_store.dart';

/// Billing that replays whatever the test pushes.
class ScriptedBilling implements BillingService {
  final out = StreamController<PurchaseOutcome>.broadcast();

  @override
  bool get isTest => true;
  @override
  bool get available => true;
  @override
  Map<String, StoreProduct> get products => const {};
  @override
  Stream<PurchaseOutcome> get outcomes => out.stream;
  @override
  Future<bool> init() async => true;
  @override
  Future<void> buy(String sku) async {}
  @override
  Future<void> restore() async {}
}

void main() {
  late ProviderContainer c;
  late ScriptedBilling billing;

  setUp(() async {
    billing = ScriptedBilling();
    c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(SaveStore.memory()),
        billingProvider.overrideWithValue(billing),
      ],
    );
    await c.read(storeProvider.notifier).init();
  });

  tearDown(() => c.dispose());

  Future<void> deliver(PurchaseOutcome o) async {
    billing.out.add(o);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('a purchase token is granted once, even if delivered twice', () async {
    const o = PurchaseOutcome(
      'gems_550',
      PurchaseState.purchased,
      token: 'tok-1',
      priceCents: 499,
    );
    await deliver(o);
    await deliver(o);
    final w = c.read(walletProvider);
    expect(w.gems, 550);
    expect(w.history.where((h) => h.status == 'ok'), hasLength(1));

    await deliver(
      const PurchaseOutcome(
        'gems_550',
        PurchaseState.purchased,
        token: 'tok-2',
        priceCents: 499,
      ),
    );
    expect(c.read(walletProvider).gems, 1100);
  });

  test('an unknown SKU or empty token grants nothing', () async {
    await deliver(
      const PurchaseOutcome('gems_100', PurchaseState.purchased, token: ''),
    );
    expect(c.read(walletProvider).gems, 0);
    expect(c.read(storeProvider).message, 'error');
  });

  test('the token survives a save round-trip', () {
    final r = PurchaseRecord(
      sku: 'gems_100',
      priceCents: 99,
      time: DateTime.utc(2026),
      token: 'abc',
    );
    expect(PurchaseRecord.fromJson(r.toJson()).token, 'abc');
  });
}
