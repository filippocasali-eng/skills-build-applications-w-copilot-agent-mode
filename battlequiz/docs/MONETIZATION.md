# Monetization

**Status: not implemented. No payments are active.** Stripe integration is Milestone 6 and will run in test mode until explicitly approved.

## Model: fair freemium
- **Free (forever):** unlimited Quick Play (abuse-limited), Daily Challenge, basic profile, basic leaderboards, friend challenges, standard avatars.
- **BattleQuiz Plus — suggested €3.99/month:** exclusive themes, premium avatars, advanced statistics, extended history, custom private rooms, extra non-ranked modes, cosmetic seasonal rewards.
- **Never:** scoring advantages in ranked play, paywalled essential gameplay, real-money prizes, paid entry, loot boxes.

## Planned implementation (M6)
Stripe Checkout + Billing + Customer Portal, configurable price ids, `subscriptions` table updated only from verified webhooks, `billing_events` primary key for replay protection, entitlements resolved server-side. Native apps would require Apple/Google IAP evaluation.

## Advertising (optional, later)
Abstraction only; allowed placements: between completed matches, optional rewarded ads for cosmetics, non-intrusive home placement. Never during a question, never required to finish a competitive match, only with GDPR consent and a verified provider.
