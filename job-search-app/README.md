# Cerca Lavoro

Web app per cercare offerte di lavoro, salvare quelle interessanti e tenere traccia delle candidature.

## Funzionalità

- **Ricerca** per parola chiave (ruolo, competenza, azienda) e località, con ranking per pertinenza o data.
- **Filtri**: solo da remoto, data di pubblicazione, tipo di contratto, fonte.
- **Fonti reali** aggregate lato server: [Arbeitnow](https://www.arbeitnow.com/api/job-board-api) (Europa) e [Remotive](https://remotive.com/api/remote-jobs) (remoto). Nessuna API key necessaria.
- **Dettaglio offerta** con link per candidarsi sul sito originale.
- **Tracker candidature**: salva le offerte e spostale tra *Salvate → Candidato → Colloquio → Offerta / Non selezionato*, con note personali. I dati restano nel browser (localStorage).
- URL condivisibili (i filtri sono nella query string), tema chiaro/scuro automatico, layout mobile.
- Se le fonti esterne non rispondono, l'app mostra offerte dimostrative e lo segnala.

## Avvio

Richiede Node.js 18 o superiore. Nessuna dipendenza da installare.

```bash
cd job-search-app
npm start          # http://localhost:3000
```

Variabili d'ambiente:

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `PORT`    | `3000`  | Porta HTTP |
| `OFFLINE` | —       | Con `OFFLINE=1` usa solo i dati dimostrativi, senza chiamare le API esterne |

## Test

```bash
npm test
```

## Struttura

```
job-search-app/
├── server.js            # server HTTP: API /api/jobs + file statici
├── lib/
│   ├── providers.js     # client Arbeitnow e Remotive, normalizzazione delle offerte
│   ├── store.js         # cache (10 min) e fallback sui dati demo
│   ├── search.js        # ricerca, filtri, ordinamento, paginazione
│   └── text.js          # HTML → testo, normalizzazione accenti
├── data/sample-jobs.json
├── public/              # frontend (HTML, CSS, JS senza build)
└── test/
```

### API

`GET /api/jobs` — parametri opzionali: `q`, `location`, `remote=true`, `types` (separati da virgola), `sources`, `maxAgeDays`, `sort=relevance|date`, `page`, `pageSize` (max 50).

Le descrizioni delle offerte vengono convertite in testo semplice lato server, così il browser non esegue mai HTML proveniente da terzi.
