// Renders the app icons from the in-game cat SVG using the bundled Playwright Chromium.
// Usage: node tools/make-icons.mjs   (run from the blockitty/ folder)
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { readFileSync } from 'node:fs';

const cats = readFileSync(new URL('../js/cats.js', import.meta.url), 'utf8').replace(/export /g, '');
const page = (pad) => `<html><body style="margin:0">
<div id="i" style="width:512px;height:512px;background:linear-gradient(160deg,#ffcf9f,#ff6a88);display:grid;place-items:center;position:relative;overflow:hidden">
  <div style="position:absolute;inset:${pad}px;">
    ${[[0, 3, '#2bb5ff'], [1, 3, '#3ddc84'], [2, 3, '#ffe14d'], [3, 3, '#ff5a5f'], [3, 2, '#7a5cff'], [0, 2, '#ff7ad9']]
      .map(([c, r, col]) => `<div style="position:absolute;left:${c * 25}%;top:${r * 25}%;width:24%;height:24%;background:${col};border-radius:14%;box-shadow:inset 0 -10px 0 rgba(0,0,0,.18),inset 0 8px 0 rgba(255,255,255,.35)"></div>`).join('')}
    <div id="cat" style="position:absolute;left:8%;top:0;width:84%;height:84%"></div>
  </div>
</div>
<script>${cats}; document.getElementById('cat').innerHTML = catSVG({fur:'#f6a04d',fur2:'#d9772a',pattern:'tabby',eyes:'#3aa655',acc:'crown'}, 'happy');</script>
</body></html>`;

const browser = await chromium.launch();
const p = await browser.newPage({ viewport: { width: 512, height: 512 } });
for (const [file, pad, size] of [['icon-512.png', 20, 512], ['maskable-512.png', 80, 512], ['icon-192.png', 20, 192]]) {
  await p.setViewportSize({ width: 512, height: 512 });
  await p.setContent(page(pad));
  const buf = await p.locator('#i').screenshot();
  if (size === 512) { (await import('node:fs')).writeFileSync(`icons/${file}`, buf); continue; }
  const p2 = await browser.newPage({ viewport: { width: size, height: size } });
  await p2.setContent(`<img src="data:image/png;base64,${buf.toString('base64')}" style="width:${size}px;height:${size}px;display:block">`);
  (await import('node:fs')).writeFileSync(`icons/${file}`, await p2.screenshot());
  await p2.close();
}
await browser.close();
console.log('icons written');
