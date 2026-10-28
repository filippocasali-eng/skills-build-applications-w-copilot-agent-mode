# Guida d'uso

## Primo avvio
1. **Benvenuto** → leggi l'avvertenza: l'app non dà consigli personalizzati e non invia ordini reali.
2. **Capitale**: inserisci il capitale virtuale del conto **ETF** e del conto **Trading** (possono restare 0 €).
3. **Profilo di rischio** e **fonti dati** (le chiavi personali sono facoltative e si possono aggiungere dopo in Impostazioni → Fonti dati).
4. Fine: si apre la schermata **Oggi**. Premi **AGGIORNA MERCATO** per scaricare i dati (la prima volta può richiedere qualche minuto).

## Schede principali
- **Oggi**: regime di mercato, punteggi con pulsante *Perché?*, rischi, migliori opportunità oppure **NESSUN TRADE**, miglior ETF, notizie e qualità dei dati. Il menu in alto apre Notizie, Insider/13F, Reddit, Watchlist, Diario, Storico decisioni, Fonti dati e Impostazioni.
- **ETF**: elenco UCITS con punteggio e tre decisioni separate (accumulo lungo periodo, acquisto tattico, rischio di concentrazione). Nel dettaglio: grafico, indicatori e confronto storico *unica soluzione vs PAC vs 3/6 tranche*.
- **Top Trade**: classifica dei titoli USA con punteggio, copertura dati, fiducia, zona d'ingresso, stop, target e rapporto rendimento/rischio. Se nessun titolo supera le soglie appare **NESSUN TRADE**: è un risultato valido.
- **Simulatore**: ordini virtuali (mercato, limite, stop, stop-limite, bracket). Il ticket mostra in anteprima quantità massima, rischio, costi e vincoli violati.
- **Portafoglio**: conti ETF e Trading separati, posizioni, P&L, curva di equity, statistiche, depositi/prelievi/trasferimenti.

## Leggere i dati
Ogni dato mostra la **fonte** e la **freschezza**: LIVE, RITARDATO, FINE GIORNATA, VECCHIO (STALE), CACHE, NON DISPONIBILE. Quando la copertura è bassa, la fiducia del punteggio scende e l'app lo dice esplicitamente.

## Aggiornamenti e avvisi
- Aggiornamento manuale con **AGGIORNA MERCATO** (annullabile); automatico tramite WorkManager secondo le impostazioni (richiede connessione e batteria non scarica).
- Avvisi locali: soglie di prezzo/punteggio, acquisti insider e trimestrali in arrivo sui titoli in watchlist, ordini simulati eseguiti, promemoria giornaliero.
- Offline l'app usa la cache e segnala l'aggiornamento come **parziale**.

## Backup
Impostazioni → **Esporta** crea un file cifrato con password (AES-256-GCM). **Importa** ripristina conti, ordini, diario e watchlist. Le chiavi API non vengono esportate.

## Chiavi personali (facoltative)
- **Alpha Vantage** / **Finnhub**: chiave gratuita registrandosi sui rispettivi siti.
- **Reddit**: crea un'app di tipo *installed app* su reddit.com/prefs/apps e incolla il *client ID*.
- **SEC**: inserisci un contatto (email) per l'intestazione User-Agent richiesta dalla SEC.
Le chiavi restano sul telefono, cifrate con Android Keystore.
