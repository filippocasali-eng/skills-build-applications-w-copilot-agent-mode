// Real-money purchases.
// - Inside the Play Store build (Trusted Web Activity) it uses Google Play
//   Billing through the Digital Goods API + Payment Request API.
// - Anywhere else (browser / local install) it runs in DEMO mode: purchases are
//   simulated and nothing is charged. The UI says so clearly.

const PLAY_BILLING = 'https://play.google.com/billing';
let service = null;
let details = {};

export async function initBilling() {
  if (!('getDigitalGoodsService' in window)) return false;
  try {
    service = await window.getDigitalGoodsService(PLAY_BILLING);
    return true;
  } catch {
    service = null;
    return false;
  }
}

export const isDemo = () => !service;

export async function loadPrices(skus) {
  if (!service) return {};
  try {
    const list = await service.getDetails(skus);
    details = Object.fromEntries(list.map((d) => [d.itemId, d]));
    return Object.fromEntries(list.map((d) => [d.itemId, new Intl.NumberFormat(undefined, { style: 'currency', currency: d.price.currency }).format(d.price.value)]));
  } catch {
    return {};
  }
}

// Returns true when the purchase completed and the goods should be granted.
export async function purchase(sku, confirmDemo) {
  if (!service) return confirmDemo();
  try {
    const request = new PaymentRequest(
      [{ supportedMethods: PLAY_BILLING, data: { sku } }],
      { total: { label: 'Total', amount: { currency: 'USD', value: '0' } } },
    );
    const response = await request.show();
    const { purchaseToken } = response.details;
    // Production: verify purchaseToken on your server before granting.
    await response.complete('success');
    if (sku !== 'starter_pack') await service.consume(purchaseToken);
    return true;
  } catch {
    return false;
  }
}

export { details as billingDetails };
