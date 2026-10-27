// Real-money purchases through Google Play Billing (cordova-plugin-purchase,
// bundled in the Android build). In the browser it runs in DEMO mode: purchases
// are simulated, nothing is charged, and the UI says so.

import { isNative } from './config.js';
import { GEM_PACKS, STARTER_PACK, NO_ADS } from './data.js';

let store = null;
let onGrant = null;
const pending = new Map(); // productId -> resolve
const granted = new Set(JSON.parse(localStorage.getItem('blockitty-tx') || '[]'));

const CONSUMABLES = [...GEM_PACKS.map((g) => g.sku), STARTER_PACK.sku];
const NON_CONSUMABLES = [NO_ADS.sku];

function rememberTx(id) {
  granted.add(id);
  try { localStorage.setItem('blockitty-tx', JSON.stringify([...granted].slice(-200))); } catch { /* ignore */ }
}

// grant(sku) is called exactly once per completed purchase.
export async function initBilling(grant) {
  onGrant = grant;
  if (!isNative()) return;
  await new Promise((r) => (window.CdvPurchase ? r() : document.addEventListener('deviceready', r, { once: true })));
  const C = window.CdvPurchase;
  if (!C) return;
  store = C.store;
  const P = C.Platform.GOOGLE_PLAY;
  store.register([
    ...CONSUMABLES.map((id) => ({ id, type: C.ProductType.CONSUMABLE, platform: P })),
    ...NON_CONSUMABLES.map((id) => ({ id, type: C.ProductType.NON_CONSUMABLE, platform: P })),
  ]);
  store.when()
    .approved((tx) => {
      // Production tip: validate tx with your server (store.validator) before granting.
      if (!granted.has(tx.transactionId)) {
        rememberTx(tx.transactionId);
        for (const p of tx.products) {
          onGrant && onGrant(p.id);
          const res = pending.get(p.id);
          if (res) { pending.delete(p.id); res(true); }
        }
      }
      tx.finish();
    })
    .productUpdated((p) => {
      if (NON_CONSUMABLES.includes(p.id) && p.owned) onGrant && onGrant(p.id, true);
    });
  store.error(() => {
    for (const [id, res] of pending) { pending.delete(id); res(false); }
  });
  await store.initialize([P]);
}

export const isDemo = () => !store;

export function localPrice(sku, fallback) {
  const p = store && store.get(sku);
  return (p && p.pricing && p.pricing.price) || fallback;
}

// Returns true when the purchase completed (goods are granted via onGrant).
export async function purchase(sku, confirmDemo) {
  if (!store) {
    const ok = await confirmDemo();
    if (ok) onGrant && onGrant(sku);
    return ok;
  }
  const product = store.get(sku);
  const offer = product && product.getOffer();
  if (!offer) return false;
  return new Promise((resolve) => {
    pending.set(sku, resolve);
    offer.order().then((err) => {
      if (err) { pending.delete(sku); resolve(false); }
    });
    setTimeout(() => { if (pending.has(sku)) { pending.delete(sku); resolve(false); } }, 120000);
  });
}

export async function restorePurchases() {
  if (store) await store.restorePurchases();
}
