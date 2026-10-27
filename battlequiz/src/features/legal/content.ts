import type { Locale } from "@/types/game";

/**
 * DRAFT legal texts. They describe what the current build actually does and
 * MUST be reviewed by a qualified lawyer before any commercial launch.
 * Placeholders in [brackets] need real company details.
 */
export type LegalDoc = "privacy" | "terms" | "cookies";

interface Section {
  h: string;
  p: string[];
}

export const LEGAL: Record<LegalDoc, Record<Locale, { title: string; updated: string; sections: Section[] }>> = {
  privacy: {
    it: {
      title: "Informativa sulla privacy",
      updated: "Bozza del 27 ottobre 2026",
      sections: [
        { h: "Titolare del trattamento", p: ["[Ragione sociale], [indirizzo], [email di contatto]. Da completare prima del lancio."] },
        { h: "Dati trattati nella versione attuale", p: [
          "Giocando come ospite non chiediamo nome, email o altri dati personali.",
          "Per far funzionare la partita impostiamo un identificativo ospite casuale in un cookie tecnico firmato (bq_guest). Serve solo ad associare a te le tue partite e a evitare che altri le leggano.",
          "Sul server registriamo le partite (domande mostrate, risposte, tempi di risposta e punteggi) e la cronologia delle domande viste, per calcolare i punteggi in modo equo ed evitare ripetizioni.",
          "Registriamo eventi tecnici e di sicurezza (es. limiti di richieste superati, risposte anomale) senza salvare indirizzi IP in chiaro.",
          "Le preferenze (lingua, audio, animazioni) e i progressi da ospite restano nel localStorage del tuo dispositivo.",
        ] },
        { h: "Finalità e basi giuridiche", p: ["Erogazione del servizio richiesto (art. 6.1.b GDPR) e legittimo interesse alla sicurezza e alla prevenzione degli abusi (art. 6.1.f GDPR). Da validare con il consulente legale."] },
        { h: "Conservazione", p: ["Partite e cronologia ospite: [periodo da definire, es. 180 giorni]. Eventi di sicurezza: [periodo da definire]."] },
        { h: "Fornitori", p: ["Hosting: Vercel. Database: Supabase (PostgreSQL). L'elenco dei responsabili del trattamento e delle eventuali sedi extra-UE va completato."] },
        { h: "I tuoi diritti", p: ["Accesso, rettifica, cancellazione, limitazione, portabilità e opposizione, oltre al reclamo al Garante per la protezione dei dati personali. Le funzioni self-service di esportazione e cancellazione arriveranno con gli account."] },
      ],
    },
    en: {
      title: "Privacy Policy",
      updated: "Draft of 27 October 2026",
      sections: [
        { h: "Controller", p: ["[Company name], [address], [contact email]. To be completed before launch."] },
        { h: "Data processed in the current version", p: [
          "Playing as a guest we do not ask for your name, email or other personal data.",
          "To run a match we set a random guest identifier in a signed technical cookie (bq_guest). It only links your matches to you and prevents others from reading them.",
          "On the server we store matches (questions shown, answers, response times and scores) and the history of questions seen, to score fairly and avoid repeats.",
          "We log technical and security events (e.g. rate limits exceeded, anomalous answers) without storing raw IP addresses.",
          "Preferences (language, sound, motion) and guest progress stay in your device's localStorage.",
        ] },
        { h: "Purposes and legal bases", p: ["Providing the requested service (Art. 6(1)(b) GDPR) and legitimate interest in security and abuse prevention (Art. 6(1)(f) GDPR). To be validated by legal counsel."] },
        { h: "Retention", p: ["Guest matches and history: [period to be defined, e.g. 180 days]. Security events: [period to be defined]."] },
        { h: "Providers", p: ["Hosting: Vercel. Database: Supabase (PostgreSQL). The list of processors and any non-EU locations must be completed."] },
        { h: "Your rights", p: ["Access, rectification, erasure, restriction, portability and objection, plus the right to complain to your data protection authority. Self-service export and deletion arrive with accounts."] },
      ],
    },
  },
  terms: {
    it: {
      title: "Termini di servizio",
      updated: "Bozza del 27 ottobre 2026",
      sections: [
        { h: "Il servizio", p: ["BattleQuiz è un gioco di quiz a scopo di intrattenimento. Non prevede premi in denaro, puntate o meccaniche d'azzardo."] },
        { h: "Uso corretto", p: ["È vietato manipolare i punteggi, automatizzare le risposte, estrarre in massa le domande o aggirare i limiti tecnici. Possiamo annullare risultati e limitare l'accesso in caso di abusi."] },
        { h: "Contenuti", p: ["Le domande sono curate con attenzione ma possono contenere errori. Puoi segnalarli. I contenuti, il marchio e la grafica di BattleQuiz sono originali e protetti."] },
        { h: "Abbonamenti", p: ["BattleQuiz Plus non è ancora disponibile e nessun pagamento è attivo. Le condizioni di abbonamento saranno pubblicate prima dell'attivazione."] },
        { h: "Responsabilità e legge applicabile", p: ["[Da completare a cura del consulente legale: limitazioni di responsabilità, foro competente, legge italiana, tutela del consumatore.]"] },
      ],
    },
    en: {
      title: "Terms of Service",
      updated: "Draft of 27 October 2026",
      sections: [
        { h: "The service", p: ["BattleQuiz is a trivia game for entertainment. It offers no cash prizes, wagers or gambling mechanics."] },
        { h: "Fair use", p: ["Manipulating scores, automating answers, bulk-scraping questions or bypassing technical limits is forbidden. We may void results and restrict access in case of abuse."] },
        { h: "Content", p: ["Questions are carefully curated but may contain mistakes. You can report them. BattleQuiz content, brand and artwork are original and protected."] },
        { h: "Subscriptions", p: ["BattleQuiz Plus is not available yet and no payments are active. Subscription terms will be published before activation."] },
        { h: "Liability and governing law", p: ["[To be completed by legal counsel: limitation of liability, jurisdiction, governing law, consumer protection.]"] },
      ],
    },
  },
  cookies: {
    it: {
      title: "Cookie policy",
      updated: "Bozza del 27 ottobre 2026",
      sections: [
        { h: "Cookie tecnici", p: ["bq_guest — identificativo ospite firmato, httpOnly, durata 180 giorni. Necessario per giocare: non richiede consenso."] },
        { h: "Archiviazione locale", p: ["bq-settings e bq-guest-profile nel localStorage: preferenze e progressi da ospite. Restano sul tuo dispositivo e puoi cancellarli dalle impostazioni del browser."] },
        { h: "Cookie di profilazione e pubblicità", p: ["Al momento non usiamo cookie di analisi di terze parti, di profilazione o pubblicitari. Se in futuro verranno introdotti, chiederemo prima il tuo consenso."] },
      ],
    },
    en: {
      title: "Cookie Policy",
      updated: "Draft of 27 October 2026",
      sections: [
        { h: "Technical cookies", p: ["bq_guest — signed guest identifier, httpOnly, 180-day lifetime. Required to play; no consent needed."] },
        { h: "Local storage", p: ["bq-settings and bq-guest-profile in localStorage: preferences and guest progress. They stay on your device and you can clear them in your browser settings."] },
        { h: "Analytics, profiling and advertising", p: ["We currently use no third-party analytics, profiling or advertising cookies. If any are introduced, we will ask for your consent first."] },
      ],
    },
  },
};
