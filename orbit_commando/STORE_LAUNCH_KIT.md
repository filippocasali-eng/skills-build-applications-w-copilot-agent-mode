# Store launch kit (Google Play)

## 1. Before the first upload

1. **Package name.** `com.orbitcommando.orbit_commando` is the
   placeholder. Pick the final one now: it can never change after the
   first upload.
   - Change it in `android/app/build.gradle.kts` (`applicationId`,
     `namespace`).
   - Move the `MainActivity` package to match.
   - Update `PACKAGE_NAME` in `backend/functions`.
2. **Upload key.** Create it and keep it out of git:

   ```bash
   keytool -genkey -v -keystore ~/orbit-upload.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias upload
   ```

   Then create `android/key.properties` (git-ignored). The Gradle file
   picks it up automatically:

   ```properties
   storeFile=/home/you/orbit-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

   Enrol in Play App Signing: Google holds the app key and you keep the
   upload key.
3. **AdMob.**
   1. Create the app and two ad units (rewarded, interstitial).
   2. Put the App ID in `android/app/src/main/res/values/admob.xml`.
   3. Pass the unit ids with `--dart-define` (`MONETIZATION.md` §6).
   4. Complete the GDPR message in AdMob → Privacy & messaging.
4. **Products.** Create every SKU in `MONETIZATION.md` §1 with the same
   ids. Activate them.
5. **Version.** Bump `version:` in `pubspec.yaml` (`1.0.0+1`). The
   build number must grow with every upload.
6. **Build:**

   ```bash
   flutter build appbundle --release \
     --dart-define=ADMOB_REWARDED=ca-app-pub-XXXX/YYYY \
     --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-XXXX/ZZZZ
   # → build/app/outputs/bundle/release/app-release.aab
   ```

   Do **not** pass `TEST_STORE=true` to the Play build.

## 2. Testing tracks

1. **Internal testing:** up to 100 testers, available in minutes.
   - Add license testers (Setup → License testing) so purchases are free
     test purchases.
   - Verify:
     - buying the cartridge, gems and the season pass
     - restore after reinstall
     - a pending purchase (test card "slow")
     - refund handling
2. **Closed testing:** new personal developer accounts must run a closed
   test with at least 12 testers for 14 days before production access.
3. **Pre-launch report:** check the Robo crawl for crashes on low-end
   devices.

## 3. Content rating (IARC questionnaire)

| Topic | Answer |
|---|---|
| Violence | Cartoon/fantasy violence against non-human and human-like characters; no blood or gore |
| Language | Mild (in-game text); user chat → "Users interact" |
| Gambling-like | Loot boxes with paid currency: **yes**; simulated gambling: no |
| In-app purchases | Yes, including random items |
| Expected rating | ESRB T (US, launch market); PEGI 12–16 in Italy. The brief targets 16+, so set the target audience to 16+ in "Target audience and content". |

Not designed for children: do not opt into the Families programme.

## 4. Store listing

**App name** (30 chars max): `Orbit Commando '94`

**Short description** (80 chars max):
- IT: `Run & gun anni '90 con gravità planetaria: corri, salta e spara sui pianeti!`
- EN: `90s run & gun with planetary gravity: run, jump and blast around tiny planets!`

**Full description (IT):**

> Torna il 1994! ORBIT COMMANDO '94 è un run & gun in pixel art dove il pavimento è... rotondo.
>
> ★ GRAVITÀ PLANETARIA: corri attorno a piccoli pianeti, salta da un campo gravitazionale all'altro e fluttua a gravità zero.
> ★ 15 LIVELLI, 3 MONDI, 3 BOSS: dalla Cintura Tranquilla all'Imperatore Glorbo, passando per una lavatrice cosmica gigante.
> ★ 7 ARMI e 3 VEICOLI: laser, plasma, lanciafiamme, proiettili che rimbalzano... più un mech a molla, una moto-razzo e una navetta.
> ★ MODALITÀ ARCADE, BOSS RUSH e SFIDA SETTIMANALE contro il tuo fantasma.
> ★ ANIMA ANNI '90: filtro CRT, attract mode, codici segreti, juke-box chiptune e galleria.
> ★ GIOCO OFFLINE.
>
> Il primo mondo è gratis. La Cartuccia Completa sblocca tutto il gioco e rimuove la pubblicità con un unico acquisto. Contiene acquisti in-app opzionali, inclusi oggetti casuali (probabilità visibili nel gioco).

**Full description (EN):**

> It's 1994 again! ORBIT COMMANDO '94 is a pixel-art run & gun where the ground is... round.
>
> ★ PLANETARY GRAVITY: run around tiny planets, leap between gravity fields and float in zero-g.
> ★ 15 LEVELS, 3 WORLDS, 3 BOSSES — including a giant cosmic washing machine.
> ★ 7 WEAPONS & 3 VEHICLES: laser, plasma, flamethrower, ricochet shots, a spring mech, a rocket bike and a shuttle.
> ★ ARCADE MODE, BOSS RUSH and a WEEKLY CHALLENGE against your own ghost.
> ★ PURE 90s: CRT filter, attract mode, secret codes, chiptune juke-box and gallery.
> ★ PLAYS OFFLINE.
>
> World 1 is free. The Full Cartridge unlocks the whole game and removes ads with a single purchase. Optional in-app purchases include random items (odds shown in the game).

- **Category:** Action.
- **Tags:** Run & gun, Retro, Pixel art, Platformer, Shooter.
- **Contact:** a support e-mail is required. Use the privacy policy URL
  (host `PRIVACY.md`, adapted).

## 5. Graphics

| Asset | Spec | How to make it |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | Upscale the launcher icon ×8 with nearest neighbour (`tools/pixel_art`), on a dark-space background |
| Feature graphic | 1024×500 | Title logo plus a hero on a planetoid. Render a frame with `ORBIT_DUMP_DIR` (`test/widget/play_render_test.dart`) and compose it at 2× nearest. |
| Phone screenshots | 4–8, 16:9 landscape, at least 1080 px tall | `SHOT_DIR=… flutter test test/widget/` for menus, plus in-game frames from the dump test |
| Promo video (optional) | 30 s YouTube | Record the attract mode on a device with `adb shell screenrecord` |

Suggested screenshot captions: "Gravity is round" · "Ride a spring mech" ·
"Defeat the Cosmic Washer" · "CRT mode, like 1994" · "Weekly challenge vs.
your ghost".

## 6. Policy checklist

- [ ] Odds of random items disclosed before purchase (odds screen) ✔ in game
- [ ] Paid loot boxes off under 18 and in Belgium ✔ (`MONETIZATION.md` §3)
- [ ] No ads after deaths, rate-limited interstitials ✔
- [ ] UMP consent before ads ✔ (needs the AdMob GDPR message published)
- [ ] Data safety form filled (`PRIVACY.md`)
- [ ] Privacy policy URL live
- [ ] Target audience 16+ declared; not in the Families programme
- [ ] User-generated content policy: chat has a filter, report, block and
      mute ✔ (only when the backend is live; the offline demo is labelled)
- [ ] Account deletion path (only if accounts ship)
- [ ] Target API level: current Play requirement (`targetSdk` follows
      Flutter's default; check before upload)
- [ ] IP review: the character pack's look must be checked by counsel
      (see `DECISIONS.md` D15)

## 7. Launch week

1. Staged rollout: 10 % → 50 % → 100 % over 5 days, watching ANR and
   crash rates.
2. Day 1: the first weekly challenge goes live (it rotates automatically
   with the ISO week).
3. Watch the KPIs in `MONETIZATION.md` §11.
4. Reply to reviews in IT and EN within 48 h.
