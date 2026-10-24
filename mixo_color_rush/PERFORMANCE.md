# PERFORMANCE — MIXO: Color Rush

Obiettivo: **60 FPS stabili** su un dispositivo di fascia bassa (2 GB RAM), APK < 40 MB.

## Scelte già fatte nel codice

| Area | Scelta |
|---|---|
| Simulazione | Dart puro, passo fisso 1/60 s, max 6 passi per frame (niente "spirale della morte"), dt limitato a 0,1 s |
| Pista | `RowPool` (64 file preallocate), celle mutabili riutilizzate; il generatore usa uno scratch buffer fisso |
| Validatore | due array `double` preallocati per gli stati; nessuna allocazione per chunk oltre alle liste di scelta del pattern |
| Eventi | ring di 64 `SimEvent` riutilizzati |
| Particelle | struct-of-arrays (`Float32List`) da 320 elementi, nessun oggetto per particella |
| Rendering | `Paint`/`Path` preallocati e riusati; shader del cielo/pavimento ricreati solo al resize o al cambio tema; testi dei popup in cache (`TextPainter`) |
| HUD | Flutter, ricostruito solo quando i valori cambiano (`ValueNotifier<HudData>` con `==`) |
| Audio | pool di player per gli SFX frequenti; la musica cambia traccia solo al cambio di intensità |
| Asset | nessuna immagine bitmap nel gioco (tutto vettoriale), audio WAV 22 kHz mono ≈ 1,2 MB totali |

Allocazioni residue note nel loop: oggetti `Color` immutabili creati per gli alpha (molto economici) e `HSVColor` per gli anelli del tunnel (15 per frame). Se il profiling li mostrasse rilevanti: cache di 64 colori per anello.

## Procedura di misura (da eseguire su dispositivo)

1. `flutter run --profile` su un dispositivo reale economico (es. 2 GB RAM, Android 8/9).
2. DevTools → **Performance**: 3 partite da 90 s in Corsa Libera, rating alto (velocità massima, warp attivo, particelle).
3. Annotare: frame UI/raster medi e p90, jank (> 16 ms), memoria (DevTools → Memory) prima e dopo 10 partite.
4. `flutter build apk --analyze-size --target-platform android-arm64` per la dimensione.
5. Riportare i risultati nella tabella sotto.

| Dispositivo | Android | FPS medio | p90 frame (ms) | Jank % | RAM (MB) | Note |
|---|---|---|---|---|---|---|
| *da misurare* | | | | | | |

> Nell'ambiente di sviluppo cloud non era disponibile né un dispositivo né l'Android SDK, quindi la tabella è vuota: **i 60 FPS non sono ancora stati verificati**. La build web di anteprima gira fluida in Chromium desktop, ma non è un dato rappresentativo.

## Dimensione

Stima release AAB: motore Flutter (~5–7 MB per ABI) + codice Dart (~3 MB) + asset (~1,3 MB). Ampiamente sotto i 40 MB; il workflow CI stampa le dimensioni reali nello step "Sizes".
