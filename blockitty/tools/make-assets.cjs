// Generates every graphic asset (icons, Android launcher/splash, Play Store
// feature graphic + screenshots, share preview) from the game's own art.
// Usage (needs Playwright + Chromium): node tools/make-assets.cjs   [from blockitty/]
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const http = require('http');

const ROOT = path.resolve(__dirname, '..');
const cats = fs.readFileSync(path.join(ROOT, 'js/cats.js'), 'utf8').replace(/export /g, '');
const font = (w) => `url(data:font/woff2;base64,${fs.readFileSync(path.join(ROOT, `fonts/fredoka-latin-${w}-normal.woff2`)).toString('base64')})`;
const HERO = { fur: '#f6a04d', fur2: '#d9772a', pattern: 'tabby', eyes: '#3aa655', acc: 'crown' };
const BG = 'linear-gradient(160deg,#ffcf9f 0%,#ff9a8b 55%,#ff6a88 100%)';
const BLOCKS = [['#2bb5ff', 0, 3], ['#3ddc84', 1, 3], ['#ffe14d', 2, 3], ['#ff5a5f', 3, 3], ['#7a5cff', 3, 2], ['#ff7ad9', 0, 2]];
const block = (col, x, y, s) => `<div style="position:absolute;left:${x}px;top:${y}px;width:${s}px;height:${s}px;background:${col};border-radius:${s * 0.16}px;box-shadow:inset 0 -${s * 0.1}px 0 rgba(0,0,0,.18),inset 0 ${s * 0.08}px 0 rgba(255,255,255,.35)"></div>`;
const page = (w, h, body, bg = BG) => `<html><head><style>
@font-face{font-family:F;font-weight:600;src:${font(600)}}@font-face{font-family:F;font-weight:700;src:${font(700)}}
body{margin:0}#i{width:${w}px;height:${h}px;background:${bg};position:relative;overflow:hidden;font-family:F}
.t{color:#fff;font-weight:700;text-shadow:0 6px 0 #c2185b,0 14px 24px rgba(0,0,0,.25)}.t span{color:#ffe14d}
</style></head><body><div id="i">${body}</div><script>${cats}
document.querySelectorAll('[data-cat]').forEach(e=>{e.innerHTML=catSVG(JSON.parse(e.dataset.cat),e.dataset.mood||'happy')});</script></body></html>`;
const catDiv = (x, y, w, mood = 'happy', look = HERO) => `<div data-cat='${JSON.stringify(look)}' data-mood="${mood}" style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${w * 1.12}px"></div>`;

function iconBody(s, pad) {
  const inner = s - pad * 2; const b = inner / 4;
  return `<div style="position:absolute;inset:${pad}px">${BLOCKS.map(([c, x, y]) => block(c, x * b + b * 0.02, y * b + b * 0.02, b * 0.96)).join('')}${catDiv(inner * 0.08, -inner * 0.02, inner * 0.84)}</div>`;
}

function serve() {
  return new Promise((res) => {
    const srv = http.createServer((req, rsp) => {
      let f = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (f.endsWith('/')) f += 'index.html';
      if (!fs.existsSync(f)) { rsp.writeHead(404); rsp.end(); return; }
      const ext = path.extname(f);
      const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.png': 'image/png', '.webmanifest': 'application/manifest+json' };
      rsp.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
      fs.createReadStream(f).pipe(rsp);
    }).listen(0, () => res(srv));
  });
}

