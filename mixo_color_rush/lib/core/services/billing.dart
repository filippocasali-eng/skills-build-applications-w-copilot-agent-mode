import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/cosmetics.dart';

/// A store product with its real, localized price (never a virtual
/// currency).
class StoreProduct {
  const StoreProduct({required this.id, required this.price, this.details});

  final String id;

  /// Price formatted by Google Play in the user's currency.
  final String price;
  final ProductDetails? details;
}

enum BillingStatus {
  idle,
  unavailable,
  loading,
  pending,
  purchased,
  restored,
  cancelled,
  error,
}

/// Purchases of cosmetic, non-consumable products only.
abstract class BillingService {
  final ValueNotifier<BillingStatus> status = ValueNotifier(BillingStatus.idle);

  /// Called with a product id whenever it is purchased or restored.
  void Function(String productId)? onEntitled;

  bool get available;
  List<StoreProduct> get products;

  Future<void> init();
  Future<void> buy(String productId);
  Future<void> restore();
  void dispose() {}
}

/// Used on web previews and when Google Play is not reachable.
class UnavailableBillingService extends BillingService {
  @override
  bool get available => false;

  @override
  List<StoreProduct> get products => const [];

  @override
  Future<void> init() async => status.value = BillingStatus.unavailable;

  @override
  Future<void> buy(String productId) async =>
      status.value = BillingStatus.unavailable;

  @override
  Future<void> restore() async => status.value = BillingStatus.unavailable;
}

/// Google Play Billing through the `in_app_purchase` plugin.
///
/// Debug builds: install from Play internal testing with a license-tester
/// account (test cards, no real charge). Optionally
/// `--dart-define=MIXO_STATIC_TEST_SKU=true` queries Google's static test
/// product `android.test.purchased` for the supporter pack.
class PlayBillingService extends BillingService {
  static const bool _staticTestSku = bool.fromEnvironment(
    'MIXO_STATIC_TEST_SKU',
  );
  static const String _testSku = 'android.test.purchased';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  List<StoreProduct> _products = const [];

  @override
  bool get available => _available;

  @override
  List<StoreProduct> get products => _products;

  String _storeId(String productId) =>
      kDebugMode && _staticTestSku && productId == Products.supporter
      ? _testSku
      : productId;

  String _productId(String storeId) =>
      storeId == _testSku ? Products.supporter : storeId;

  @override
  Future<void> init() async {
    status.value = BillingStatus.loading;
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        status.value = BillingStatus.unavailable;
        return;
      }
      _sub ??= _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => status.value = BillingStatus.error,
      );
      final resp = await _iap.queryProductDetails({
        for (final p in Products.all) _storeId(p),
      });
      _products = [
        for (final d in resp.productDetails)
          StoreProduct(id: _productId(d.id), price: d.price, details: d),
      ];
      status.value = BillingStatus.idle;
    } catch (e) {
      debugPrint('Billing init failed: $e');
      _available = false;
      status.value = BillingStatus.unavailable;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          status.value = BillingStatus.pending;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Cosmetic-only, non-consumable: granted locally. No account and
          // no server, so no personal data is involved.
          onEntitled?.call(_productId(p.productID));
          status.value = p.status == PurchaseStatus.purchased
              ? BillingStatus.purchased
              : BillingStatus.restored;
        case PurchaseStatus.error:
          status.value = BillingStatus.error;
        case PurchaseStatus.canceled:
          status.value = BillingStatus.cancelled;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<void> buy(String productId) async {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (!_available || product?.details == null) {
      status.value = BillingStatus.unavailable;
      return;
    }
    status.value = BillingStatus.loading;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product!.details!),
    );
  }

  @override
  Future<void> restore() async {
    if (!_available) {
      status.value = BillingStatus.unavailable;
      return;
    }
    status.value = BillingStatus.loading;
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
  }
}
