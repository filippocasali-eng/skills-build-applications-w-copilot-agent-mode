# Risultati dei test

Tutti i numeri qui sotto provengono da esecuzioni reali su **GitHub Actions** (workflow
`.github/workflows/marketpilot-android.yml`, branch `ccr-86bce3c0-nbbha4`, 28/10/2026).
L'ambiente di sviluppo locale non può scaricare l'Android SDK (repository Google bloccato), quindi la build Android e
i test Android girano solo in CI; i moduli Kotlin puri sono stati compilati e testati anche in locale (`jvm-check/`).

## Test unitari e di integrazione (JVM + Robolectric) — 113 test, 0 falliti

| Modulo | Suite | Test | Esito |
|---|---|---|---|
| core/common | TradingCalendarTest (NYSE/Xetra/LSE, festività, chiusure anticipate, fasi di sessione, freschezza) | 10 | PASS |
| core/network | HttpFetcherTest (retry, backoff, 429 Retry-After, solo HTTPS) | 5 | PASS |
| core/datastore | SettingsStoreTest | 1 | PASS |
| core/security | SecurityTest (Keystore AES-GCM, export cifrato PBKDF2) | 2 | PASS |
| domain/indicators | IndicatorsTest (SMA, EMA, RSI vs valori pubblicati, MACD, Bollinger, ATR, supporti/resistenze) | 14 | PASS |
| domain/market | MarketAssessorTest (regimi, dati insufficienti) | 4 | PASS |
| domain/scoring | ScoringTest (pesi, copertura, fiducia, NESSUN TRADE, insider, Reddit hype) | 9 | PASS |
| domain/risk | RiskTest (dimensionamento, vincoli, R/R minimo, costi, cambio) | 7 | PASS |
| domain/portfolio | PortfolioTest (registro, P&L, trasferimenti) | 4 | PASS |
| domain/papertrading | PaperTradingEngineTest (no look-ahead, gap, limit, stop, stop-limit, OCO ambiguo, parziali, cassa) | 18 | PASS |
| domain/backtesting | DecisionTrackerTest (orizzonti 1/5/20/60/90 sedute, benchmark, calibrazione) | 5 | PASS |
| data/providers | ParsersTest (payload reali registrati: Yahoo, SEC Form 4/13F/XBRL/Atom, Cboe, FRED, BCE, RSS, Reddit, Alpha Vantage) | 14 | PASS |
| data/repositories | RepositoryIntegrationTest (refresh offline, refresh concorrente, errore fonte con cache, ciclo ordine, export/import cifrato, storico decisioni, avvisi, trasferimenti, registro immutabile) | 9 | PASS |
| app | UiFlowsTest (Compose UI su Robolectric: onboarding, navigazione completa, aggiornamento offline, ETF e scheda titolo, ordine simulato e annullamento, diario dopo ricreazione) | 6 | PASS |

## Test su rete reale — `LiveProvidersTest` (5 test, PASS nell'ultima esecuzione; include ora anche FRED DEXUSEU)
Esito dettagliato e date osservate: vedi [DATA_SOURCES.md](DATA_SOURCES.md). Superati 5/5 nelle esecuzioni delle 08:03
e 12:36 UTC; nell'esecuzione delle 13:46 UTC Stooq ha risposto con un timeout invece della pagina anti-bot e
l'asserzione (troppo rigida) è fallita: corretta per accettare qualsiasi errore classificato (Stooq è disattivato).

## Test end-to-end su emulatore Android (API 34, rete reale) — `EndToEndTest`
Percorso: primo avvio → onboarding con capitale → AGGIORNA MERCATO con tutte le fonti gratuite reali → ETF Radar e
dettaglio VWCE → watchlist + scheda MSFT → ordine simulato dal ticket → riconciliazione di un ordine retrodatato su
barre reali (deve essere eseguito sulla prima seduta successiva, all'apertura reale) → portafoglio → ricreazione
dell'activity → export cifrato.

**Esito finale: PASS** (run 40716797481, 28/10/2026 15:54 UTC, commit d1f0329, APK build 21). Evidenze dal log:
- SPY: 751 barre giornaliere reali, ultima seduta 27/10/2026 (= ultima seduta conclusa attesa)
- Regime di mercato calcolato: FAVORABLE, punteggio 73, copertura dati 100%
- Fonti operative sul dispositivo: Yahoo, SEC EDGAR, Cboe, FRED, Fed RSS, SEC RSS, Yahoo RSS
- BCE: DEGRADED sull'emulatore (certificato non riconosciuto da Android) → 747 cambi EUR/USD dalla riserva FRED
- Ordine simulato dal ticket SPY: accettato (stato NEW)
- Ordine retrodatato di 10 sedute: FILLED nella prima seduta successiva, al prezzo di apertura reale o peggiore
- Ricreazione dell'activity: dati e capitale (20.000 € ETF) conservati
- Export cifrato: 105.161 byte

Esecuzioni precedenti fallite (tutte corrette): deadlock all'avvio, dialog permesso notifiche, cambio BCE non disponibile su Android,
passi del test.

## Problemi trovati e corretti grazie ai test
- Deadlock all'avvio: lock dei repository tenuti sul main thread (ora su `Dispatchers.IO`).
- Navigazione "Vai agli ordini" che riportava al ticket invece che alla lista ordini.
- Editor del diario in finestra di dialogo → editor in linea.
- Indicatori di avanzamento infiniti sostituiti da indicatori determinati.
- Richiesta del permesso notifiche che mette in pausa l'app subito dopo l'onboarding (comportamento atteso; il test lo concede in anticipo).
- Decompressione gzip disattivata per errore sulle richieste SEC; chiave "demo" Alpha Vantage classificata come AUTH.

## Non testato
- Installazione e uso su **telefono Samsung fisico** (nessun dispositivo disponibile): NOT TESTED.
- Finnhub e Reddit con credenziali reali: NOT TESTED (nessuna chiave disponibile).
- Aggiornamenti in background WorkManager su più giorni e consegna reale delle notifiche: NOT TESTED.
