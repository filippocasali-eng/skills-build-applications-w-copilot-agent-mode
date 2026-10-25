# Backend (optional, v2 path)

The v1 app works fully offline. This folder holds the Firebase backend that
turns on server-side purchase validation, the online chat and (later) online
leaderboards. Nothing here is deployed automatically.

| Piece | File | What it does |
|---|---|---|
| `validatePurchase` | `functions/src/index.js` | Verifies a Play purchase with the Play Developer API and grants it once (purchase token = Firestore doc id) |
| `onPlayNotification` | same | Real-time developer notifications: revokes refunded / voided purchases |
| `api` | same | Chat: `GET/POST /chat/:channel` (`global`, `squad_<id>`, `friends`), `POST /report`; filter, rate limit (1 msg / 3 s), age rules, auto-mute |
| `purgeChatLogs` | same | Daily: deletes chat messages older than 30 days |
| Moderation rules | `functions/src/moderation.js` | Same filter as the app (words, leetspeak, phone numbers, e-mails, links) |
| Security rules | `firestore.rules` | Clients can only read their own wallet/purchases; every write goes through the functions |

## Deploy

```bash
npm i -g firebase-tools
cd backend/functions && npm install && npm test
firebase login
firebase use --add                      # pick your Firebase project
firebase functions:secrets:set PLAY_SA_KEY < play-service-account.json
firebase deploy --only functions,firestore
```

1. In Play Console → Users and permissions, invite the service account and
   give it *View financial data* and *Manage orders*.
2. In Play Console → Monetization setup, enable Real-time developer
   notifications on the Pub/Sub topic `play-rtdn` (or set `PLAY_RTDN_TOPIC`).
3. Enable Firebase Authentication (anonymous sign-in is enough) and write the
   player's age-gate answer to `profiles/{uid}` (`birthYear`, `birthMonth`,
   `nick`, `squad`, `friends`, `blocked`).

## Wiring the app

- **Chat:** build with `--dart-define=BACKEND_URL=https://<region>-<project>.cloudfunctions.net/api`
  and pass the Firebase ID token to `BackendChatService` (see
  `lib/core/social/chat_service.dart`, `chatServiceProvider`).
- **Purchases:** implement `PurchaseValidator` with a POST to
  `validatePurchase` (`{sku, token}`), override `validatorProvider`, and read
  the wallet from `wallets/{uid}` instead of the local save (see
  `MONETIZATION.md` §8).
