# MULTIPLAYER PLAN — MIXO: Color Rush

## Cosa c'è già in v1 (fondamenta)

- **Simulazione deterministica** (`lib/game/sim/`): tick fisso a 60 Hz, nessuna dipendenza da Flutter, RNG `mulberry32` identico su VM e web (test con valore di riferimento), pista funzione solo di `(seed, params, colore iniziale, libreria pattern)`.
- **Replay compatti**: `seed + params + input impacchettati (tick << 2 | azione)`. Una partita di 2 minuti pesa pochi KB. `GameSimulation.fromReplay` riproduce punteggio e stato esatti (test).
- **Sfida Fantasma**: un secondo `GameSimulation` avanza in lockstep alimentato dal replay; il rendering mostra il fantasma semitrasparente e il delta di punti.
- **Interfaccia** `MultiplayerService { opponentFor(trackId); submit(trackId, replay, score) }` con implementazione `LocalGhostService`.

## v2 — Gare asincrone tra amici

**Obiettivo:** sfidare un amico sulla stessa pista e vedere il suo fantasma, senza chat e senza dati personali.

1. **Backend**: Firebase (Auth anonima + Firestore + Cloud Functions) oppure Supabase (anon auth + Postgres + Edge Functions). Scelta da fare in base al costo: con replay di pochi KB entrambi restano nel piano gratuito per molte migliaia di utenti.
2. **Identità**: solo **autenticazione anonima** legata al dispositivo. Nessuna email, nessun nome reale; si mostra il soprannome generato (lista chiusa, già in v1).
3. **Consenso genitoriale** (COPPA/GDPR-K): la funzione online è **spenta di default**; si attiva solo dall'area genitori dietro parental gate, con informativa dedicata. Va aggiornata la Data Safety (identificatore anonimo, replay di gioco) e la privacy policy.
4. **Gare via codice**: chi crea la sfida ottiene un codice di 6 caratteri (alfabeto senza ambiguità). L'amico inserisce il codice (tastiera limitata ai caratteri del codice, nessun testo libero).
5. **Server autorevole sul punteggio**: la Cloud Function ri-simula il replay (stesso codice Dart compilato per il server, o porta TypeScript validata con vettori di test generati dalla v1) e rifiuta punteggi non riproducibili → anti-cheat gratuito.
6. **Comunicazione**: solo emote predefinite (👍 🔥 😮 🎉) inviabili a fine gara. Nessun testo.
7. **Moderazione**: niente contenuti generati dagli utenti oltre al soprannome dalla lista e alle emote.
8. **Implementazione client**: `RemoteMultiplayerService implements MultiplayerService`, `trackId` = codice sfida, `opponentFor` scarica il replay, `submit` carica il proprio.

## v2.5 — 1v1 in tempo reale (stessa seed)

- Matchmaking per fascia di rating (l'AdaptiveDirector fornisce già una stima).
- Entrambi i client simulano localmente; si scambiano **solo input con tick** (lockstep a input ritardati di 3–4 tick, rollback leggero se serve). La simulazione è già deterministica, quindi non serve sincronizzare lo stato.
- Trasporto: WebSocket gestito (Firebase RTDB / Supabase Realtime) o un piccolo server dedicato; payload ~2 byte per input.
- In caso di disconnessione si continua contro il fantasma dell'avversario fino a quel momento.

## v3 — Leghe stagionali

- Stagioni di 4 settimane con **ricompense solo cosmetiche** e garantite (nessuna loot box).
- Divisioni per rating, promozione/retrocessione morbida (nessuna perdita di oggetti).
- Classifiche **per gruppi di 30 giocatori** con soprannomi generati; nessuna classifica globale nominativa per i più piccoli (in base alla fascia d'età dichiarata dal genitore, se la si introduce).
- Nessuna pressione a giocare ogni giorno: il punteggio di lega è la somma delle **migliori N partite**, non del numero di partite.

## Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| Desync tra piattaforme | RNG a 32 bit testato su VM e web; niente `double` non deterministici nella logica oltre a operazioni IEEE semplici; test di replay cross-platform in CI |
| Cheat | Ri-simulazione server del replay |
| Privacy minori | Opt-in genitore, auth anonima, nessun testo libero, dati minimi, retention breve dei replay (es. 30 giorni) |
| Costi | Replay di pochi KB, nessuno streaming video, funzioni server brevi |
