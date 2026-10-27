// Production build: bundles all modules into one file, minifies and obfuscates
// it (no readable source ships in the APK or on the website), then writes www/.
import { cpSync, rmSync, mkdirSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { build } from 'esbuild';
import JavaScriptObfuscator from 'javascript-obfuscator';

const OUT = 'www';
rmSync(OUT, { recursive: true, force: true });
mkdirSync(`${OUT}/js`, { recursive: true });
for (const p of ['privacy.html', 'manifest.webmanifest', 'css', 'icons', 'fonts']) cpSync(p, `${OUT}/${p}`, { recursive: true });

const bundle = await build({
  entryPoints: ['js/main.js'], bundle: true, format: 'iife', minify: true, write: false,
  target: ['chrome90'], legalComments: 'none', sourcemap: false,
});
const code = JavaScriptObfuscator.obfuscate(bundle.outputFiles[0].text, {
  compact: true,
  identifierNamesGenerator: 'hexadecimal',
  renameGlobals: false,
  stringArray: true,
  stringArrayEncoding: ['base64'],
  stringArrayThreshold: 0.75,
  stringArrayRotate: true,
  stringArrayShuffle: true,
  splitStrings: true,
  splitStringsChunkLength: 8,
  controlFlowFlattening: true,
  controlFlowFlatteningThreshold: 0.15, // keep the game loop fast
  deadCodeInjection: false,
  selfDefending: true,
  numbersToExpressions: true,
  transformObjectKeys: false,
  unicodeEscapeSequence: false,
}).getObfuscatedCode();
const header = '/*! Blockitty (c) 2026 Filippo Casali. All rights reserved. Unauthorized copying, modification or redistribution is prohibited. */\n';
writeFileSync(`${OUT}/js/app.js`, header + code);

const html = readFileSync('index.html', 'utf8').replace('<script type="module" src="js/main.js"></script>', '<script src="js/app.js" defer></script>');
writeFileSync(`${OUT}/index.html`, html);

// Service worker with the real file list of this build.
const files = [];
const walk = (d) => { for (const f of readdirSync(d)) { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else files.push(p.slice(OUT.length + 1)); } };
walk(OUT);
const sw = readFileSync('sw.js', 'utf8').replace(/const ASSETS = \[[\s\S]*?\];/, `const ASSETS = ${JSON.stringify(['./', ...files.filter((f) => !f.startsWith('icons/screenshot'))])};`);
writeFileSync(`${OUT}/sw.js`, sw);
console.log(`www/ ready: ${files.length} files, app.js ${(code.length / 1024).toFixed(0)} KB (bundled + obfuscated)`);
