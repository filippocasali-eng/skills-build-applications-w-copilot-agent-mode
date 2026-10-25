# Privacy and safety

This is the developer reference. The player-facing text is in
`lib/features/settings/privacy_screen.dart` (IT/EN) and must stay
consistent with it. A published privacy policy URL is required by Play.
Host this page, adapted with the publisher's legal name and contact.

## Data the app handles

| Data | Where | Purpose | Shared |
|---|---|---|---|
| Progress, settings, wallet, purchase history, ghosts | On the device (Hive) | Play the game | No |
| Age-gate answer (birth year + month only) | On the device | Age-based features | Backend only if online features are on |
| Purchase token | On the device; backend when validation is on | Grant purchases once | Google Play |
| Advertising ID | Google Mobile Ads SDK | Ads, personalised only with UMP consent | Google (AdMob) |
| Telemetry events | Local file, opt-in, off by default | Improve the game | No (v1) |
| Chat messages (backend on) | Firestore, 30-day retention (`purgeChatLogs`) | Chat, moderation | No |

The app does not collect name, e-mail, contacts, location or precise
device identifiers.

## Age gate

- **First launch:** the age gate asks for the birth month and year,
  neutrally. There is no default answer and no hint about which answer
  unlocks what.
- **What age changes:**

| Age | Online chat | Paid capsules | Ads |
|---|---|---|---|
| Under 16 | No online features | No | Teen treatment (no personalisation) |
| 16–17 | Quick messages only (no free text) | No | Teen treatment |
| 18+ | Free text, filtered | Yes (except blocked countries) | Personalised only with consent |

Until the age gate is answered, the player is treated as a minor.

## Consent

- **Ads:** Google UMP collects consent before any ad request (GDPR/EEA
  and UK). "Privacy options" in Settings reopens the form.
- **Telemetry:** opt-in. Push notifications are opt-in, at most 1 a day
  (`push_max_per_day`).

## Chat moderation

- **Filter on the device and on the server:**
  - insults and slurs in IT and EN, including leetspeak and spaced-out
    letters
  - phone numbers, e-mail addresses and links
  - a maximum of 140 characters
- **Rate limit:** 1 message every 3 s.
- **Reports and mutes:**
  - Every message can be reported, and every author can be blocked.
  - Two reports hide a message.
  - Reports from three different players mute the author for 24 h.
  - Moderators review the `reports` collection.
- **Channels:** private messages only between mutual friends. Squad chat
  is for squad members only.
- **Offline:** without a backend the chat runs as a clearly labelled
  offline demo with simulated players.

## Deleting data

- **Local data:** Settings → Privacy → "Delete my data" wipes the local
  save. Store purchases can be restored from Google Play afterwards.
- **Backend data:** with the backend on, the same action must also call a
  delete endpoint that removes `profiles/{uid}`, `wallets/{uid}` and that
  user's messages. Google Play requires an in-app path and a web form for
  account deletion once accounts exist.

## Play Console — Data safety form (v1 build)

| Question | Answer |
|---|---|
| Data collected | Device or other IDs (advertising ID, by the AdMob SDK); App activity → in-app purchases (purchase history, on the device) |
| Data shared | Advertising ID with Google for ads |
| Encrypted in transit | Yes (ads SDK) |
| Data deletion | Yes, in-app |
| Purpose | Advertising, app functionality |

Update the form when the backend (chat, accounts, server validation) goes
live.
