# Modello di punteggio (versione `mp-model-1.0.0`)

Tutti i calcoli sono **deterministici, spiegati nell'app ("Perché?") e testati**. I pesi sono quelli della
specifica, configurabili, e **non sono validati statisticamente**: lo Storico decisioni serve proprio a misurarne l'efficacia.

## Indicatori (`domain/indicators`)
SMA, EMA (inizializzata con SMA), RSI 14 di Wilder (verificato contro l'esempio pubblicato da Wilder/StockCharts),
MACD 12/26/9, ATR 14 (Wilder), Bande di Bollinger 20/2, volatilità storica annualizzata (20 sedute, log-rendimenti),
drawdown corrente e massimo, massimi/minimi 52 settimane, forza relativa, distanza dalle medie, supporti/resistenze
da pivot confermati (3 barre per lato: le ultime barre non possono generare livelli → niente look-ahead).

## Regime di mercato (`domain/market`)
| Componente | Peso | Regola (0–100) |
|---|---|---|
| Trend S&P 500 (SPY) | 20% | +35 sopra SMA200, +25 SMA50>SMA200, +20 sopra SMA50, +20 SMA50 in salita |
| Trend Nasdaq 100 (QQQ) | 10% | idem |
| Volatilità | 15% | VIX ≤13:85, ≤17:75, ≤20:60, ≤25:40, ≤30:25, ≤40:10, oltre:0; −10 se +25% vs media 20g. Senza VIX: volatilità realizzata SPY (segnalato) |
| Drawdown SPY da max 52s | 10% | >−3%:85, >−7%:65, >−12%:45, >−20%:25, oltre:10 |
| Momentum SPY | 10% | 50 + 400·r1m + 200·r3m |
| Ampiezza | 10% | % titoli dell'universo sopra SMA50 (≥20 titoli) — stima sull'universo, non sull'indice |
| Settori | 10% | % ETF settoriali SPDR sopra SMA50 (≥6) |
| Propensione al rischio | 5% | XLY vs XLP a 3 mesi |
| Macro | 10% | base 65; −20 se Treasury 10a +0,30 pp in 1 mese; −10 curva 10a-2a invertita; −10 comunicato FOMC negli ultimi 3 giorni |

Componenti mancanti sono **escluse** e riducono la copertura (mai trattate come 50).
Regime: copertura <60% o trend SPY mancante → DATI INSUFFICIENTI; VIX ≥35 o (drawdown ≤−20% e sotto SMA200) → RISCHIO ELEVATO;
altrimenti ≥65 FAVOREVOLE, ≥50 NEUTRALE, ≥35 CAUTELA, sotto RISCHIO ELEVATO.

**Opportunità ETF**: ritracciamento (35%), distanza da SMA200 (25%), RSI (20%), VIX come sentiment (20%): premia ritracciamenti moderati in trend intatto.
**Opportunità swing**: trend 35%, ampiezza 25%, volatilità 25%, momentum 15%; limitato a 50 in CAUTELA e 30 in RISCHIO ELEVATO.

## ETF Radar (`EtfAnalyzer`)
Score: trend lungo (25%), ritracciamento (30%), distanza da SMA200 (25%), RSI (20%). Tre decisioni distinte:
1. **Accumulo di lungo periodo**: dati insufficienti / solo benchmark (ETF USA non UCITS) / adatto al PAC / adatto come satellite (Nasdaq-100).
2. **Acquisto tattico**: ≥65 momento ragionevole, ≥45 neutrale (PAC/tranche), sotto attendi; in RISCHIO ELEVATO sempre "ingresso a tranche".
3. **Concentrazione**: famiglia di esposizione >70% o singolo ETF non globale >80% → concentrazione elevata; segnala la sovrapposizione USA/globali.

## Top Trade USA (`StockScorer`, `StockRanker`)
| Sottopunteggio | Peso | Fonte |
|---|---|---|
| Momentum | 25% | 0,4·r3m + 0,3·r6m + 0,3·forza relativa vs SPY, normalizzato a **percentile** nell'universo |
| Struttura tecnica | 20% | medie, RSI, MACD, vicinanza ai massimi, estensione |
| Qualità fondamentale | 15% | SEC XBRL: crescita ricavi, margini, free cash flow, debito/patrimonio (servono ≥2 metriche) |
| Acquisti insider | 10% | Insider Conviction Score |
| Attività istituzionale | 10% | 13F gestori monitorati: 50 + 15·(aumenti − riduzioni) |
| Sentiment Reddit | 10% | con limite per hype |
| Catalizzatori news | 5% | tono dei titoli a 7 giorni (interpretazione automatica) |
| Liquidità | 5% | controvalore medio 20 sedute |

Regole esplicite sui dati mancanti:
- `null` = non disponibile (fonte non configurata/fallita) ≠ lista vuota = disponibile ma nulla trovato.
- **Esclusione**: <200 sedute, momentum o tecnica non calcolabili, copertura <50%, ultimo prezzo più vecchio di 3 sedute.
- **Copertura** = somma dei pesi disponibili; **fiducia** = copertura × fattore di freschezza (1 / 0,8 / 0,5).
- **Ranking** = punteggio × (0,6 + 0,4·copertura): i dati mancanti penalizzano esplicitamente.
- **Raccomandazione**: dati insufficienti → DATI INSUFFICIENTI; rischio molto alto → RISCHIO ELEVATO; regime RISCHIO ELEVATO/insufficiente → ATTENDI;
  nessun setup → ATTENDI (score ≥65) o NESSUN TRADE; CANDIDATO solo con score ≥65, fiducia ≥60%, piano valido (e ≥72 in CAUTELA); 55–65 → OSSERVA.
- Se nessun titolo è CANDIDATO la schermata mostra **NESSUN TRADE**.

Rischio: ATR% e volatilità (basso/medio/alto/molto alto), +1 livello con hype Reddit alto o trimestrale entro 5 giorni.

### Insider Conviction Score
Solo **acquisti sul mercato (P)** non in piano 10b5-1 (flag `aff10b5One` o nota a piè di pagina). Esclusi: assegnazioni (A),
esercizi/conversioni (M/X/C), ritenute (F), donazioni (G), piani automatici. Nessun acquisto: 30 − 3 per vendita discrezionale (min 10).
Con acquisti: 50 + 8·acquirenti (max 25) + punti valore log10 (max 20) + bonus ruolo (CEO/CFO 5) − vendite (max 15) + 5 se ≥3 insider nello stesso mese.
Il ritardo di deposito (data operazione → data filing) è sempre mostrato.

### Reddit
Ticker riconosciuti come cashtag `$XXX`, oppure in maiuscolo solo se non ambigui (A, IT, ALL, MA, V, AI, DD… solo come cashtag).
Rischio hype ALTO se l'autore più attivo produce >30% dei post, autori unici <30% delle menzioni o crescita >300%: punteggio limitato a 55 (70 se moderato).
<5 menzioni → 45 ("attenzione trascurabile").

## Piano di trade (`TradePlanner`) — scenari del modello, non previsioni
- Solo trend rialzista. **Breakout**: chiusura entro il 2% dal massimo a 20 sedute → ingresso = massimo + 0,1 ATR, stop 2 ATR (o sotto supporto).
- **Pullback**: prezzo entro 1 ATR dalla EMA21 e RSI 35–65 → zona EMA21 ± 0,5 ATR, stop 1,5–2,5 ATR / sotto supporto.
- Target 1 = ingresso + R·minimo (2,0), target 2 = resistenza o 3R. Se la resistenza più vicina dà R/R < minimo → NESSUN TRADE.

## Dimensionamento (`PositionSizer`)
budget = equity × rischio%; rischio per azione = |ingresso − stop| + slippage dello stop + spread + costi % (+ cambio), convertito in EUR;
quantità = min(rischio, liquidità, esposizione max 15%, 1% del volume medio, rischio aggregato residuo). Avvisi: gap, ATR >5%, volatilità >60%,
liquidità <20 M$, trimestrale entro 7 giorni o data sconosciuta. Errori: stop ≥ ingresso, capitale zero, rischio fuori 0–5%, posizioni massime.
