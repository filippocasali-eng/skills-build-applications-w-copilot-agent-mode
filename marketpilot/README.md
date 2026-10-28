# MarketPilot AI

App Android nativa di **supporto alle decisioni di investimento** per un investitore italiano che segue azioni USA, S&P 500, Nasdaq 100, VWCE e altri ETF UCITS. Include un **simulatore di ordini (paper trading)** con due conti virtuali separati (ETF e Trading).

> ⚠️ Nessuna raccomandazione garantisce profitti. L'app non invia ordini reali: tutta l'operatività è simulata. Le fonti gratuite possono essere incomplete, ritardate o interrompersi.

## Caratteristiche principali

| Area | Cosa fa |
|---|---|
| **Oggi** | Regime di mercato (FAVOREVOLE / NEUTRALE / CAUTELA / RISCHIO ELEVATO / DATI INSUFFICIENTI), tre punteggi con spiegazione "Perché?", rischi, migliori opportunità o **NESSUN TRADE**, miglior ETF, notizie, qualità dei dati, pulsante **AGGIORNA MERCATO** |
| **ETF Radar** | ETF UCITS (VWCE, VGWL, EUNL, SXR8, VUAA, CSPX, SXRV) con ISIN, borsa, valuta, indicatori, Opportunity Score e tre decisioni distinte (accumulo di lungo periodo, acquisto tattico, concentrazione). Confronto storico unica soluzione / PAC / 3 / 6 tranche su prezzi reali |
| **Top Trade USA** | Classifica quantitativa (momentum, struttura tecnica, fondamentali SEC, insider, 13F, Reddit, news, liquidità) con punteggio, **copertura**, **fiducia**, rischio, zona di ingresso, stop, target, rapporto rendimento/rischio, catalizzatore, scenario negativo |
| **Scheda titolo** | Grafico a candele interattivo con SMA, Bande di Bollinger, supporti/resistenze, RSI, MACD; fondamentali SEC XBRL; insider Form 4; 13F; Reddit; notizie; scenari rialzista/base/ribassista |
| **Insider / 13F** | Acquisti sul mercato (codice P) separati da assegnazioni, esercizi di opzioni, vendite e piani 10b5-1; Insider Conviction Score; posizioni di 8 gestori istituzionali con ritardo di deposito dichiarato |
| **Reddit Radar** | Solo tramite API ufficiale OAuth (client ID personale); menzioni, crescita, autori unici, sentiment, rischio hype con limite al punteggio |
| **Simulatore** | Ordini mercato, limite, stop, stop-limit, bracket/OCO; esecuzione su barre giornaliere **senza look-ahead**, gap, spread, slippage, commissioni, cambio; politiche prudenti per esiti ambigui |
| **Portafoglio** | Conti ETF e Trading indipendenti, registro contabile append-only, trasferimenti manuali tracciati, P&L, curva di equity vs benchmark, win rate, profit factor, expectancy, drawdown |
| **Storico decisioni** | Snapshot giornalieri immutabili valutati a 1/5/20/60/90 sedute vs SPY/QQQ/VWCE/liquidità, calibrazione per fascia di punteggio |
| **Altro** | Watchlist e avvisi locali, diario di trading, notizie RSS ufficiali, impostazioni avanzate, export/import cifrato (AES-256-GCM) |

## Architettura

Android standalone (nessun backend, nessun server): Kotlin, Jetpack Compose, Material 3, MVVM con flusso unidirezionale, Hilt, Coroutines/StateFlow, Room (fonte di verità locale), DataStore, OkHttp + Retrofit + kotlinx.serialization, WorkManager, Android Keystore, notifiche locali, grafici Compose Canvas interattivi.

```
marketpilot/
  app/                      shell, navigazione, worker, notifiche
  core/model|common|network|database|datastore|security|designsystem
  domain/indicators|market|scoring|risk|portfolio|papertrading|backtesting   (Kotlin puro, testato)
  data/providers            provider registry + parser + normalizzazione (Kotlin puro)
  data/repositories         repository, cache, refresh engine, export
  feature/onboarding|home|etf|toptrade|stockdetail|reddit|insiders|news|watchlist|portfolio|simulator|journal|settings
  jvm-check/                build locale dei soli moduli JVM (senza Android SDK)
  scripts/                  build Windows/Linux, sonda fonti, riepilogo test
```

## Documentazione

- [INSTALL_ANDROID.md](INSTALL_ANDROID.md) — installazione sul telefono (Samsung) e build
- [USER_GUIDE.md](USER_GUIDE.md) — guida d'uso
- [DATA_SOURCES.md](DATA_SOURCES.md) — fonti dati, verifiche reali, credenziali
- [SCORING_MODEL.md](SCORING_MODEL.md) — modelli e pesi
- [PAPER_TRADING_RULES.md](PAPER_TRADING_RULES.md) — regole del simulatore
- [TEST_RESULTS.md](TEST_RESULTS.md) — risultati dei test eseguiti
- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) — limiti noti
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — stato PASS/FAIL/BLOCKED/NOT TESTED per funzionalità
- [TASKS.md](TASKS.md) — checkpoint e prossimi passi

## Build rapida

```bash
./gradlew :app:assembleDebug          # Linux/macOS (richiede Android SDK)
scripts\build_apk_windows.bat          # Windows
```

L'APK compilato e testato da GitHub Actions è pubblicato nella pre-release **marketpilot-android-latest** del repository.
