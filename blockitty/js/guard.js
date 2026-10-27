// Anti-clone guard. The official game only runs as the Play Store package or on
// the official web domains; repackaged or re-hosted copies refuse to start.
// (Works together with the obfuscated production build.)

import { APP_ID, PLAY_URL, WEB_HOSTS, isNative, plugin } from './config.js';

function block() {
  document.body.innerHTML = `<div style="position:fixed;inset:0;display:grid;place-items:center;background:#ff8a8a;font-family:sans-serif;text-align:center;padding:24px;color:#2b1630">
    <div><h1>Unofficial copy</h1><p>This is not the official Blockitty game.</p>
    <p><a href="${PLAY_URL}" style="color:#2b1630;font-weight:bold">Get the original on Google Play</a></p></div></div>`;
  throw new Error('blocked');
}

export async function verifyOfficial() {
  if (isNative()) {
    const App = plugin('App');
    if (!App) return;
    try {
      const info = await App.getInfo();
      if (info.id !== APP_ID) block();
    } catch (e) {
      if (e && e.message === 'blocked') throw e;
    }
    return;
  }
  if (location.protocol === 'file:') block();
  if (!WEB_HOSTS.includes(location.hostname)) block();
}
