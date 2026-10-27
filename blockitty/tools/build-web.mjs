// Copies the static game into www/ for the Capacitor Android wrapper.
import { cpSync, rmSync, mkdirSync } from 'node:fs';

rmSync('www', { recursive: true, force: true });
mkdirSync('www');
for (const p of ['index.html', 'privacy.html', 'manifest.webmanifest', 'sw.js', 'css', 'js', 'icons', 'fonts']) cpSync(p, `www/${p}`, { recursive: true });
console.log('www/ ready');
