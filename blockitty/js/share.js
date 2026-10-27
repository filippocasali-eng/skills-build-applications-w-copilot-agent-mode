// Viral loop: shareable score cards and friend-challenge links.
// A challenge link carries a seed + score, so a friend plays the exact same
// starting pieces in the browser (no install needed) and tries to beat it.

import { WEB_URL, isNative, plugin } from './config.js';
import { catSVG } from './cats.js';

export function challengeLink({ seed, score, name, mode = 'duel' }) {
  const u = new URL(WEB_URL);
  u.searchParams.set('c', String(seed));
  u.searchParams.set('s', String(score));
  if (name) u.searchParams.set('n', name.slice(0, 16));
  if (mode === 'daily') u.searchParams.set('d', '1');
  return u.toString();
}

export function readIncomingChallenge(href = location.href) {
  try {
    const u = new URL(href);
    const seed = Number(u.searchParams.get('c'));
    if (!seed) return null;
    return {
      seed: seed >>> 0,
      score: Math.max(0, Number(u.searchParams.get('s')) || 0),
      name: (u.searchParams.get('n') || 'A friend').replace(/[<>&"]/g, '').slice(0, 16),
    };
  } catch {
    return null;
  }
}

function loadImage(src) {
  return new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = src; });
}

// 1080x1350 portrait card (Instagram/TikTok friendly).
export async function scoreCard({ score, best, look, headline, sub }) {
  const W = 1080, H = 1350;
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  const x = c.getContext('2d');
  const g = x.createLinearGradient(0, 0, W, H);
  g.addColorStop(0, '#ffcf9f'); g.addColorStop(0.55, '#ff9a8b'); g.addColorStop(1, '#ff6a88');
  x.fillStyle = g; x.fillRect(0, 0, W, H);
  // confetti blocks
  const cols = ['#ff5a5f', '#ffb400', '#ffe14d', '#3ddc84', '#2bb5ff', '#7a5cff', '#ff7ad9'];
  for (let i = 0; i < 26; i++) {
    const s = 40 + (i * 37) % 50;
    x.save(); x.translate((i * 197) % W, (i * 331) % H); x.rotate(i);
    x.globalAlpha = 0.35; x.fillStyle = cols[i % 7];
    x.beginPath(); x.roundRect(-s / 2, -s / 2, s, s, s * 0.2); x.fill(); x.restore();
  }
  const svg = catSVG(look, 'love').replace('class="cat-svg "', 'width="600" height="672"');
  try {
    const img = await loadImage(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`);
    x.drawImage(img, 240, 150, 600, 672);
  } catch { /* card still works without the cat */ }
  x.textAlign = 'center';
  x.fillStyle = '#fff';
  x.shadowColor = 'rgba(120,10,60,.45)'; x.shadowOffsetY = 8;
  x.font = '700 92px Fredoka, sans-serif';
  x.fillText('Blockitty', W / 2, 130);
  x.font = '700 64px Fredoka, sans-serif';
  x.fillText(headline, W / 2, 900);
  x.font = '700 190px Fredoka, sans-serif';
  x.fillText(score.toLocaleString('en-US'), W / 2, 1090);
  x.shadowOffsetY = 0;
  x.font = '600 46px Fredoka, sans-serif';
  x.fillStyle = 'rgba(255,255,255,.95)';
  x.fillText(sub || (best ? `Best ${best.toLocaleString('en-US')}` : ''), W / 2, 1170);
  x.fillStyle = 'rgba(40,10,40,.75)';
  x.beginPath(); x.roundRect(190, 1220, 700, 90, 45); x.fill();
  x.fillStyle = '#fff'; x.font = '600 42px Fredoka, sans-serif';
  x.fillText('Can you beat me? 🐾', W / 2, 1280);
  return c;
}

// Returns 'shared' | 'copied' | 'cancelled'
export async function shareContent({ text, url, canvas }) {
  const full = `${text} ${url}`;
  if (isNative()) {
    const Share = plugin('Share');
    const FS = plugin('Filesystem');
    try {
      let files;
      if (canvas && FS) {
        const data = canvas.toDataURL('image/png').split(',')[1];
        const f = await FS.writeFile({ path: `blockitty-${Date.now()}.png`, data, directory: 'CACHE' });
        files = [f.uri];
      }
      await Share.share({ title: 'Blockitty', text, url, files, dialogTitle: 'Challenge your friends' });
      return 'shared';
    } catch {
      return 'cancelled';
    }
  }
  try {
    if (canvas && navigator.canShare) {
      const blob = await new Promise((r) => canvas.toBlob(r, 'image/png'));
      const file = new File([blob], 'blockitty.png', { type: 'image/png' });
      if (navigator.canShare({ files: [file] })) {
        await navigator.share({ files: [file], text: full });
        return 'shared';
      }
    }
    if (navigator.share) { await navigator.share({ text, url }); return 'shared'; }
  } catch (e) {
    if (e && e.name === 'AbortError') return 'cancelled';
  }
  try { await navigator.clipboard.writeText(full); return 'copied'; } catch { return 'cancelled'; }
}
