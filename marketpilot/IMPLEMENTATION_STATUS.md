# Stato di implementazione

Legenda: **PASS** = implementato e verificato da test automatici eseguiti · **FAIL** = verificato e non funzionante ·
**BLOCKED** = impossibile per vincoli esterni (credenziali, termini d'uso, infrastruttura) · **NOT TESTED** = implementato ma non verificato.

| Funzionalità | Stato | Evidenza |
|---|---|---|
| Build APK (Gradle KTS, multi-modulo, Kotlin/Compose/Hilt/Room) | PASS | CI `assembleDebug`, APK pubblicato in pre-release |
| Onboarding con capitale ETF/Trading (default 0 €) | PASS | UiFlowsTest, EndToEndTest, PortfolioTest |
| Conti ETF e Trading separati, registro append-only, trasferimenti tracciati | PASS | PortfolioTest, RepositoryIntegrationTest |
| Calendari NYSE/Nasdaq, Xetra, LSE e freschezza dei dati | PASS | TradingCalendarTest |
| Indicatori tecnici (SMA/EMA/RSI/MACD/Bollinger/ATR/supporti) | PASS | IndicatorsTest |
| Regime di mercato e schermata Oggi | PASS | MarketAssessorTest, UiFlowsTest |
| Top Trade USA (pesi 25/20/15/10/10/10/5/5, copertura, fiducia, NESSUN TRADE) | PASS | ScoringTest, RepositoryIntegrationTest |
| ETF Radar (3 decisioni, confronto unica soluzione/PAC/tranche) | PASS | ScoringTest, DecisionTrackerTest, UiFlowsTest |
| Scheda titolo con grafico a candele e indicatori | PASS | UiFlowsTest (render), IndicatorsTest |
| Insider Form 4 + 13F (SEC, rete reale) | PASS | ParsersTest, LiveProvidersTest |
| Fondamentali SEC XBRL | PASS | ParsersTest, LiveProvidersTest |
| Notizie (RSS ufficiali + Yahoo per ticker) | PASS | ParsersTest, LiveProvidersTest |
| Reddit Radar (API OAuth ufficiale) | BLOCKED | Richiede client ID personale; senza, stato "non configurato" verificato |
| Alpha Vantage (riserva prezzi, trimestrali) | BLOCKED | Richiede chiave personale; rifiuto della chiave demo classificato correttamente |
| Finnhub | NOT TESTED | Nessuna chiave disponibile |
| Stooq | BLOCKED | Verifica anti-bot JavaScript; non aggirata, fonte disattivata |
| Paper trading (mercato/limite/stop/stop-limit/bracket/OCO, no look-ahead, gap, parziali, costi, cambio) | PASS | PaperTradingEngineTest (18), RepositoryIntegrationTest, UiFlowsTest |
| Riconciliazione ordini pendenti su barre reali | vedi E2E | EndToEndTest passo 8 |
| Motore di rischio (0,5%, 15%, 3 posizioni, 2%, R/R 2,0) | PASS | RiskTest |
| Storico decisioni (1/5/20/60/90 sedute, benchmark, calibrazione) | PASS | DecisionTrackerTest, RepositoryIntegrationTest |
| AGGIORNA MERCATO (15 passi, annullabile, offline → parziale) | PASS | RepositoryIntegrationTest, UiFlowsTest |
| Watchlist e avvisi locali | PASS | RepositoryIntegrationTest (avvisi), UiFlowsTest |
| Diario di trading | PASS | UiFlowsTest |
| Export/import cifrato (PBKDF2 + AES-GCM) | PASS | SecurityTest, RepositoryIntegrationTest |
| Segreti cifrati con Android Keystore, nessuna chiave nell'APK, solo HTTPS | PASS | SecurityTest, HttpFetcherTest, revisione del codice |
| Aggiornamento in background (WorkManager) e notifiche | NOT TESTED | Pianificazione implementata; esecuzione su più giorni non verificata |
| Percorso completo su emulatore Android con rete reale | vedi TEST_RESULTS.md | EndToEndTest |
| Installazione su telefono Samsung fisico | NOT TESTED | Nessun dispositivo fisico disponibile all'autore |
| Migrazioni del database | NOT TESTED | Schema v1 esportato; nessuna migrazione ancora necessaria |
