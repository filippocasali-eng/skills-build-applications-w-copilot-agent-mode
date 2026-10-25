// ORBIT COMMANDO '94 backend (v2 path, see MONETIZATION.md and PRIVACY.md).
//
//   validatePurchase   HTTPS  verifies a Play purchase and grants it once
//   onPlayNotification PubSub revokes refunded / voided purchases
//   api                HTTPS  chat: GET/POST /chat/:channel, POST /report
//   purgeChatLogs      daily  deletes chat messages older than 30 days
//
// Every HTTPS call carries a Firebase ID token: `Authorization: Bearer <t>`.

const { onRequest } = require('firebase-functions/v2/https');
const { onMessagePublished } = require('firebase-functions/v2/pubsub');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { google } = require('googleapis');

const { SKUS } = require('./catalog');
const { check, chatRights, EMOTES } = require('./moderation');

admin.initializeApp();
const db = admin.firestore();

const PLAY_SA_KEY = defineSecret('PLAY_SA_KEY');
const PACKAGE_NAME = defineString('PACKAGE_NAME', {
  default: 'com.orbitcommando.orbit_commando',
});
const PLAY_TOPIC = defineString('PLAY_RTDN_TOPIC', { default: 'play-rtdn' });

// Channel ids used by the app (lib/features/chat/chat_screen.dart).
const CHANNELS = /^(global(-(it|en))?|squad_[A-Za-z0-9]{3,20}|friends)$/;
const LOG_DAYS = 30;
const SEND_INTERVAL_MS = 3000;
const REPORTS_TO_MUTE = 3;
const MUTE_MS = 24 * 3600 * 1000;

async function uidFrom(req) {
  const h = req.get('authorization') || '';
  const m = h.match(/^Bearer (.+)$/);
  if (!m) return null;
  try {
    return (await admin.auth().verifyIdToken(m[1])).uid;
  } catch {
    return null;
  }
}

function publisher() {
  const auth = new google.auth.GoogleAuth({
    credentials: JSON.parse(PLAY_SA_KEY.value()),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({ version: 'v3', auth });
}

// --------------------------------------------------------------- purchases --

exports.validatePurchase = onRequest(
  { secrets: [PLAY_SA_KEY], cors: false },
  async (req, res) => {
    if (req.method !== 'POST') return res.status(405).end();
    const uid = await uidFrom(req);
    if (!uid) return res.status(401).end();
    const { sku, token } = req.body || {};
    const product = SKUS[sku];
    if (!product || typeof token !== 'string' || !token) {
      return res.status(400).json({ ok: false, reason: 'bad_request' });
    }

    let purchase;
    try {
      purchase = (
        await publisher().purchases.products.get({
          packageName: PACKAGE_NAME.value(),
          productId: sku,
          token,
        })
      ).data;
    } catch (e) {
      return res.status(402).json({ ok: false, reason: 'not_found' });
    }
    // 0 = purchased, 1 = cancelled, 2 = pending.
    if (purchase.purchaseState !== 0) {
      return res.status(402).json({ ok: false, reason: 'not_purchased' });
    }

    // Idempotent grant: the purchase token is the document id.
    const ref = db.collection('purchases').doc(token);
    const wallet = db.collection('wallets').doc(uid);
    const granted = await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      if (existing.exists) return existing.data().uid === uid;
      const w = (await tx.get(wallet)).data() || { gems: 0, owned: [] };
      const owned = new Set(w.owned || []);
      if (product.kind === 'nonConsumable') owned.add(sku);
      tx.set(ref, {
        uid,
        sku,
        cents: product.cents,
        orderId: purchase.orderId || '',
        time: admin.firestore.FieldValue.serverTimestamp(),
        status: 'ok',
      });
      tx.set(wallet, {
        gems: (w.gems || 0) + (product.gems || 0),
        owned: [...owned],
      });
      return true;
    });
    if (!granted) return res.status(409).json({ ok: false, reason: 'owner' });

    // Consumables must be consumed so they can be bought again; the client
    // acknowledges through Play Billing as usual.
    const w = (await wallet.get()).data();
    return res.json({ ok: true, sku, gems: w.gems, owned: w.owned });
  },
);

