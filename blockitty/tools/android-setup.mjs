// Applies Blockitty's Android customizations to the Capacitor project:
// launcher icons + splash, portrait lock, AdMob app id, version, release signing.
// Env (all optional): VERSION_CODE, VERSION_NAME, ADMOB_APP_ID,
//   KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
import { cpSync, readFileSync, writeFileSync } from 'node:fs';

const env = process.env;
const ADMOB_TEST_APP = 'ca-app-pub-3940256099942544~3347511713';
const res = 'android/app/src/main/res';

cpSync('android-res/res', res, { recursive: true });
writeFileSync(`${res}/values/ic_launcher_background.xml`,
  '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FF8F8F</color>\n</resources>\n');

const mf = 'android/app/src/main/AndroidManifest.xml';
let xml = readFileSync(mf, 'utf8');
if (!xml.includes('screenOrientation')) xml = xml.replace('<activity', '<activity\n            android:screenOrientation="portrait"');
if (!xml.includes('com.google.android.gms.ads.APPLICATION_ID')) {
  xml = xml.replace('</application>', `    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${env.ADMOB_APP_ID || ADMOB_TEST_APP}"/>\n    </application>`);
}
writeFileSync(mf, xml);

const gradle = 'android/app/build.gradle';
let g = readFileSync(gradle, 'utf8');
g = g.replace(/versionCode \d+/, `versionCode ${Number(env.VERSION_CODE) || 1}`)
  .replace(/versionName "[^"]*"/, `versionName "${env.VERSION_NAME || '2.0.0'}"`);
if (env.KEYSTORE_PATH && !g.includes('signingConfigs')) {
  g = g.replace('    buildTypes {', `    signingConfigs {
        release {
            storeFile file("${env.KEYSTORE_PATH}")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {`).replace("proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'",
    "proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'\n            signingConfig signingConfigs.release");
}
writeFileSync(gradle, g);
console.log('android project configured', env.KEYSTORE_PATH ? '(release signing on)' : '(debug signing only)');
