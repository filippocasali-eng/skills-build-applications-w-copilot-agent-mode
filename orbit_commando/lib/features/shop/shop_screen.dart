import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/audio/audio.dart';
import '../../core/monetization/capsules.dart';
import '../../core/monetization/catalog.dart';
import '../../core/monetization/offers.dart';
import '../../core/monetization/remote_config.dart';
import '../../core/monetization/store.dart';
import '../../core/monetization/wallet.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

enum _Tab { cartridge, gems, capsules, daily, pass, login, history }

/// The shop. Prices always visible, euro equivalents next to gem prices,
/// exact capsule odds one tap away, timers that match real expiries.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  _Tab _tab = _Tab.cartridge;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    ref.read(storeProvider.notifier).init();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _tabName(AppLocalizations l, _Tab t) => switch (t) {
    _Tab.cartridge => l.shopCartridge,
    _Tab.gems => l.gems,
    _Tab.capsules => l.capsules,
    _Tab.daily => l.dailyShop,
    _Tab.pass => l.seasonPass,
    _Tab.login => l.dailyLogin,
    _Tab.history => l.purchaseHistory,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = ref.watch(storeProvider);
    final wallet = ref.watch(walletProvider);
    final rc = ref.watch(remoteConfigProvider).value;
    return PixelScreen(
      title: l.menuShop,
      trailing: Row(
        children: [
          if (store.test)
            const PixelText('TEST STORE', scale: 0.7, color: Pal.ember5),
          const SizedBox(width: 10),
          PixelText('${l.gems} ${wallet.gems}', color: Pal.neon6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: ListView(
                children: [
                  for (final t in _Tab.values) ...[
                    PixelButton(
                      label: _tabName(l, t),
                      scale: 0.8,
                      width: double.infinity,
                      color: t == _tab ? Pal.gold7 : Pal.ink6,
                      autofocus: t == _Tab.cartridge,
                      onPressed: () => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: rc == null
                  ? Center(child: PixelText(l.loading))
                  : SingleChildScrollView(
                      child: _content(l, rc, wallet, store),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Pal.ink1,
        content: PixelText(text, color: Pal.gold6),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _buy(String sku) async {
    final l = AppLocalizations.of(context);
    final ok = await ref.read(storeProvider.notifier).buy(sku);
    if (!ok) {
      final msg = ref.read(storeProvider).message;
      _snack(msg == 'limit' ? l.spendLimitReached : l.storeUnavailable);
    }
  }

  String _gemsLabel(AppLocalizations l, RemoteConfig rc, int gems) =>
      '${l.buyGems(gems)} (${l.gemsApprox(Catalog.euro(rc.gemsToCents(gems)))})';

  Widget _content(
    AppLocalizations l,
    RemoteConfig rc,
    Wallet w,
    StoreState st,
  ) {
    final lang = Localizations.localeOf(context).languageCode;
    final store = ref.read(storeProvider.notifier);
    final now = DateTime.now();
    if (st.pending != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: PixelText(l.purchasePending, color: Pal.aqua6),
      );
    }
    switch (_tab) {
      case _Tab.cartridge:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(l.shopCartridge, scale: 1.6, color: Pal.gold6),
                  PixelText(l.shopCartridgeDesc, scale: 0.8),
                  const SizedBox(height: 8),
                  w.fullCartridge
                      ? PixelText(l.owned, color: Pal.moss6)
                      : PixelButton(
                          label:
                              '${l.buy}  ${store.priceOf(Catalog.fullCartridge)}',
                          scale: 1.2,
                          onPressed: () => _buy(Catalog.fullCartridge),
                        ),
                ],
              ),
            ),
            if (store.starterPackAvailable(rc)) ...[
              const SizedBox(height: 10),
              _packTile(
                l,
                lang,
                Catalog.starterPack,
                w,
                highlight: true,
                endsIn: DateTime.parse('${w.firstLaunch}T00:00:00Z')
                    .add(Duration(days: rc.intValue('starter_pack_days', 3))),
              ),
            ],
            for (final sku in const [
              'pack_retro_suits',
              'pack_crt_deluxe',
              'pack_mixtape_vol1',
            ]) ...[const SizedBox(height: 10), _packTile(l, lang, sku, w)],
            const SizedBox(height: 10),
            PixelButton(
              label: l.restorePurchases,
              scale: 0.8,
              onPressed: store.restore,
            ),
          ],
        );
      case _Tab.gems:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in Catalog.skus.where((s) => s.id.startsWith('gems_')))
              PixelPanel(
                child: SizedBox(
                  width: 170,
                  child: Column(
                    children: [
                      PixelText('${s.gems}', scale: 2, color: Pal.neon6),
                      PixelText(l.gems, scale: 0.7),
                      const SizedBox(height: 6),
                      PixelButton(
                        label: store.priceOf(s.id),
                        onPressed: () => _buy(s.id),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case _Tab.capsules:
        return _CapsulesTab(rc: rc);
      case _Tab.daily:
        final slots = DailyShop.slots(rc, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelText(
              l.refreshesIn(
                formatCountdown(
                  DailyShop.refreshAt(now).difference(now.toUtc()),
                ),
              ),
              color: Pal.aqua6,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in slots)
                  PixelPanel(
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          PixelText(
                            _itemName(s),
                            color: Pal.gold6,
                            align: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          w.dailyBought.contains('${dayKey(now)}:${s['id']}')
                              ? PixelText(l.owned, color: Pal.moss6)
                              : PixelButton(
                                  label: (s['gems'] as num) == 0
                                      ? l.claim
                                      : _gemsLabel(
                                          l,
                                          rc,
                                          (s['gems'] as num).toInt(),
                                        ),
                                  scale: 0.7,
                                  onPressed: () async {
                                    final ok = await store.buyDailySlot(s);
                                    if (!ok) _snack(l.notEnough);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            PixelText(l.weeklyEvent, scale: 1.1, color: Pal.ember6),
            for (final e in rc.list('events'))
              PixelText(
                '${e['id']}: ${(e['goal'] as Map<String, dynamic>)['amount']} ${(e['goal'] as Map<String, dynamic>)['stat']}  ->  ${(e['reward'] as Map<String, dynamic>).values.first}',
                scale: 0.8,
              ),
          ],
        );
      case _Tab.pass:
        final season = Season.from(rc);
        final tier = season.tier(w.passXp);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelText(
              l.seasonEndsIn(
                formatCountdown(season.endsAt(now).difference(now.toUtc())),
              ),
              color: Pal.aqua6,
            ),
            PixelText(
              'Tier $tier/${season.tiers}  (${w.passXp} XP)',
              color: Pal.gold6,
            ),
            const SizedBox(height: 6),
            if (!w.passPremium)
              PixelButton(
                label: '${l.premiumTrack}: ${store.priceOf(season.sku)}',
                onPressed: () => _buy(season.sku),
              ),
            const SizedBox(height: 6),
            for (var t = 1; t <= season.tiers; t++)
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: PixelText(
                      '$t',
                      color: t <= tier ? Pal.gold6 : Pal.ink4,
                    ),
                  ),
                  Expanded(
                    child: _passCell(l, season, t, tier, premium: false, w: w),
                  ),
                  Expanded(
                    child: _passCell(l, season, t, tier, premium: true, w: w),
                  ),
                ],
              ),
          ],
        );
      case _Tab.login:
        final can = DailyLogin.canClaim(w, now);
        final next = DailyLogin.nextDay(w, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 0; d < 7; d++)
                  PixelPanel(
                    border: d == next && can ? Pal.gold6 : Pal.space4,
                    child: SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          PixelText(l.dayN(d + 1), color: Pal.ink6),
                          PixelText(
                            '${DailyLogin.rewards[d]['amount']} ${DailyLogin.rewards[d]['kind']}',
                            scale: 0.8,
                            color: Pal.gold6,
                            align: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            can
                ? PixelButton(
                    label: l.claim,
                    scale: 1.3,
                    onPressed: () async {
                      await store.claimDailyLogin();
                      ref.read(audioProvider).sfx(Sfx.coin);
                    },
                  )
                : PixelText(
                    '${l.claimed}. ${l.refreshesIn(formatCountdown(nextUtcMidnight(now).difference(now.toUtc())))}',
                    color: Pal.moss6,
                  ),
          ],
        );
      case _Tab.history:
        if (w.history.isEmpty) return PixelText(l.noPurchases);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelText(
              '${l.total}: ${Catalog.euro(w.spentThisMonth(now))} / ${now.month}-${now.year}',
              color: Pal.gold6,
            ),
            for (final h in w.history.reversed)
              PixelText(
                '${h.time.toLocal().toString().substring(0, 16)}  ${Catalog.byId(h.sku).title(lang)}  ${Catalog.euro(h.priceCents)}  ${h.status}',
                scale: 0.7,
              ),
          ],
        );
    }
  }

  Widget _packTile(
    AppLocalizations l,
    String lang,
    String sku,
    Wallet w, {
    bool highlight = false,
    DateTime? endsIn,
  }) {
    final store = ref.read(storeProvider.notifier);
    final owned = w.owned.contains(sku);
    return PixelPanel(
      border: highlight ? Pal.gold6 : Pal.space4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(
            Catalog.byId(sku).title(lang),
            scale: 1.2,
            color: highlight ? Pal.gold7 : Pal.gold6,
          ),
          // Contents always shown before buying.
          PixelText(
            (Catalog.packContents[sku] ?? const []).join(', '),
            scale: 0.7,
            color: Pal.ink6,
          ),
          if (endsIn != null)
            PixelText(
              l.endsIn(
                formatCountdown(endsIn.difference(DateTime.now().toUtc())),
              ),
              scale: 0.8,
              color: Pal.ember6,
            ),
          const SizedBox(height: 6),
          owned
              ? PixelText(l.owned, color: Pal.moss6)
              : PixelButton(
                  label: '${l.buy}  ${store.priceOf(sku)}',
                  onPressed: () => _buy(sku),
                ),
        ],
      ),
    );
  }

  Widget _passCell(
    AppLocalizations l,
    Season s,
    int t,
    int tier, {
    required bool premium,
    required Wallet w,
  }) {
    final r = Season.reward(t, premium: premium);
    final key = '${s.id}:${s.index(DateTime.now())}:$t:${premium ? 'p' : 'f'}';
    final claimed = w.passClaimed.contains(key);
    final can = t <= tier && !claimed && (!premium || w.passPremium);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: can
          ? PixelButton(
              label: '${r['amount'] ?? ''} ${r['kind']}',
              scale: 0.6,
              onPressed: () => ref
                  .read(storeProvider.notifier)
                  .claimPassTier(s, t, premium: premium),
            )
          : PixelText(
              '${claimed ? '* ' : ''}${r['amount'] ?? ''} ${r['kind']}',
              scale: 0.6,
              color: premium ? Pal.neon4 : Pal.ink5,
            ),
    );
  }

  static String _itemName(Map<String, dynamic> s) {
    final amount = s['amount'];
    return '${amount ?? ''} ${(s['id'] as String).replaceAll('_', ' ')}'
        .trim()
        .toUpperCase();
  }
}

