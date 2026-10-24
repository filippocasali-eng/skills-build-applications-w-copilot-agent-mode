# PLAY STORE CHECKLIST — MIXO: Color Rush

## 1. Families Policy (Designed for Families)

| Requisito | Stato | Dove |
|---|---|---|
| Pubblico: bambini inclusi (6–8, 9–12, 13–15) | da dichiarare | Play Console → Pubblico di destinazione |
| Nessun SDK pubblicitario / analytics | ✅ nessuno nel `pubspec.yaml` | `AdProvider` = `NoAds` |
| Nessun advertising ID | ✅ permesso `AD_ID` rimosso con `tools:node="remove"` | `AndroidManifest.xml` |
| Nessun dato personale / account | ✅ profilo solo locale, soprannome generato | `PlayerProfile`, `Nickname` |
| Nessuna chat / testo libero | ✅ | — |
| Acquisti dietro parental gate | ✅ apertura negozio, ogni acquisto, ripristino, area genitori | `parental_gate.dart` |
| Nessuna loot box / ricompensa casuale a pagamento | ✅ tutto visibile e deterministico | `Catalog` |
| Nessun pay-to-win | ✅ solo cosmetici | GAME_DESIGN §8 |
| Prezzi in valuta reale | ✅ prezzo formattato da Google Play | `StoreProduct.price` |
| Nessun link esterno senza gate | ✅ nessun link esterno nell'app | — |
| Nessuna notifica push | ✅ nessun permesso `POST_NOTIFICATIONS` | — |
| Backup cloud dei dati disattivato | ✅ `allowBackup=false`, `data_extraction_rules.xml` | manifest |
| Permessi minimi | ✅ `INTERNET` (billing) e `VIBRATE` (+ `BILLING` aggiunto dalla libreria) | manifest |
| Contenuti adatti | ✅ niente violenza, errori "morbidi" | — |

## 2. Questionario "Pubblico di destinazione e contenuti"

- Fasce d'età: **6-8, 9-12, 13-15**.
- L'app attira i bambini: **Sì** → partecipazione al programma Families.
- Annunci: **No, la mia app non contiene annunci**.
- Funzionalità social / comunicazione tra utenti: **No**.
- Accesso con account: **No**.

## 3. Sicurezza dei dati (Data Safety)

