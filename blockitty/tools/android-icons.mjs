// Replaces Capacitor's default launcher icons with the Blockitty icon.
import { copyFileSync, readdirSync, rmSync, existsSync } from 'node:fs';

const res = 'android/app/src/main/res';
for (const dir of readdirSync(res).filter((d) => d.startsWith('mipmap-') && !d.includes('anydpi'))) {
  for (const name of ['ic_launcher.png', 'ic_launcher_round.png', 'ic_launcher_foreground.png']) {
    if (existsSync(`${res}/${dir}/${name}`)) copyFileSync('icons/icon-192.png', `${res}/${dir}/${name}`);
  }
}
rmSync(`${res}/mipmap-anydpi-v26`, { recursive: true, force: true });
console.log('android icons replaced');

// Portrait-only, like every top casual puzzle game.
import { readFileSync, writeFileSync } from 'node:fs';
const mf = 'android/app/src/main/AndroidManifest.xml';
const xml = readFileSync(mf, 'utf8');
if (!xml.includes('screenOrientation')) writeFileSync(mf, xml.replace('<activity', '<activity\n            android:screenOrientation="portrait"'));