/// Capsules: free daily, paid (age/country gated), odds and pity counter.
class _CapsulesTab extends ConsumerStatefulWidget {
  const _CapsulesTab({required this.rc});

  final RemoteConfig rc;

  @override
  ConsumerState<_CapsulesTab> createState() => _CapsulesTabState();
}

class _CapsulesTabState extends ConsumerState<_CapsulesTab>
    with SingleTickerProviderStateMixin {
  CapsuleResult? _last;
  bool _showOdds = false;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _open(bool paid) async {
    final r = await ref.read(storeProvider.notifier).openCapsule(paid: paid);
    if (r == null) return;
    ref.read(audioProvider).sfx(Sfx.cassette);
    setState(() => _last = null);
    await _spin.forward(from: 0);
    ref.read(audioProvider).sfx(r.rarity == 'legendary' ? Sfx.yeah : Sfx.coin);
    if (mounted) setState(() => _last = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = ref.watch(walletProvider);
    final table = ref.watch(dropTableProvider).value;
    final store = ref.read(storeProvider.notifier);
    final price = widget.rc.gemPrice('capsule');
    final block = store.paidCapsuleBlock(price: price);
    if (table == null) return PixelText(l.loading);
    final rarityName = {
      'common': l.rarityCommon,
      'rare': l.rarityRare,
      'epic': l.rarityEpic,
      'legendary': l.rarityLegendary,
    };
    final rarityColor = {
      'common': Pal.ink6,
      'rare': Pal.aqua6,
      'epic': Pal.neon6,
      'legendary': Pal.gold7,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The capsule (skippable spin).
            GestureDetector(
              onTap: () => _spin.value = 1,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, _) => Transform.rotate(
                  angle: _spin.value * 12.56,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Pal.ink0, width: 4),
                      gradient: const LinearGradient(
                        colors: [Pal.ember5, Pal.ember5, Pal.ink7, Pal.ink7],
                        stops: [0, 0.5, 0.5, 1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(
                    l.pityCounter(table.pity - w.capsulePity),
                    color: Pal.gold6,
                  ),
                  PixelText('x${w.inventory['capsule'] ?? 0}', color: Pal.ink6),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.capsuleFree,
                    enabled: store.freeCapsuleAvailable,
                    onPressed: () => _open(false),
                  ),
                  const SizedBox(height: 6),
                  if (block == CapsuleBlock.minor)
                    PixelText(
                      l.paidCapsulesMinor,
                      scale: 0.8,
                      color: Pal.ember5,
                    )
                  else if (block == CapsuleBlock.country)
                    PixelText(
                      l.paidCapsulesBlocked,
                      scale: 0.8,
                      color: Pal.ember5,
                    )
                  else
                    PixelButton(
                      label:
                          '${l.capsuleOpen}: ${l.buyGems(price)} (${l.gemsApprox(Catalog.euro(widget.rc.gemsToCents(price)))})',
                      enabled: block == CapsuleBlock.none,
                      onPressed: () => _open(true),
                    ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.capsuleOdds,
                    color: Pal.aqua6,
                    onPressed: () => setState(() => _showOdds = !_showOdds),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_last != null) ...[
          const SizedBox(height: 10),
          PixelText(
            rarityName[_last!.rarity]!,
            scale: 2,
            color: rarityColor[_last!.rarity]!,
          ),
          PixelText(
            _last!.item.id.replaceAll('_', ' ').toUpperCase(),
            scale: 1.2,
          ),
        ],
        if (_showOdds) ...[
          const SizedBox(height: 10),
          PixelText(l.capsuleOddsTitle, scale: 1.2, color: Pal.aqua6),
          for (final r in table.rarities) ...[
            PixelText(
              '${rarityName[r.id]}: ${(table.rarityChance(r.id) * 100).toStringAsFixed(2)}%',
              color: rarityColor[r.id]!,
            ),
            for (final i in r.items)
              PixelText(
                '   ${i.id.replaceAll('_', ' ')}: ${(table.itemChance(r.id, i.id) * 100).toStringAsFixed(3)}%',
                scale: 0.7,
                color: Pal.ink6,
              ),
          ],
          PixelText(l.pityCounter(table.pity), scale: 0.8, color: Pal.gold6),
        ],
      ],
    );
  }
}
