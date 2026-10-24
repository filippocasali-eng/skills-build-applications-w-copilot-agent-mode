# Idee prioritarie per la v1.1

Ordinate per impatto stimato su divertimento e ritenzione sana, sulla base di ciò che è emerso sviluppando la v1.

1. **Telemetria di bilanciamento opt-in, anonima e aggregata (solo genitore).** Il bilanciamento di `difficulty_config.json` è stato fatto con bot e simulazioni: servono dati reali su successo e durata per fascia di rating. Proposta: report aggregati e anonimi, attivabili solo dall'area genitori, senza identificatori. In alternativa: playtest dal vivo con 10–20 bambini divisi per età.
2. **Colori "in anticipo" sulle porte miste per i più piccoli.** Le porte secondarie sono il punto in cui l'errore "mix sbagliato" cresce di più. Un aiuto opzionale (mini-ricetta R+B sopra la porta viola nei primi incontri) ridurrebbe la frustrazione senza togliere sfida a chi è esperto.
3. **Feedback del Coach più ricco ma sempre breve.** Oggi c'è un consiglio per partita. Si possono aggiungere micro-replay di 2 secondi dell'errore (i replay ci sono già) con la corsia giusta evidenziata.
4. **Nuova meccanica: porte che cambiano colore.** Previste nel concept per i ragazzi più grandi: porta che alterna due colori con un ritmo leggibile (sincronizzato con la musica). Il validatore va esteso con la fase della porta.
5. **Nuova meccanica: corsie "nastro" e gocce doppie.** Corsie che spostano Mixo di lato e gocce con due colori in sequenza: aumentano la profondità dei mix a 3 livelli senza nuove regole da leggere.
6. **Eventi stagionali cosmetici a calendario fisso, senza FOMO.** Halloween (zucche e mondo "Notte"), Natale (neve), Primavera (fiori): gli oggetti dell'evento si sbloccano giocando e **tornano ogni anno**, quindi nessuno "li perde per sempre".
7. **Tutorial vocale / audio per chi non sa leggere.** Le icone ci sono già; mancano brevi voci registrate ("Vai sulla porta rossa!") in IT/EN per i 6-7enni.
8. **Modalità "Zen" senza cuori.** Per i più piccoli o per rilassarsi: niente game over, punteggio comunque registrato a parte. Utile anche come "modalità genitore + bambino".
9. **Prestazioni: cache dei colori degli anelli e LOD delle file lontane.** Le uniche allocazioni residue nel loop sono colori immutabili; con il profiling su dispositivo (PERFORMANCE.md) decidere se servono cache e semplificazione delle porte oltre i 60 m.
10. **Sfide tra amici via codice (anticipo della v2 multiplayer).** Il replay compatto e il `MultiplayerService` sono pronti: il primo passo online è lo scambio di un codice-sfida, con opt-in genitoriale e auth anonima (vedi MULTIPLAYER_PLAN.md).