// Real-time developer notifications: refunds and chargebacks.
exports.onPlayNotification = onMessagePublished(
  { topic: PLAY_TOPIC.value(), secrets: [PLAY_SA_KEY] },
  async (event) => {
    const data = event.data.message.json || {};
    const voided = data.voidedPurchaseNotification;
    if (!voided) return;
    const ref = db.collection('purchases').doc(voided.purchaseToken);
    await db.runTransaction(async (tx) => {
      const p = await tx.get(ref);
      if (!p.exists || p.data().status === 'refunded') return;
      const { uid, sku } = p.data();
      const product = SKUS[sku] || {};
      const wallet = db.collection('wallets').doc(uid);
      const w = (await tx.get(wallet)).data() || { gems: 0, owned: [] };
      tx.update(ref, { status: 'refunded' });
      tx.set(wallet, {
        // Gems can go negative: the player must cover spent refunded gems.
        gems: (w.gems || 0) - (product.gems || 0),
        owned: (w.owned || []).filter((s) =>
          product.kind === 'nonConsumable' ? s !== sku : true,
        ),
      });
    });
  },
);

// -------------------------------------------------------------------- chat --

async function profileOf(uid) {
  return (await db.collection('profiles').doc(uid).get()).data() || {};
}

exports.api = onRequest({ cors: false }, async (req, res) => {
  const uid = await uidFrom(req);
  if (!uid) return res.status(401).end();
  const profile = await profileOf(uid);
  const rights = chatRights(profile);
  if (rights === 'none') return res.status(403).json({ reason: 'age' });

  const parts = req.path.split('/').filter(Boolean);

  if (parts[0] === 'chat' && parts[1] && CHANNELS.test(parts[1])) {
    const channel = parts[1];
    if (channel.startsWith('squad_') && profile.squad !== channel) {
      return res.status(403).json({ reason: 'not_member' });
    }
    // "friends": only messages between mutual friends are visible.
    const friends = new Set([uid, ...(profile.friends || [])]);

    if (req.method === 'GET') {
      const snap = await db
        .collection('messages')
        .where('channel', '==', channel)
        .orderBy('time', 'desc')
        .limit(50)
        .get();
      const blocked = new Set(profile.blocked || []);
      const list = snap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((m) => !blocked.has(m.user) && !m.hidden)
        .filter((m) => channel !== 'friends' || friends.has(m.user))
        .reverse()
        .map((m) => ({
          id: m.id,
          channel: m.channel,
          user: m.user,
          nick: m.nick,
          text: m.text,
          emote: !!m.emote,
          time: m.time.toDate().toISOString(),
        }));
      return res.json(list);
    }

    if (req.method === 'POST') {
      const { text, emote } = req.body || {};
      if ((profile.mutedUntil || 0) > Date.now()) {
        return res.status(403).json({ reason: 'muted' });
      }
      if (Date.now() - (profile.lastSend || 0) < SEND_INTERVAL_MS) {
        return res.status(429).json({ reason: 'rate' });
      }
      if (rights === 'emotes' && !(emote && EMOTES.has(text))) {
        return res.status(403).json({ reason: 'emotes_only' });
      }
      const verdict = check(text);
      if (!verdict.allowed) {
        return res.status(422).json({ reason: verdict.reason });
      }
      await db.collection('messages').add({
        channel,
        user: uid,
        nick: profile.nick || 'PILOT',
        text: text.trim(),
        emote: !!emote,
        time: admin.firestore.FieldValue.serverTimestamp(),
      });
      await db
        .collection('profiles')
        .doc(uid)
        .set({ lastSend: Date.now() }, { merge: true });
      return res.json({ ok: true });
    }
  }

  if (parts[0] === 'report' && req.method === 'POST') {
    const { message } = req.body || {};
    if (typeof message !== 'string') return res.status(400).end();
    const msgRef = db.collection('messages').doc(message);
    const msg = await msgRef.get();
    if (!msg.exists) return res.status(404).end();
    await db.collection('reports').add({
      message,
      reporter: uid,
      user: msg.data().user,
      text: msg.data().text,
      time: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Two reports hide a message for everyone; reports from three different
    // players auto-mute its author for 24 h. Moderators review `reports`.
    const sameMessage = await db
      .collection('reports')
      .where('message', '==', message)
      .get();
    if (sameMessage.size >= 2) await msgRef.update({ hidden: true });
    const reporters = new Set(
      (
        await db.collection('reports').where('user', '==', msg.data().user).get()
      ).docs.map((d) => d.data().reporter),
    );
    if (reporters.size >= REPORTS_TO_MUTE) {
      await db
        .collection('profiles')
        .doc(msg.data().user)
        .set({ mutedUntil: Date.now() + MUTE_MS }, { merge: true });
    }
    return res.json({ ok: true });
  }

  return res.status(404).end();
});

// Chat logs are kept for 30 days (PRIVACY.md), reports for review as long
// as needed by moderators.
exports.purgeChatLogs = onSchedule('every 24 hours', async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - LOG_DAYS * 24 * 3600 * 1000,
  );
  for (;;) {
    const old = await db
      .collection('messages')
      .where('time', '<', cutoff)
      .limit(400)
      .get();
    if (old.empty) return;
    const batch = db.batch();
    old.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
});
