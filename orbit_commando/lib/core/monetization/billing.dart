import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'catalog.dart';

enum PurchaseState { purchased, pending, cancelled, error, restored }

class PurchaseOutcome {
  const PurchaseOutcome(
    this.sku,
    this.state, {
    this.token = '',
    this.priceCents = 0,
    this.message = '',
  });

  final String sku;
  final PurchaseState state;

  /// Store purchase token (sent to the server validator).
  final String token;
  final int priceCents;
  final String message;
}

class StoreProduct {
  const StoreProduct(this.sku, this.title, this.price, this.priceCents);

  final String sku;
  final String title;

  /// Localised price string from the store.
  final String price;
  final int priceCents;
}

abstract interface class BillingService {
  Future<bool> init();
  bool get available;
  Map<String, StoreProduct> get products;
  Stream<PurchaseOutcome> get outcomes;
  Future<void> buy(String sku);
  Future<void> restore();
  bool get isTest;
}

/// Validates a purchase before anything is granted.
abstract interface class PurchaseValidator {
  Future<bool> validate(PurchaseOutcome p);
}

/// v1: local checks (non-empty token, known SKU). Server-side validation
/// with the Google Play Developer API is the v2 path (see
/// MONETIZATION.md and backend/functions).
class LocalReceiptValidator implements PurchaseValidator {
  const LocalReceiptValidator();

  @override
  Future<bool> validate(PurchaseOutcome p) async =>
      Catalog.skus.any((s) => s.id == p.sku) &&
      (p.token.isNotEmpty || p.state == PurchaseState.restored);
}

/// Google Play Billing through in_app_purchase.
class PlayBillingService implements BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _out = StreamController<PurchaseOutcome>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, StoreProduct> _products = {};
  final Map<String, ProductDetails> _details = {};
  bool _available = false;

  @override
  bool get isTest => false;

  @override
  bool get available => _available;

  @override
  Map<String, StoreProduct> get products => _products;

  @override
  Stream<PurchaseOutcome> get outcomes => _out.stream;

  @override
  Future<bool> init() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) return false;
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          _out.add(PurchaseOutcome('', PurchaseState.error, message: '$e'));
        },
      );
      final res = await _iap.queryProductDetails({
        for (final s in Catalog.skus) s.id,
      });
      for (final d in res.productDetails) {
        _details[d.id] = d;
        _products[d.id] = StoreProduct(
          d.id,
          d.title,
          d.price,
          (d.rawPrice * 100).round(),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Billing init failed: $e');
      _available = false;
      return false;
    }
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      final cents =
          _products[p.productID]?.priceCents ?? Catalog.byId(p.productID).cents;
      switch (p.status) {
        case PurchaseStatus.pending:
          _out.add(
            PurchaseOutcome(
              p.productID,
              PurchaseState.pending,
              priceCents: cents,
            ),
          );
        case PurchaseStatus.purchased:
          _out.add(
            PurchaseOutcome(
              p.productID,
              PurchaseState.purchased,
              token: p.verificationData.serverVerificationData,
              priceCents: cents,
            ),
          );
        case PurchaseStatus.restored:
          _out.add(
            PurchaseOutcome(
              p.productID,
              PurchaseState.restored,
              token: p.verificationData.serverVerificationData,
            ),
          );
        case PurchaseStatus.error:
          _out.add(
            PurchaseOutcome(
              p.productID,
              PurchaseState.error,
              message: p.error?.message ?? '',
            ),
          );
        case PurchaseStatus.canceled:
          _out.add(PurchaseOutcome(p.productID, PurchaseState.cancelled));
      }
      if (p.pendingCompletePurchase) _iap.completePurchase(p);
    }
  }

  @override
  Future<void> buy(String sku) async {
    final d = _details[sku];
    if (d == null) {
      _out.add(
        PurchaseOutcome(sku, PurchaseState.error, message: 'unknown product'),
      );
      return;
    }
    final param = PurchaseParam(productDetails: d);
    if (Catalog.byId(sku).kind == SkuKind.consumable) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  void dispose() => _sub?.cancel();
}

/// TEST store (`--dart-define=TEST_STORE=true`): every purchase succeeds
/// instantly with a fake token, so the whole flow can be tried on a phone
/// without a Play Console listing. Never used in the production bundle.
class TestBillingService implements BillingService {
  final _out = StreamController<PurchaseOutcome>.broadcast();
  int _n = 0;

  @override
  bool get isTest => true;

  @override
  bool get available => true;

  @override
  Map<String, StoreProduct> get products => {
    for (final s in Catalog.skus)
      s.id: StoreProduct(
        s.id,
        s.titleEn,
        '${Catalog.money(s.cents)} TEST',
        s.cents,
      ),
  };

  @override
  Stream<PurchaseOutcome> get outcomes => _out.stream;

  @override
  Future<bool> init() async => true;

  @override
  Future<void> buy(String sku) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _out.add(
      PurchaseOutcome(
        sku,
        PurchaseState.purchased,
        token: 'test-token-${_n++}',
        priceCents: Catalog.byId(sku).cents,
      ),
    );
  }

  @override
  Future<void> restore() async {}
}

class UnavailableBilling implements BillingService {
  @override
  bool get isTest => false;
  @override
  bool get available => false;
  @override
  Map<String, StoreProduct> get products => const {};
  @override
  Stream<PurchaseOutcome> get outcomes => const Stream.empty();
  @override
  Future<bool> init() async => false;
  @override
  Future<void> buy(String sku) async {}
  @override
  Future<void> restore() async {}
}
