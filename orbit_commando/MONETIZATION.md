# Monetization

Design goal: a fair premium-plus-cosmetics model that can pass Google Play
review and EU consumer rules. Ranked modes never sell power.

All prices, odds and offers are data:

| File | Contents |
|---|---|
| `lib/core/monetization/catalog.dart` | SKUs and euro reference prices |
| `assets/data/capsules.json` | drop table |
| `assets/data/remote_defaults.json` | gem prices, offers, season, blocked countries |

## 1. Products (Google Play SKUs)

| SKU | Type | Price (US base) | Contents |
|---|---|---|---|
| `full_cartridge` | non-consumable | $4.99 | Worlds 2–3, Boss Rush, infinite campaign continues, no ads |
| `gems_100` | consumable | $0.99 | 100 Quasar Gems |
| `gems_550` | consumable | $4.99 | 550 gems |
| `gems_1200` | consumable | $9.99 | 1200 gems |
| `gems_2600` | consumable | $19.99 | 2600 gems |
| `gems_7000` | consumable | $49.99 | 7000 gems |
| `season_pass_s1` | non-consumable | $9.99 | premium track of the 30-day season (cosmetics, soft currency) |
| `pack_retro_suits` | non-consumable | $2.99 | 4 skins (contents listed before purchase) |
| `pack_crt_deluxe` | non-consumable | $1.99 | green and amber CRT filters |
| `pack_mixtape_vol1` | non-consumable | $1.99 | 2 bonus music tracks |
| `starter_pack` | non-consumable | $1.99 | 300 gems, 3 capsules, Walkman skin; offered for 3 days after first launch |

Create these exact ids in Play Console → Monetize → Products. The prices
shown in-game are those returned by Play (localised); the catalog prices are
only a fallback.

## 2. Currencies

- **Tokens (soft):** earned by playing. They buy Workshop upgrades and
  items in the daily shop.
- **Quasar Gems (hard):** bought, or earned in small amounts from the
  season, login days and capsules. Every gem price shows its euro
  equivalent next to it ("≈ $0.55"; euros on eurozone devices), computed from the best-value pack
  (`gem_euro_cents_per_100`).

## 3. Cosmic Capsules (loot boxes)

| Rarity | Weight | Probability |
|---|---|---|
| Common | 7000 | 70.00 % |
| Rare | 2200 | 22.00 % |
| Epic | 650 | 6.50 % |
| Legendary | 150 | 1.50 % |

- **Pity:** a Legendary is guaranteed within 50 openings. The counter is
  visible and resets on any Legendary.
- **Odds screen:** reachable from the capsule page before buying. It lists
  every item, its rarity and the per-item probability.
- **Free path:** one free capsule a day. Capsules also come from the
  season and login calendar.
- **Contents:** cosmetics, soft currency, upgrade fragments (10 = one
  level, which can also be bought with tokens) and collectibles. No
  exclusive gameplay power.
- **Age gate:** paid capsules are disabled for players under 18. Free
  capsules stay available.
- **Country block:** paid capsules are blocked in Belgium (`BE`, from the
  remote list `lootbox_paid_blocked_countries`, using the device locale's
  country). Add countries there without a release.
- **Tests:** `test/unit/monetization/capsules_test.dart` draws 1,000,000
  capsules. It checks the observed rates against the table and checks
  that pity never exceeds 50.

## 4. Offers and live-ops

- **Daily shop:** 4 slots from `daily_shop_pool`, seeded by the UTC date.
  They refresh at UTC midnight with a visible real countdown.
- **Flash offers:** triggered by events such as 3 failures on a boss, a
  world clear, or 5 failures on a level. They last 2–6 hours with a real
  timer, and each trigger fires at most once.
- **Season Pass:**
  - 30 days and 30 tiers, with XP from playing.
  - The free track is always available.
  - The premium track is bought with `season_pass_s1`.
- **Daily login:** a 7-day calendar with free rewards only.
- **Cosmetic events:** weekly goals (for example "300 kills") reward
  exclusive skins. Exclusives return within 6 months
  (`exclusive_months`).

There are no fake timers, no "only 2 left" claims and no confirm-shaming.

## 5. Player protections

| Protection | Where |
|---|---|
| Monthly spending limit (off, $5, $10, $20, $50, $100) | Settings; checked before every purchase (`SpendGuard`) |
| Purchase history with date, item, price and status | Shop → History |
| Restore purchases | Shop → History |
| Paid capsules disabled under 18 | `StoreController.paidCapsuleBlock` |
| Chat restricted by age (see `PRIVACY.md`) | `ChatScreen` |
| Ads: no ads after a death, at most 1 interstitial every 3 cleared levels, rewarded ads only on opt-in | `InterstitialPolicy`, results screen |
| Ads by age (US/COPPA): under 13 child treatment, 13–17 or unknown teen treatment (no personalisation), content rating capped at T for everyone | `GoogleAdsProvider.init`, `treatmentFor` |
| Full Cartridge removes all ads | `main.dart` |
| Paid upgrades disabled in Arcade difficulty and ranked modes | `Workshop.loadoutFor`, `ranked_allow_paid_upgrades` |

