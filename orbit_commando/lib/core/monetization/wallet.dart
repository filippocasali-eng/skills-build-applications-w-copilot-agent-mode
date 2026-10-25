import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// A completed (or pending) purchase, for the purchase history screen.
class PurchaseRecord {
  const PurchaseRecord({
    required this.sku,
    required this.priceCents,
    required this.time,
    this.status = 'ok',
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> j) => PurchaseRecord(
    sku: j['sku'] as String,
    priceCents: j['cents'] as int? ?? 0,
    time: DateTime.parse(j['t'] as String),
    status: j['status'] as String? ?? 'ok',
  );

  final String sku;
  final int priceCents;
  final DateTime time;

  /// ok | pending | refunded
  final String status;

  Map<String, Object> toJson() => {
    'sku': sku,
    'cents': priceCents,
    't': time.toUtc().toIso8601String(),
    'status': status,
  };
}

/// Entitlements and the local mirror of the premium wallet.
///
/// The authoritative gem balance lives on the server in production
/// (MONETIZATION.md); this local copy is a cache and works offline for
/// the free features and the test store.
class Wallet {
  const Wallet({
    this.fullCartridge = false,
    this.gems = 0,
    this.owned = const {},
    this.history = const [],
    this.capsulePity = 0,
    this.freeCapsuleDay = '',
    this.loginDay = 0,
    this.lastLoginDate = '',
    this.passXp = 0,
    this.passPremium = false,
    this.passClaimed = const {},
    this.dailyBought = const {},
    this.firstLaunch = '',
    this.inventory = const {},
  });

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
    fullCartridge: j['cartridge'] as bool? ?? false,
    gems: j['gems'] as int? ?? 0,
    owned: {
      for (final s in (j['owned'] as List<dynamic>? ?? const [])) s as String,
    },
    history: [
      for (final h in (j['history'] as List<dynamic>? ?? const []))
        PurchaseRecord.fromJson(h as Map<String, dynamic>),
    ],
    capsulePity: j['pity'] as int? ?? 0,
    freeCapsuleDay: j['freeCapsule'] as String? ?? '',
    loginDay: j['loginDay'] as int? ?? 0,
    lastLoginDate: j['lastLogin'] as String? ?? '',
    passXp: j['passXp'] as int? ?? 0,
    passPremium: j['passPremium'] as bool? ?? false,
    passClaimed: {
      for (final s in (j['passClaimed'] as List<dynamic>? ?? const []))
        s as String,
    },
    dailyBought: {
      for (final s in (j['dailyBought'] as List<dynamic>? ?? const []))
        s as String,
    },
    firstLaunch: j['firstLaunch'] as String? ?? '',
    inventory: {
      for (final e
          in (j['inventory'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as int,
    },
  );

  final bool fullCartridge;
  final int gems;

  /// Non-consumable SKUs and cosmetic ids owned.
  final Set<String> owned;
  final List<PurchaseRecord> history;

  /// Opens since the last Legendary (pity counter).
  final int capsulePity;

  /// yyyy-mm-dd of the last free capsule claimed.
  final String freeCapsuleDay;

  /// Daily login streak position (0..6) and last claim date.
  final int loginDay;
  final String lastLoginDate;
  final int passXp;
  final bool passPremium;
  final Set<String> passClaimed;

  /// `day:slot` entries bought from the daily shop.
  final Set<String> dailyBought;

  /// yyyy-mm-dd of first launch (starter pack window).
  final String firstLaunch;

  /// Capsule loot: upgrade fragments, legendary weapons, etc.
  final Map<String, int> inventory;

  Map<String, Object> toJson() => {
    'cartridge': fullCartridge,
    'gems': gems,
    'owned': owned.toList(),
    'history': [for (final h in history) h.toJson()],
    'pity': capsulePity,
    'freeCapsule': freeCapsuleDay,
    'loginDay': loginDay,
    'lastLogin': lastLoginDate,
    'passXp': passXp,
    'passPremium': passPremium,
    'passClaimed': passClaimed.toList(),
    'dailyBought': dailyBought.toList(),
    'firstLaunch': firstLaunch,
    'inventory': inventory,
  };

  Wallet copyWith({
    bool? fullCartridge,
    int? gems,
    Set<String>? owned,
    List<PurchaseRecord>? history,
    int? capsulePity,
    String? freeCapsuleDay,
    int? loginDay,
    String? lastLoginDate,
    int? passXp,
    bool? passPremium,
    Set<String>? passClaimed,
    Set<String>? dailyBought,
    String? firstLaunch,
    Map<String, int>? inventory,
  }) => Wallet(
    fullCartridge: fullCartridge ?? this.fullCartridge,
    gems: gems ?? this.gems,
    owned: owned ?? this.owned,
    history: history ?? this.history,
    capsulePity: capsulePity ?? this.capsulePity,
    freeCapsuleDay: freeCapsuleDay ?? this.freeCapsuleDay,
    loginDay: loginDay ?? this.loginDay,
    lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    passXp: passXp ?? this.passXp,
    passPremium: passPremium ?? this.passPremium,
    passClaimed: passClaimed ?? this.passClaimed,
    dailyBought: dailyBought ?? this.dailyBought,
    firstLaunch: firstLaunch ?? this.firstLaunch,
    inventory: inventory ?? this.inventory,
  );

  /// Money spent in the calendar month of [now] (euro cents).
  int spentThisMonth(DateTime now) => history
      .where(
        (h) =>
            h.status == 'ok' &&
            h.time.year == now.year &&
            h.time.month == now.month,
      )
      .fold(0, (s, h) => s + h.priceCents);
}

class WalletController extends Notifier<Wallet> {
  @override
  Wallet build() =>
      Wallet.fromJson(ref.watch(saveStoreProvider).section('wallet'));

  Future<void> set(Wallet Function(Wallet w) change) async {
    state = change(state);
    final store = ref.read(saveStoreProvider);
    store.section('wallet')
      ..clear()
      ..addAll(state.toJson());
    await store.flush();
  }
}

final walletProvider = NotifierProvider<WalletController, Wallet>(
  WalletController.new,
);

/// Compile-time switch for the TEST store build (fake purchases, everything
/// testable without Play Console). `--dart-define=TEST_STORE=true`.
const bool kTestStore = bool.fromEnvironment('TEST_STORE');
