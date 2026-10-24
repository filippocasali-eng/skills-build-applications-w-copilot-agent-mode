import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/cosmetics.dart';
import '../../core/profile_controller.dart';
import '../../core/providers.dart';
import '../../core/services/billing.dart';
import '../../core/widgets/common.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import '../collection/cosmetic_swatch.dart';
import '../parental_gate/parental_gate.dart';

/// Shop (opened behind the parental gate). Every pack shows its full
/// content before buying, prices are the real store prices, and items are
/// cosmetic only.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final billing = ref.watch(billingProvider);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    return MixoPage(
      title: l.shop,
      child: ValueListenableBuilder<BillingStatus>(
        valueListenable: billing.status,
        builder: (context, status, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MixoCard(
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded, color: MixoColors.sun),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.shopInfo,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              if (!p.parent.purchasesEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MixoCard(
                    color: Colors.black45,
                    child: Text(
                      l.purchasesDisabled,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (!billing.available)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MixoCard(
                    color: Colors.black45,
                    child: Text(
                      l.storeUnavailable,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_statusText(l, status) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _statusText(l, status)!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MixoColors.sun, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 12),
              for (final id in Products.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProductCard(
                    productId: id,
                    title: content.product(id),
                    owned: p.owned.contains(id),
                    price: billing.products
                        .where((x) => x.id == id)
                        .firstOrNull
                        ?.price,
                    enabled: p.parent.purchasesEnabled && billing.available,
                    onBuy: () async {
                      if (await showParentalGate(context)) {
                        await billing.buy(id);
                      }
                    },
                  ),
                ),
              OutlinedButton.icon(
                key: const Key('restore-purchases'),
                onPressed: () async {
                  if (await showParentalGate(context)) await billing.restore();
                },
                icon: const Icon(Icons.restore_rounded),
                label: Text(l.restorePurchases),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _statusText(AppLocalizations l, BillingStatus s) => switch (s) {
    BillingStatus.pending => l.purchasePending,
    BillingStatus.purchased => l.purchaseDone,
    BillingStatus.restored => l.purchasesRestored,
    BillingStatus.error => l.purchaseError,
    BillingStatus.cancelled => l.purchaseCancelled,
    BillingStatus.loading => l.loading,
    _ => null,
  };
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.productId,
    required this.title,
    required this.owned,
    required this.price,
    required this.enabled,
    required this.onBuy,
  });

  final String productId;
  final String title;
  final bool owned;
  final String? price;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final items = Catalog.ofProduct(productId).toList();
    return MixoCard(
      color: productId == Products.supporter ? const Color(0x55FFC107) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(l.packContains, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: 92,
                  child: Column(
                    children: [
                      SizedBox(height: 80, child: CosmeticSwatch(item: item)),
                      Text(
                        content.item(item.id),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: owned
                ? FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.owned),
                  )
                : FilledButton(
                    key: Key('buy-$productId'),
                    onPressed: enabled && price != null ? onBuy : null,
                    child: Text(
                      price == null ? l.priceUnavailable : l.buyFor(price!),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
