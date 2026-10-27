// App-wide configuration. Replace the AdMob IDs with your own before release
// (the defaults are Google's official test IDs and never pay out).

export const APP_ID = 'com.blockitty.game';
export const APP_NAME = 'Blockitty';
export const VERSION = '2.1.0';

// Public web version (GitHub Pages). Friend-challenge links open here so anyone
// can play instantly, even without the app installed.
export const WEB_URL = 'https://filippocasali-eng.github.io/skills-build-applications-w-copilot-agent-mode/';
// Domains allowed to run the web version (anti-clone guard). Add your own domain here.
export const WEB_HOSTS = ['filippocasali-eng.github.io', 'localhost', '127.0.0.1'];
export const PLAY_URL = `https://play.google.com/store/apps/details?id=${APP_ID}`;
export const SUPPORT_EMAIL = 'filippocasali@gmail.com';

export const ADMOB = {
  rewarded: 'ca-app-pub-3940256099942544/5224354917', // test ID
  interstitial: 'ca-app-pub-3940256099942544/1033173712', // test ID
  testing: true, // set false with real IDs
};

// Ad pacing: gentle by design (aggressive ads are the #1 complaint in this genre).
export const AD_RULES = {
  interstitialFirstGame: 4, // never before the 4th finished game
  interstitialEvery: 3, // then at most every 3rd game
  interstitialMinGapMs: 180000,
};

export const isNative = () => !!(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
export const plugin = (name) => (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins[name]) || null;