(async () => {
  const browser = await chromium.launch();
  const render = async (html, w, h, file, transparent = false) => {
    const p = await browser.newPage({ viewport: { width: w, height: h } });
    await p.setContent(html);
    await p.waitForTimeout(150);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await p.locator('#i').screenshot({ path: file, omitBackground: transparent });
    await p.close();
  };
  const resize = async (src, w, h, file, round = false) => {
    const p = await browser.newPage({ viewport: { width: w, height: h } });
    await p.setContent(`<html><body style="margin:0;background:transparent"><img id="i" src="data:image/png;base64,${fs.readFileSync(src).toString('base64')}" style="display:block;width:${w}px;height:${h}px;${round ? 'border-radius:50%' : ''}"></body></html>`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await p.locator('#i').screenshot({ path: file, omitBackground: true });
    await p.close();
  };
  const tmp = path.join(ROOT, 'store/.tmp'); fs.mkdirSync(tmp, { recursive: true });

  // Master icons
  await render(page(1024, 1024, iconBody(1024, 40)), 1024, 1024, `${tmp}/icon.png`);
  await render(page(1024, 1024, iconBody(1024, 170)), 1024, 1024, `${tmp}/maskable.png`);
  await render(page(1024, 1024, catDiv(512 - 300, 512 - 330, 600, 'happy'), 'transparent'), 1024, 1024, `${tmp}/fg.png`, true);
  await resize(`${tmp}/icon.png`, 512, 512, `${ROOT}/icons/icon-512.png`);
  await resize(`${tmp}/icon.png`, 192, 192, `${ROOT}/icons/icon-192.png`);
  await resize(`${tmp}/maskable.png`, 512, 512, `${ROOT}/icons/maskable-512.png`);
  await resize(`${tmp}/icon.png`, 512, 512, `${ROOT}/store/play-icon-512.png`);

  // Android launcher icons
  const RES = `${ROOT}/android-res/res`;
  for (const [d, legacy, fg] of [['mdpi', 48, 108], ['hdpi', 72, 162], ['xhdpi', 96, 216], ['xxhdpi', 144, 324], ['xxxhdpi', 192, 432]]) {
    await resize(`${tmp}/icon.png`, legacy, legacy, `${RES}/mipmap-${d}/ic_launcher.png`);
    await resize(`${tmp}/icon.png`, legacy, legacy, `${RES}/mipmap-${d}/ic_launcher_round.png`, true);
    await resize(`${tmp}/fg.png`, fg, fg, `${RES}/mipmap-${d}/ic_launcher_foreground.png`);
  }
  // Splash screens (same sizes as the Capacitor template)
  const splash = (w, h) => page(w, h, `${catDiv(w / 2 - Math.min(w, h) * 0.22, h / 2 - Math.min(w, h) * 0.32, Math.min(w, h) * 0.44)}<div class="t" style="position:absolute;left:0;right:0;top:${h / 2 + Math.min(w, h) * 0.2}px;text-align:center;font-size:${Math.min(w, h) * 0.12}px">Block<span>itty</span></div>`);
  const sizes = { 'drawable': [480, 320], 'drawable-land-mdpi': [480, 320], 'drawable-land-hdpi': [800, 480], 'drawable-land-xhdpi': [1280, 720], 'drawable-land-xxhdpi': [1600, 960], 'drawable-land-xxxhdpi': [1920, 1280], 'drawable-port-mdpi': [320, 480], 'drawable-port-hdpi': [480, 800], 'drawable-port-xhdpi': [720, 1280], 'drawable-port-xxhdpi': [960, 1600], 'drawable-port-xxxhdpi': [1280, 1920] };
  for (const [dir, [w, h]] of Object.entries(sizes)) await render(splash(w, h), w, h, `${RES}/${dir}/splash.png`);

  // Feature graphic 1024x500 + social preview 1200x630
  const banner = (w, h) => page(w, h, `
    ${BLOCKS.map(([c], k) => block(c, 40 + k * 70, h - 120 + (k % 2) * 30, 64)).join('')}
    ${catDiv(w - h * 0.95, h * 0.04, h * 0.85, 'love')}
    <div class="t" style="position:absolute;left:${w * 0.06}px;top:${h * 0.2}px;font-size:${h * 0.24}px;line-height:1">Block<span>itty</span></div>
    <div style="position:absolute;left:${w * 0.065}px;top:${h * 0.5}px;font-size:${h * 0.075}px;color:#fff;font-weight:600;text-shadow:0 3px 0 rgba(0,0,0,.2)">Cute cats. Satisfying blocks.</div>`);
  await render(banner(1024, 500), 1024, 500, `${ROOT}/store/feature-graphic-1024x500.png`);
  await render(banner(1200, 630), 1200, 630, `${ROOT}/icons/og.png`);

  // Store screenshots from the real game
  const srv = await serve();
  const URL = `http://localhost:${srv.address().port}/index.html`;
  const ctx = await browser.newContext({ viewport: { width: 390, height: 780 }, deviceScaleFactor: 2.77 });
  const seed = (extra) => ctx.addInitScript((d) => { if (!localStorage.getItem('blockitty-seeded')) { localStorage.setItem('blockitty-save-v1', d); localStorage.setItem('blockitty-seeded', '1'); } }, JSON.stringify(extra));
  const base = { v: 2, coins: 12840, gems: 1250, level: 14, xp: 900, tutorialDone: true, best: { classic: 18450 }, stats: { games: 40, lines: 900, pieces: 2000, bestCombo: 9, perfects: 3, boxes: 30, shares: 2 }, streak: { count: 12, last: new Date().toISOString().slice(0, 10) }, pass: { season: Math.floor((Date.now() - Date.UTC(2026, 0, 5)) / (28 * 86400000)), xp: 3300, premium: false, free: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], prem: [] } };
  const owned = ['cat:mochi', 'cat:pepper', 'cat:biscuit', 'cat:smokey', 'cat:socks', 'cat:duchess', 'cat:tiara', 'cat:whiskers', 'cat:sushi', 'cat:boba', 'cat:cupcake', 'cat:riff', 'cat:glam', 'cat:luna', 'cat:merlin', 'cat:nova', 'skin:classic', 'skin:galaxy', 'skin:neon', 'skin:candy', 'theme:cozy', 'theme:space', 'theme:sakura', 'fx:sparkle', 'fx:stars'];
  await seed({ ...base, owned, seen: owned, equip: { cat: 'merlin', skin: 'candy', theme: 'cozy', fx: 'stars' } });
  const p = await ctx.newPage();
  await p.goto(URL);
  await p.waitForTimeout(900);
  await p.evaluate(() => document.querySelectorAll('.modal-back').forEach((m) => m.remove()));
  const shots = [];
  const snap = async (name) => { await p.evaluate(() => document.querySelectorAll('.get-app').forEach((e) => e.remove())); const f = `${tmp}/${name}.png`; await p.screenshot({ path: f }); shots.push(f); };
  await snap('home');
  await p.click('[data-act="play"]', { force: true }); await p.waitForTimeout(500);
  // fill a lively board with near-complete lines
  await p.evaluate(async () => {
    const g = (await import('./js/game.js')).current();
    const rows = ['12345670', '23450671', '00000000', '30004000', '45106210', '56702340', '67123450', '71234560'];
    rows.forEach((row, r) => [...row].forEach((v, c) => { g.board[r][c] = Number(v); }));
    g.score = 8640; g.comboState = { combo: 4, miss: 0 };
    (await import('./js/game.js')).refresh();
  });
  await p.waitForTimeout(400);
  await snap('game');
  await p.evaluate(() => { document.getElementById('btn-pause').click(); });
  await p.waitForTimeout(200);
  await p.click('[data-home]');
  await p.click('[data-nav="cats"]'); await p.waitForTimeout(400);
  await snap('cats');
  await p.evaluate(async () => { const s = (await import('./js/state.js')); s.S.gems += 900; });
  await p.click('[data-open="g10"]'); await p.waitForTimeout(400); await p.click('.opening'); await p.waitForTimeout(1600);
  await snap('box');
  await p.click('.modal [data-close]'); await p.waitForTimeout(200);
  await p.click('[data-nav="pass"]'); await p.waitForTimeout(400);
  await snap('pass');
  srv.close();

  const captions = [
    ['Collect adorable cats', 'Over 30 cats to unlock & dress up'],
    ['Blast satisfying combos', 'Fill rows & columns. Chain combos!'],
    ['Build your collection', 'Cats, block skins, themes & effects'],
    ['Open Mystery Boxes', 'Epic, Legendary & Mythic drops'],
    ['Earn Paw Pass rewards', 'Free & premium seasonal rewards'],
  ];
  for (let i = 0; i < shots.length; i++) {
    const img = fs.readFileSync(shots[i]).toString('base64');
    const html = page(1080, 1920, `
      <div class="t" style="position:absolute;top:70px;left:0;right:0;text-align:center;font-size:92px">${captions[i][0]}</div>
      <div style="position:absolute;top:200px;left:0;right:0;text-align:center;font-size:48px;color:#fff;font-weight:600">${captions[i][1]}</div>
      <img src="data:image/png;base64,${img}" style="position:absolute;left:${(1080 - 780) / 2}px;top:310px;width:780px;height:1560px;border-radius:56px;box-shadow:0 30px 60px rgba(0,0,0,.35);border:10px solid #fff">`);
    await render(html, 1080, 1920, `${ROOT}/store/screenshot-${i + 1}.png`);
  }
  fs.copyFileSync(shots[1], `${ROOT}/icons/screenshot-game.png`);
  fs.rmSync(tmp, { recursive: true, force: true });
  await browser.close();
  console.log('assets generated');
})();