- **Dati raccolti: nessuno.**
- **Dati condivisi: nessuno.**
- Pratiche di sicurezza: "I dati non vengono raccolti". La crittografia in transito non si applica (l'app non trasmette dati propri; il billing è gestito da Google Play).
- Eliminazione dati: i progressi sono solo sul dispositivo; "Azzera tutti i progressi" nell'area genitori o disinstallazione.

> Nota: gli acquisti passano da Google Play; Google li dichiara come proprio trattamento. L'app non riceve dati di pagamento.

## 4. Classificazione contenuti (IARC)

Risposte attese: nessuna violenza, nessun linguaggio, nessun contenuto sessuale, nessun gioco d'azzardo, **acquisti digitali: Sì**, interazione tra utenti: No, condivisione posizione: No.
Risultato atteso: **PEGI 3 / ESRB Everyone / USK 0**, con nota "Acquisti in-app".

## 5. Scheda dello store

### Italiano

**Titolo (≤30):** MIXO: Color Rush
**Breve descrizione (≤80):** Corri, mescola i colori e attraversa le porte giuste! Facile, veloce, colorato.
**Descrizione completa:**
> Mixo è un blob gelatinoso che prende il colore di ciò che tocca. Corri nel tunnel e passa solo dalle porte del tuo colore!
>
> 🎨 MESCOLA I COLORI — Rosso + Blu = Viola! Più vai avanti, più i mix diventano furbi.
> ⚡ SEMPRE PIÙ VELOCE — combo fino a ×8, "per un pelo!", slow motion.
> 🧠 SI ADATTA A TE — la difficoltà cresce con te: facile per chi inizia, una sfida vera per chi è bravo.
> 📅 SFIDA DEL GIORNO — una pista nuova ogni giorno, uguale per tutti. Se salti un giorno, nessun problema!
> 🎓 ACCADEMIA — 8 lezioni brevi per imparare tutte le regole.
> 👻 SFIDA FANTASMA — batti la tua corsa migliore.
> 🧢 COLLEZIONE — oltre 20 aspetti per Mixo, scie e 7 mondi da sbloccare giocando.
>
> PENSATO PER LE FAMIGLIE
> • Nessuna pubblicità, nessuna chat, nessun account.
> • Nessun dato personale raccolto.
> • Acquisti solo estetici, protetti da verifica per adulti.
> • Simboli per ogni colore (adatto ai daltonici).
> • Pausa consigliata dopo 30 minuti e limite giornaliero per i genitori.

### English

**Title:** MIXO: Color Rush
**Short description:** Run, mix colours and dash through the right gates! Easy, fast, colourful.
**Full description:**
> Mixo is a jelly blob that takes the colour of whatever it touches. Race through the tunnel and only pass gates of your own colour!
>
> 🎨 MIX COLOURS — Red + Blue = Purple! The further you go, the trickier the mixes.
> ⚡ FASTER AND FASTER — combos up to ×8, close calls, slow motion.
> 🧠 ADAPTS TO YOU — gentle for beginners, a real challenge for experts.
> 📅 DAILY CHALLENGE — a new track every day, the same for everyone. Skip a day? No problem!
> 🎓 ACADEMY — 8 short lessons to learn every rule.
> 👻 GHOST CHALLENGE — beat your own best run.
> 🧢 COLLECTION — 20+ looks for Mixo, trails and 7 worlds to unlock by playing.
>
> MADE FOR FAMILIES
> • No ads, no chat, no accounts.
> • No personal data collected.
> • Cosmetic-only purchases protected by a grown-up check.
> • A symbol for every colour (colour-blind friendly).
> • Break reminder after 30 minutes and a daily limit for parents.

### Idee per gli screenshot (1080×1920, 8 immagini)

1. Mixo al centro del tunnel con porte colorate — testo "Passa dal TUO colore!"
2. Ricetta visiva Rosso + Blu = Viola con una porta viola in arrivo — "Mescola i colori!"
3. Combo ×8 con linee warp — "Sempre più veloce!"
4. Schermata risultati con barra XP e consiglio del Coach — "Impari giocando"
5. Collezione con 6 Mixo diversi — "Oltre 20 aspetti da sbloccare"
6. Mappa dell'Accademia — "8 lezioni per diventare campione"
7. Fantasma semitrasparente accanto a Mixo — "Batti il tuo fantasma"
8. Area genitori — "Niente pubblicità. Niente chat. Nessun dato."

Grafica: `store/icon_512.png` (icona hi-res). Feature graphic 1024×500 da creare con Mixo + titolo.

## 6. Prima dell'invio

- [ ] Creare i 4 prodotti in-app non consumabili e fissare i prezzi.
- [ ] Pubblicare la privacy policy a un URL pubblico (es. GitHub Pages) e inserirla in Play Console e nella scheda.
- [ ] Email di contatto dello sviluppatore.
- [ ] Test interno con account license-tester: acquisto, annullamento, ripristino, acquisti disattivati dal genitore.
- [ ] Verifica su emulatore API 24 e API 36 (vedi sotto).
- [ ] Profiling su dispositivo da 2 GB di RAM (vedi PERFORMANCE.md).
- [ ] Revisione legale di PRIVACY_POLICY.md.

## Stato criteri di accettazione v1

| Criterio | Stato | Evidenza |
|---|---|---|
| Installazione/avvio su API 24 e ultima API | ⏳ da verificare su emulatore | `minSdk = 24`; la build APK/AAB gira su GitHub Actions |
| Home → partita in 1 tap; game over → nuova partita in 1 tap e < 1 s | ✅ | test widget/integration misurano il restart (< 1 s, nessun caricamento) |
| 60 FPS stabili | ⏳ da misurare su dispositivo | budget e procedura in PERFORMANCE.md; nessuna allocazione di oggetti di gioco nel loop |
| 4 modalità funzionanti | ✅ | Corsa Libera, Giorno, Accademia, Fantasma (+ onboarding) |
| Mix corretti con simbolo | ✅ | `color_system_test.dart` (tabella completa) |
| Difficoltà che si adatta in modo misurabile | ✅ | `adaptive_director_test.dart` + log `[AdaptiveDirector]` in debug |
| Progressione persistente dopo riavvio | ✅ | `persistence_test.dart` (round-trip, migrazioni, backup) |
| Billing con SKU di test, parental gate, ripristino | ✅ codice / ⏳ test su Play | `PlayBillingService`, `parental_gate_test.dart` |
| Nessuna rete per giocare; solo INTERNET e VIBRATE | ✅ | manifest; gioco 100% offline |
| Localizzazione IT/EN completa | ✅ | 153 stringhe da un'unica tabella + contenuti localizzati |
| Pausa benessere e limite giornaliero | ✅ | `persistence_test.dart`, schermate dedicate |
| AAB release firmata | ✅ workflow CI (chiave debug se mancano i secret) | `.github/workflows/mixo-android.yml` |
