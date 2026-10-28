# Checkpoint e prossimi passi

## Fatto
- App Android completa multi-modulo (13 schermate funzionali), dati reali gratuiti, paper trading, rischio, storico decisioni.
- CI GitHub Actions: build, 113 test unitari/integrazione/UI, test su rete reale, test end-to-end su emulatore, pubblicazione APK.
- Documentazione completa in italiano.

## Priorità successive
1. Installazione e prova su un telefono Samsung reale (permesso notifiche, ottimizzazione batteria, aggiornamenti in background).
2. Verifica con chiavi personali Alpha Vantage / Finnhub e client ID Reddit.
3. Fonte di prezzi ufficiale alternativa a Yahoo (es. chiave gratuita di un fornitore con termini chiari) per ridurre il rischio di interruzione.
4. Validazione storica dei punteggi (walk-forward) prima di attribuire loro qualsiasi significato statistico.
5. Test di migrazione Room alla prima modifica dello schema (v1 → v2) con `MigrationTestHelper`.
6. Modellare dividendi e fiscalità italiana nel simulatore.
7. Build release con firma privata dell'utente (non la chiave di sideload pubblica).
