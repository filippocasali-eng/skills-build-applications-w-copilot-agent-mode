// Ads: opt-in rewarded videos (revive, double coins, free box, extra spin) and
// rare interstitials. Native builds use AdMob (with the Google UMP consent form
// for GDPR). The web build shows a clearly labelled demo placeholder instead.

import { ADMOB, AD_RULES, isNative, plugin } from './config.js';
import { S, save } from './state.js';
import { suspendAudio, resumeAudio } from './audio.js';

let ready = false;
let lastInterstitial = 0;

export async function initAds() {
  const AdMob = plugin('AdMob');
  if (!isNative() || !AdMob) return;
  try {
    await AdMob.initialize({ initializeForTesting: ADMOB.testing });
    try {
      const info = await AdMob.requestConsentInfo();
      if (info.isConsentFormAvailable && info.status === 'REQUIRED') await AdMob.showConsentForm();
    } catch { /* consent not required in this region */ }
    ready = true;
  } catch {
    ready = false;
  }
}

export const adsAvailable = () => true; // native AdMob or web demo placeholder

function demoAd(seconds = 3) {
  return new Promise((resolve) => {
    const el = document.createElement('div');
    el.className = 'demo-ad';
    el.innerHTML = `<div class="demo-ad-box"><b>Ad placeholder</b><p>In the Play Store app a short video ad plays here.</p><div class="demo-ad-count">${seconds}</div></div>`;
    document.body.appendChild(el);
    let n = seconds;
    const iv = setInterval(() => {
      n -= 1;
      el.querySelector('.demo-ad-count').textContent = n;
      if (n <= 0) { clearInterval(iv); el.remove(); resolve(true); }
    }, 1000);
  });
}

// Resolves true when the player earned the reward.
export async function showRewarded() {
  const AdMob = plugin('AdMob');
  if (!isNative() || !AdMob || !ready) return demoAd();
  suspendAudio();
  try {
    await AdMob.prepareRewardVideoAd({ adId: ADMOB.rewarded, isTesting: ADMOB.testing });
    const reward = await AdMob.showRewardVideoAd();
    return !!reward;
  } catch {
    return false;
  } finally {
    resumeAudio();
  }
}

export async function maybeInterstitial() {
  if (S.purchases.noAds) return;
  const games = S.stats.games;
  if (games < AD_RULES.interstitialFirstGame) return;
  if ((games - AD_RULES.interstitialFirstGame) % AD_RULES.interstitialEvery !== 0) return;
  if (Date.now() - lastInterstitial < AD_RULES.interstitialMinGapMs) return;
  const AdMob = plugin('AdMob');
  if (!isNative() || !AdMob || !ready) return; // never fake interstitials on the web
  lastInterstitial = Date.now();
  suspendAudio();
  try {
    await AdMob.prepareInterstitial({ adId: ADMOB.interstitial, isTesting: ADMOB.testing });
    await AdMob.showInterstitial();
    S.stats.interstitials = (S.stats.interstitials || 0) + 1;
    save();
  } catch { /* no fill */ } finally {
    resumeAudio();
  }
}