## 6. Ads (AdMob)

- **Consent:** collected through Google UMP (`ConsentService`) before
  ads are initialised. "Privacy options" in Settings reopens the form.
- **Formats:** rewarded (double tokens on the results screen, extra
  continue) and interstitial (between levels, at most 1 every 3).
- **Unit ids:** Google's test ids are used by default.
- **Release setup:**
  1. Replace `admob_app_id` in
     `android/app/src/main/res/values/admob.xml` with the real App ID.
  2. Build with `--dart-define=ADMOB_REWARDED=ca-app-pub-…/…` and
     `--dart-define=ADMOB_INTERSTITIAL=ca-app-pub-…/…`.
  3. Complete the AdMob privacy & messaging (GDPR) form so UMP shows it.

## 7. Build flavours

| Build | Billing | Use |
|---|---|---|
| `flutter build apk --dart-define=TEST_STORE=true` | `TestBillingService`: every purchase succeeds instantly, prices tagged "TEST", "TEST STORE" banner | sideloaded APKs, QA, reviews |
| `flutter build appbundle` | `PlayBillingService` (`in_app_purchase`) | Play Store |

Play Billing only works for an app installed from Play (internal testing
track or later). That is why the CI's downloadable APK uses the test store.

## 8. Purchase validation

- **v1 (shipped):** `LocalReceiptValidator` runs on the device.
  1. It checks that the SKU is known, the token is non-empty and the token
     has not been granted before (tokens are kept in the purchase history,
     `store_test.dart`).
  2. Only then does it grant the purchase and complete it.
- **v2 (server-side, ready in `backend/functions`):**
  1. Deploy the Cloud Function `validatePurchase` (see `backend/README.md`).
     It calls the Google Play Developer API
     (`purchases.products.get`), checks `purchaseState == 0`, writes the
     grant to Firestore (`purchases/{token}`, idempotent) and returns the
     grant.
  2. Create a Google Cloud service account with *View financial data* in
     Play Console and give it to the function (`PLAY_SA_KEY` secret).
  3. In the app, implement `PurchaseValidator` with an HTTP call to the
     function and override `validatorProvider` with it. Nothing else
     changes: `StoreController` already awaits `validate()` before
     granting.
  4. Also enable Real-time developer notifications (Pub/Sub) for refunds.
     The function `onPlayNotification` revokes refunded gems.

Gems are currently stored on the device (Hive). With the server
validator, move the wallet to Firestore so the server owns the balance.
Until then a rooted device can edit its own save; that only affects
cosmetics and that player.

## 9. Remote config

- **Today:** `BundledRemoteConfig` reads
  `assets/data/remote_defaults.json`.
- **Firebase Remote Config:**
  1. Add `firebase_core` and `firebase_remote_config`.
  2. Implement `RemoteConfigService.fetch()` so it returns
     `RemoteConfig.parse(json)` with values from Firebase.
  3. Fall back to the bundled file when Firebase is unavailable.
  4. Override `remoteConfigProvider`.

  Keys and shapes stay identical, so the JSON in the repo is the schema.

## 10. Telemetry

- **Default:** off. The player opts in on first launch or in Settings.
- **Storage:** `LocalFileAnalytics` writes JSON lines on the device;
  nothing leaves the phone in v1.
- **Funnel events:**
  - `app_open`, `level_start`, `level_complete`, `level_fail`
  - `store_open`, `store_purchase_start`, `store_purchase_ok`,
    `store_purchase_fail`
  - `capsule_open`, `offer_shown`, `ad_rewarded`, `ad_interstitial`
- **Firebase Analytics adapter:** implement `AnalyticsService.log` with
  `FirebaseAnalytics.instance.logEvent` and override `analyticsProvider`
  only when `settings.analyticsOptIn` is true.

## 11. KPIs to watch after launch

| Area | KPIs |
|---|---|
| Conversion | Full Cartridge conversion (target 3–5 % of D7 players), payer conversion overall |
| Retention | D1, D7, D30; World 1 completion rate (where the cartridge upsell sits) |
| Revenue | ARPDAU split between ads, cartridge, gems and season |
| Capsules | opens per payer; share of opens that are free (keep above 60 %) |
| Refunds | refund rate (alert above 2 %) |
