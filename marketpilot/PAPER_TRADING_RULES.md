# Regole del simulatore (paper trading)

Il simulatore **non invia mai ordini reali** a nessun broker. Esegue ordini virtuali su **barre giornaliere reali** già memorizzate nella cache locale. Codice: `domain/papertrading/PaperTradingEngine.kt`, test: `PaperTradingEngineTest` (18 casi).

## Conti

- Due conti indipendenti: **ETF** e **Trading**. Capitale iniziale **0 €** finché l'utente non lo imposta (onboarding o Portafoglio → Deposita).
- Registro contabile **append-only** (depositi, prelievi, trasferimenti manuali tra conti, acquisti, vendite, commissioni, costi di cambio). Le posizioni sono sempre ricostruibili dal registro.
- Il contante per gli acquisti in attesa viene **riservato** al momento dell'inserimento dell'ordine.
- Nessuna leva, nessuna vendita allo scoperto: una vendita non può superare la quantità posseduta.

## Tempo e assenza di look-ahead

1. Ogni ordine ha una **prima seduta eleggibile**: la prima seduta la cui apertura avviene *dopo* la creazione dell'ordine (calendari NYSE/Nasdaq, Xetra, LSE con festività).
2. Si usano solo barre di **sedute concluse** (con margine di assestamento di 30 minuti dopo la chiusura).
3. Se manca la barra di una seduta per uno strumento, la valutazione di quello strumento **si ferma** in attesa dei dati, non salta la seduta.
4. Gli ordini sono elaborati in ordine cronologico su tutti gli strumenti, così i controlli di cassa sono coerenti.

## Prezzi di esecuzione

| Tipo | Regola |
|---|---|
| Mercato | Apertura della prima seduta eleggibile ± mezzo spread ± slippage |
| Limite (acquisto) | Se l'apertura è ≤ limite: apertura (mai peggio del limite). Altrimenti esegue al limite solo se il minimo della barra è **strettamente sotto** il limite (il prezzo deve averlo attraversato) |
| Limite (vendita) | Simmetrico, con il massimo strettamente sopra il limite |
| Stop | Gap oltre lo stop → esecuzione **all'apertura** (peggiore dello stop). Altrimenti allo stop + slippage aggiuntivo per stop, limitato al range della barra |
| Stop-limite | Lo stop attiva l'ordine; se nella stessa barra serve un ritorno al limite dopo l'attivazione, la sequenza è ignota → **nessuna esecuzione** su quella barra |
| Bracket / OCO | Stop loss e take profit collegati; quando uno esegue l'altro viene annullato |

Costi predefiniti (modificabili in Impostazioni): commissioni 0 € (da impostare secondo il proprio broker), mezzo spread 0,05%, slippage 0,05%, slippage extra stop 0,10%, costo cambio 0%. Il cambio EUR/valuta usa i tassi di riferimento BCE del giorno (o l'ultimo disponibile precedente).

## Esiti ambigui (politica prudente)

Una barra giornaliera non rivela l'ordine degli eventi intraday. Quando sono possibili più esiti:

- **OCO con stop e target entrambi toccati nella stessa barra** → si assume prima lo **stop** (esito peggiore); l'esecuzione è marcata *ambigua*.
- **Ingresso e stop nella stessa barra** dell'ingresso → si applica l'uscita in stop (politica CONSERVATIVE), marcata ambigua.
- Gli esiti ambigui sono mostrati con un'etichetta nel registro ordini e conteggiati nelle statistiche.

## Esecuzioni parziali

Una singola barra può eseguire al massimo il **10% del volume** della seduta (modello esplicito); il resto rimane in attesa (stato *Parzialmente eseguito*; modello disattivabile in Impostazioni) e il contante riservato viene ridotto proporzionalmente.

## Scadenze e stati

`Nuovo → In attesa → (Parzialmente eseguito) → Eseguito | Annullato | Scaduto | Rifiutato`. Gli ordini DAY scadono dopo la prima seduta eleggibile; i GTC possono avere una data di scadenza. Un ordine viene rifiutato con motivazione se la cassa non basta, se viola i limiti di rischio o se mancano dati.

## Limiti di rischio applicati al ticket

Rischio per trade 0,5% del conto, esposizione massima per posizione 15%, massimo 3 posizioni aperte, rischio aggregato aperto 2%, rapporto rendimento/rischio minimo 2,0, quota massima del volume medio 1%. Il ticket mostra quale vincolo limita la quantità.

## Statistiche

Rendimento, P&L realizzato/non realizzato, win rate, profit factor, expectancy, drawdown massimo, curva di equity confrontata con SPY/QQQ/VWCE. Le statistiche sono calcolate solo su operazioni simulate e **non predicono risultati reali**.
