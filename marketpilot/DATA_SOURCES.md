# Fonti dati

Tutte le richieste partono **dal telefono** (nessun backend). Ogni risposta è normalizzata in un
`ProviderResult` con: dati, nome fonte, URL della risorsa (chiavi oscurate), orario di osservazione,
orario di recupero, freschezza (IN TEMPO REALE / RITARDATO / CHIUSURA ULTIMA SEDUTA / NON AGGIORNATO),
valuta, identità dello strumento, indicatori di qualità, errore e limiti di richiesta.

Una fonte è considerata **operativa solo dopo una richiesta reale riuscita** (test di integrazione su rete reale
in CI, oppure pulsante *Verifica* nella schermata *Fonti dati* dell'app).

## Verifica reale (CI GitHub Actions, 28/10/2026, `LiveProvidersTest`, 5/5 test superati)

| Fonte | Uso | Chiave | Ufficiale | Esito verifica reale |
|---|---|---|---|---|
| Yahoo Finance chart v8 | Storico giornaliero e quotazioni (USA, Xetra, LSE, indici) | No | **No** (endpoint pubblico non documentato) | ✅ SPY, QQQ, XLK, AAPL (chiusura 27/10); VWCE, SXR8, SXRV, EUNL, CSPX ✅ ma ultima barra Xetra/LSE incompleta → classificate NON AGGIORNATE (vedi limiti) |
| SEC EDGAR – company_tickers | Mappa ticker → CIK | No | Sì | ✅ |
| SEC EDGAR – submissions + Form 4 XML | Insider per titolo | No | Sì | ✅ (AAPL, filing del 22/10/2026) |
| SEC EDGAR – feed "current" Form 4 | Insider Radar di mercato | No | Sì | ✅ |
| SEC EDGAR – 13F-HR | Istituzionali (8 gestori) | No | Sì | ✅ Berkshire, periodo 30/06/2026 depositato 14/08/2026 |
| SEC XBRL companyfacts | Fondamentali annuali (10-K) | No | Sì | ✅ MSFT |
| Cboe VIX_History.csv | Volatilità | No | Sì | ✅ chiusura 27/10 |
| FRED (fredgraph.csv) | DGS10, T10Y2Y, VIXCLS (riserva) | No | Sì | ✅ |
| BCE eurofxref 90d + storico zip | Cambi EUR/USD, EUR/GBP | No | Sì | ✅ |
| Federal Reserve RSS | Comunicati (FOMC) | No | Sì | ✅ |
| SEC RSS comunicati | Regolamentazione | No | Sì | ✅ |
| Yahoo Finance RSS per titolo | Titoli di notizie per ticker | No | No | ✅ |
| Alpha Vantage | Storico/quotazioni/calendario trimestrali | **Sì (personale gratuita)** | Sì | ⚠️ Non verificabile senza chiave: con la chiave pubblica "demo" la richiesta viene rifiutata e l'app la classifica correttamente come AUTH |
| Finnhub | Notizie societarie, calendario trimestrali | **Sì (personale gratuita)** | Sì | ⚠️ NON TESTATO (nessuna chiave disponibile in CI) |
| Reddit API (OAuth "installed app") | Reddit Radar | **Client ID personale** | Sì | ⚠️ BLOCCATO senza client ID: accesso anonimo → HTTP 403; endpoint OAuth raggiungibile (401 senza credenziali); l'app mostra lo stato "da configurare" |
| Stooq CSV | (storico) | No | No | ❌ NON UTILIZZABILE: pagina di verifica JavaScript del browser. L'app non aggira il controllo: fonte disattivata e segnalata come BLOCCATA |

Lo **storico prezzi gratuito senza chiave** dipende quindi da Yahoo Finance (non ufficiale). Se smettesse di
funzionare l'app lo segnala, conserva i dati già salvati e — con chiave Alpha Vantage — usa quella come riserva
(piano gratuito: ~100 sedute recenti, poche richieste al minuto).

## Credenziali personali (facoltative)
| Credenziale | Dove ottenerla | Dove inserirla |
|---|---|---|
| Alpha Vantage API key | https://www.alphavantage.co/support/#api-key | Fonti dati → Alpha Vantage |
| Finnhub API key | https://finnhub.io/register | Fonti dati → Finnhub |
| Reddit client ID | https://www.reddit.com/prefs/apps → *create app* → tipo **installed app** (nessun secret) | Fonti dati → Reddit |
| E-mail di contatto SEC | (la tua e-mail) | Fonti dati → SEC EDGAR (User-Agent richiesto dalla SEC) |

Le chiavi sono cifrate con AES-256-GCM tramite chiave non esportabile dell'**Android Keystore**, mai esportate nei backup,
mai incluse nell'APK. Un'app non può nascondere in modo sicuro un segreto condiviso: per questo non ne contiene.

## Politiche di accesso
- Spaziatura minima per host (SEC 150 ms ≈ 6–7 req/s < 10 req/s consentite; Yahoo 350 ms; Alpha Vantage 13 s; Finnhub 1,1 s; Reddit 1,1 s), backoff su HTTP 429/5xx, rispetto di `Retry-After`.
- Timeout: connessione 10 s, lettura 25 s, chiamata 45 s; ogni fase del refresh ha un proprio timeout.
- Solo HTTPS (network security config + interceptor che rifiuta connessioni in chiaro).
- Download SEC "a budget": insider per titolo a rotazione (8 titoli per refresh), 13F settimanale, fondamentali settimanali; i filing già scaricati non vengono riscaricati.

## Normalizzazione e validazione
- Barre ordinate, deduplicate; scartate barre OHLC incoerenti, giorni di borsa chiusa e la **seduta non ancora conclusa**.
- Completezza calcolata sul calendario di borsa (NYSE, Xetra, LSE con festività calcolate).
- Valuta restituita diversa da quella attesa → dati scartati (mai mescolati).
- Quotazioni con timestamp nel futuro → marcate come non affidabili.
- In caso di errore i dati salvati **non vengono cancellati** e mantengono il loro timestamp originale.

## Riferimenti esterni
- Dataroma (superinvestitori): solo link di riferimento, nessuno scraping.
