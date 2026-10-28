/**
 * Renders the BattleQuiz launcher icons and splash screens for Android from the
 * logo SVG (same artwork as src/components/layout/Logo.tsx).
 * Usage: node scripts/generate-android-assets.mjs   (after `npx cap add android`)
 */
import { chromium } from "@playwright/test";
import path from "node:path";

const RES = path.resolve("android/app/src/main/res");
const BG = "#0B1020";

const MARK = `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a78bfa"/><stop offset="0.5" stop-color="#7c3aed"/><stop offset="1" stop-color="#06b6d4"/></linearGradient>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fde68a"/><stop offset="1" stop-color="#fbbf24"/></linearGradient>
  </defs>
  <path d="M24 2 42 9v14c0 11.5-7.6 19.6-18 23C13.6 42.6 6 34.5 6 23V9l18-7Z" fill="url(#s)"/>
  <path d="M24 5.5 39 11.3V23c0 9.6-6.2 16.5-15 19.6C15.2 39.5 9 32.6 9 23V11.3l15-5.8Z" fill="#0b1020" opacity="0.35"/>
  <circle cx="23" cy="23" r="10.5" fill="none" stroke="#f8fafc" stroke-width="3.4"/>
  <path d="M30 27.5 36.5 36" stroke="#f8fafc" stroke-width="3.6" stroke-linecap="round"/>
  <path d="M25.5 13.5 18.5 24.5h5l-2 9 7.5-12h-5.2l1.7-8Z" fill="url(#b)" stroke="#0b1020" stroke-width="0.8" stroke-linejoin="round"/>
</svg>`;

const GLOW = `radial-gradient(circle at 30% 20%, rgba(124,58,237,.55), transparent 60%), radial-gradient(circle at 80% 90%, rgba(6,182,212,.4), transparent 55%), ${BG}`;

const DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

function iconHtml(size, { shape, transparent, logoScale }) {
  const radius = shape === "round" ? "50%" : shape === "square" ? `${size * 0.22}px` : "0";
  return `<html><body style="margin:0;background:transparent">
    <div style="width:${size}px;height:${size}px;border-radius:${radius};overflow:hidden;display:grid;place-items:center;background:${transparent ? "transparent" : GLOW}">
      <div style="width:${size * logoScale}px;height:${size * logoScale}px">${MARK}</div>
    </div></body></html>`;
}

function splashHtml(w, h) {
  const s = Math.min(w, h);
  return `<html><body style="margin:0">
    <div style="width:${w}px;height:${h}px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:${s * 0.04}px;background:${GLOW};font-family:sans-serif">
      <div style="width:${s * 0.28}px;height:${s * 0.28}px">${MARK}</div>
      <div style="font-weight:900;font-size:${s * 0.09}px;color:#f8fafc;letter-spacing:-0.02em">Battle<span style="background:linear-gradient(100deg,#c4b5fd,#7c3aed 40%,#06b6d4);-webkit-background-clip:text;color:transparent">Quiz</span></div>
    </div></body></html>`;
}

const SPLASHES = {
  "drawable/splash.png": [480, 320],
  "drawable-land-mdpi/splash.png": [480, 320],
  "drawable-land-hdpi/splash.png": [800, 480],
  "drawable-land-xhdpi/splash.png": [1280, 720],
  "drawable-land-xxhdpi/splash.png": [1600, 960],
  "drawable-land-xxxhdpi/splash.png": [1920, 1280],
  "drawable-port-mdpi/splash.png": [320, 480],
  "drawable-port-hdpi/splash.png": [480, 800],
  "drawable-port-xhdpi/splash.png": [720, 1280],
  "drawable-port-xxhdpi/splash.png": [960, 1600],
  "drawable-port-xxxhdpi/splash.png": [1280, 1920],
};

const browser = await chromium.launch();
const page = await browser.newPage();

async function render(html, w, h, file, omitBackground) {
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(html);
  await page.screenshot({ path: path.join(RES, file), omitBackground, clip: { x: 0, y: 0, width: w, height: h } });
}

for (const [density, scale] of Object.entries(DENSITIES)) {
  const icon = Math.round(48 * scale);
  const fg = Math.round(108 * scale);
  await render(iconHtml(icon, { shape: "square", logoScale: 0.72 }), icon, icon, `mipmap-${density}/ic_launcher.png`, true);
  await render(iconHtml(icon, { shape: "round", logoScale: 0.66 }), icon, icon, `mipmap-${density}/ic_launcher_round.png`, true);
  // Adaptive icon foreground: keep the mark inside the 66dp safe zone.
  await render(iconHtml(fg, { shape: "none", transparent: true, logoScale: 0.5 }), fg, fg, `mipmap-${density}/ic_launcher_foreground.png`, true);
}
for (const [file, [w, h]] of Object.entries(SPLASHES)) await render(splashHtml(w, h), w, h, file, false);

await browser.close();
console.log("Android icons and splash screens generated.");
