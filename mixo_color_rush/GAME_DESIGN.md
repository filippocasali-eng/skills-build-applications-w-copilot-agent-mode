# GAME DESIGN — MIXO: Color Rush

**Pitch.** Mixo, un blob gelatinoso, corre in un tunnel infinito. Passa solo dalle porte del suo colore. Le gocce lo ricolorano e, più avanti, **mescolano** il suo colore. Facile da imparare (un bambino di 6 anni capisce in 5 secondi), difficile da padroneggiare (mix a più livelli ad alta velocità).

## 1. Controlli (un dito)

| Gesto | Azione | Disponibile |
|---|---|---|
| Swipe ← / → (soglia 22 dp, scatta senza alzare il dito) | cambio corsia | sempre |
| Tap | salto (scavalca ostacoli bassi) | livello giocatore ≥ 5 |
| Swipe ↓ | tuffo: ×1,35 velocità per 0,4 s | livello ≥ 10 |
| Tap a sinistra/destra dello schermo | cambio corsia (modalità accessibile) | Impostazioni |

Buffer input: 7 tick (≈120 ms) per i comandi che non possono partire subito (salto durante un salto). Tutto lo schermo è area di gesto.

## 2. Regole

- Porta del colore giusto → +100 × moltiplicatore, combo +1, piccolo boost di velocità (+0,6 u/s che decade).
- Porta sbagliata / ostacolo → −1 cuore, combo azzerata, 1 s di invulnerabilità (Mixo lampeggia).
- 3 cuori. A 0: game over. Corsia vuota = nessun effetto (si può schivare).
- **Per un pelo!** Cambio corsia ≤ 200 ms prima di una fila che, nella corsia lasciata, avrebbe fatto danno → +50.
- Salto su ostacolo basso +25; goccia raccolta +10 (entrambi × moltiplicatore).

### Combo

| Porte consecutive | 0–4 | 5–11 | 12–21 | 22–34 | 35+ |
|---|---|---|---|---|---|
| Moltiplicatore | ×1 | ×2 | ×3 | ×5 | ×8 |

A ×5 e ×8: slow motion di 300 ms, popup "COMBO ×N", vibrazione forte.

## 3. Colori

| Colore | Simbolo | Composizione |
|---|---|---|
| Rosso | cerchio | primario |
| Giallo | triangolo | primario |
| Blu | quadrato | primario |
| Arancione | rombo | R + G |
| Verde | stella | G + B |
| Viola | esagono | R + B |
| Marrone ("fango") | croce | tutti e tre — nessuna porta marrone |

**Mescolamento** (bitmask dei primari, `ColorSystem.mix`):
- stesso colore → invariato · due primari diversi → secondario
- secondario + un suo primario → invariato · secondario + primario mancante → **Marrone**
- Marrone + qualsiasi colore → Marrone (serve la **Bianca**)

**Gocce speciali:** Bianca = torna al colore base (rosso) · Arcobaleno = passa da qualsiasi porta per 3 s · Inverti = complementare (R↔Verde, G↔Viola, B↔Arancione).

Simboli visibili di default su porte, gocce, Mixo e HUD (accessibilità daltonismo, D-016).

## 4. Pista e generazione

- Simulazione a 60 Hz; distanza in "unità". Velocità `v(d) = base + (max−base)·(1−e^(−d/1800))`.
- Distanza fra file = `gap(d) · v(d) · moltiplicatore della riga`, con `gap` che scende da `gapSeconds` a `minGapSeconds` con la stessa rampa.
- Chunk = un **pattern** (1–5 file, ~3 s) da `assets/data/patterns/*.json` (51 pattern, tier 0–5). Token: `T` porta del colore pianificato, `N` esca, `d` goccia che cambia colore, `b` goccia trappola, `W/R/I` speciali, `O/o` ostacolo alto/basso, `.` libero.
- Ogni chunk è **provato risolvibile** (`ChunkValidator`) con cambi corsia limitati a 1 ogni 0,18 s; test: 10.000 chunk verificati da un risolutore brute-force indipendente.
- I primi 2 chunk sono sempre tier 0 (riscaldamento).

## 5. Difficoltà adattiva (tabella `difficulty_config.json`)

| Rating | Vel. base→max | Gap s (inizio→fine) | Tier max | Novità | Strict |
|---|---|---|---|---|---|
| 0 | 7,5 → 14 | 1,50 → 1,00 | 0 | porte + gocce (sostituiscono) | sì |
| 100 | 8 → 16 | 1,35 → 0,95 | 1 | ostacoli | sì |
| 250 | 9 → 18 | 1,25 → 0,85 | 2 | **mescolamento** + Bianca | sì |
| 400 | 10 → 20 | 1,15 → 0,78 | 3 | porte secondarie come esche | sì |
| 550 | 11 → 22 | 1,05 → 0,72 | 4 | Arcobaleno, Inverti | no |
| 700 | 12 → 24 | 1,00 → 0,66 | 5 | mix a catena | no |
| 850 | 13 → 26 | 1,00 → 0,68 | 5 | **ESPERTO: 5 corsie** | no |

