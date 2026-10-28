# Limiti noti

## Dati
- **Fonti gratuite non ufficiali**: i prezzi giornalieri arrivano dall'endpoint chart pubblico di Yahoo Finance, non documentato e senza garanzie; può cambiare formato o bloccare le richieste. L'app lo dichiara e mostra provenienza e freschezza di ogni dato.
- **Nessun dato in tempo reale**: l'analisi lavora su barre giornaliere di sedute concluse (END_OF_DAY). Le quotazioni intraday, quando presenti, sono indicative e ritardate.
- **ETF UCITS (Xetra/LSE)**: l'ultima barra del giorno corrente è spesso incompleta e viene scartata, quindi i dati risultano un giorno indietro (STALE) — comportamento voluto.
- **Stooq** ora richiede una verifica anti-bot JavaScript: il provider è **BLOCKED** e disabilitato per impostazione predefinita (nessun aggiramento).
- **Alpha Vantage / Finnhub** richiedono una chiave personale; senza chiave sono NOT_CONFIGURED. Finnhub non è stato testato con una chiave reale.
- **Reddit** funziona solo con un client ID OAuth personale (app "installed"); senza, il Reddit Radar mostra *non configurato*. Non è stato testato con credenziali reali.
- **13F**: dati trimestrali con ritardo fino a 45 giorni; solo 8 gestori monitorati. **Form 4**: deposito entro 2 giorni lavorativi.
- **Fondamentali**: solo da SEC XBRL (società USA); gli ETF non hanno fondamentali. TER degli ETF non scaricato automaticamente.
- **Universo**: 47 titoli USA a grande capitalizzazione + ETF predefiniti; altri titoli USA sono cercabili tramite la mappa ticker SEC e scaricati su richiesta.

## Modelli
- I punteggi sono **euristici e non validati statisticamente** su lunghi periodi; la calibrazione nello Storico decisioni diventa significativa solo dopo mesi di snapshot.
- Il sentiment di notizie e Reddit è basato su parole chiave, non su modelli linguistici.
- Il backtest PAC/tranche usa solo la storia disponibile in cache (fino a circa 5 anni).

## Simulatore
- Barre giornaliere: la sequenza intraday è sconosciuta; gli esiti ambigui sono risolti prudentemente (vedi PAPER_TRADING_RULES.md).
- Nessuna modellazione di dividendi, tasse italiane (capital gain 26%, bollo), aste di apertura reali o liquidità del book.

## Piattaforma
- Aggiornamenti in background tramite WorkManager: Android (e One UI di Samsung con l'ottimizzazione batteria) può ritardarli o sospenderli. Per affidabilità impostare la batteria dell'app su *Senza restrizioni*.
- L'APK è firmato con una **chiave di sideload pubblica** inclusa nel repository (serve solo a mantenere la stessa firma tra aggiornamenti): non è una firma di produzione e non va usata per la pubblicazione su Play Store.
- Le chiavi API dell'utente sono cifrate con Android Keystore sul dispositivo; un'app Android non può comunque nascondere in modo sicuro un segreto condiviso, per questo l'APK **non contiene alcuna chiave**.
- Non testato su un telefono Samsung fisico (solo emulatore Android in CI): vedi IMPLEMENTATION_STATUS.md.