Valori numerici interpolati fra stadi. Rating iniziale 60, aggiornamento a fine partita libera:

`Δ = 40 · clamp((successo − 0,775) / 0,075, −1,5, 1,5)` + 6 se nella fascia 70–85% + 15 se partita ≥ 120 s + 40 se successo ≥ 95% e ≥ 60 s + 10 se reazione < 450 ms; −60 dopo 3 sconfitte consecutive sotto i 30 s.

**Adattamento live** (solo Corsa Libera): sulle ultime 16 porte, successo > 85% → tier obiettivo fino a +1,5 e gap −12%; < 70% → tier −1,5 e gap +12%.

**Nuova meccanica** → card "NOVITÀ!" di 2 s all'inizio della partita (gioco in pausa, tap per saltarla).

## 6. Modalità

| Modalità | Seed | Parametri | Note |
|---|---|---|---|
| Corsa Libera | casuale | AdaptiveDirector | modalità principale |
| Sfida del Giorno | `mixo-daily-AAAA-MM-GG` | fissi (`daily`) | record del giorno, nessuna streak |
| Accademia | fisso per lezione | per lezione, traguardo a distanza | 8 lezioni; stelle = cuori rimasti |
| Sfida Fantasma | dal replay migliore | fissi (`ghost`) | fantasma semitrasparente, delta punti in HUD |
| Onboarding | fisso | pratica (niente danni), 230 unità | prima apertura, poi subito Corsa Libera |

Le prime 2 lezioni dell'Accademia sbloccano Sfida del Giorno e Fantasma; la Corsa Libera è sempre disponibile (D-018).

## 7. Progressione

- **XP per partita** = clamp(10 + punti/40 + porte·2 + secondi/4, 10, 600). Anche le partite perse danno XP.
- **XP per livello** = 100 + (livello−1)·50. Livello max 50. Level-up: +10 stelle.
- **Stelle per partita** = min(punti/500, 20) (+3 se lezione completata). Missioni +10–30, trofei +10–100.
- **Sblocchi a livello:** 2 Berretto + Scintille · 3 Fiocco + Oceano · 4 Occhiali + Bolle · 5 **salto** + Foresta · 6 Fiore · 7 Cuoricini · 8 Corona · 9 Vulcano · 10 **tuffo** · 11 Fuoco · 12 Mago · 15 Ninja.
- **Con stelle:** Stelline 100, Cuffie 150, Antenne 200, Note 200, Caramelle 200, Cuoco 250, Cornetti 300, Neon City 350, Pirata 400, Arcobaleno 400, Aureola 500.
- **Missioni:** 3 attive, generate in modo deterministico dal contatore e dal livello; si rinnovano solo quando completate.
- **Trofei:** 26 (vedi `Achievement`).

## 8. Monetizzazione (solo estetica)

| Prodotto (non consumabile) | Contenuto |
|---|---|
| `mixo_supporter_pack` | 3 skin (Re d'oro, Astronauta, Draghetto) + mondo Aurora + distintivo |
| `mixo_pack_dino` | Dino, Stego + scia Foglie |
| `mixo_pack_space` | Alieno, Robot + scia Cometa |
| `mixo_pack_sweet` | Cupcake, Coniglietto + scia Confettini |

Contenuto mostrato per intero, prezzo reale Google Play, parental gate all'apertura del negozio e a ogni acquisto/ripristino, disattivabile dall'area genitori.

## 9. Benessere

- Dopo 30 minuti di gioco continuo (una pausa > 5 min azzera il conteggio): "Ottima sessione! Fai una pausa?" con *Faccio una pausa* / *Continua*.
- Limite giornaliero impostabile dal genitore (15–120 min, +15 min extra): a limite raggiunto la partita in corso si conclude, poi "Per oggi basta!".
- Niente notifiche, niente timer FOMO, niente streak, niente valuta premium.

## 10. Game feel

Particelle in pool (320) · scossa schermo sugli errori (disattivabile con "Effetti più calmi") · slow-mo · linee warp oltre 14 u/s · FOV dinamico (focale 7 → 5,2) · squish di Mixo a ogni cambio corsia · espressioni (felice, sorpreso, stordito) · musica a 3 strati che cambia con la velocità e playback rate 0,95–1,2.
