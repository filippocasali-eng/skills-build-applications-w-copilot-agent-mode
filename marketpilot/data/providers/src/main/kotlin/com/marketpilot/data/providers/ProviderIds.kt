package com.marketpilot.data.providers

import com.marketpilot.core.model.ProviderCapability
import com.marketpilot.core.model.ProviderDescriptor

object ProviderIds {
    const val YAHOO = "yahoo"
    const val STOOQ = "stooq"
    const val ALPHA_VANTAGE = "alphavantage"
    const val FINNHUB = "finnhub"
    const val SEC = "sec_edgar"
    const val FRED = "fred"
    const val CBOE = "cboe"
    const val ECB = "ecb"
    const val FED_RSS = "fed_rss"
    const val SEC_RSS = "sec_rss"
    const val YAHOO_RSS = "yahoo_rss"
    const val REDDIT = "reddit"
}

object ProviderCatalog {
    val YAHOO = ProviderDescriptor(
        ProviderIds.YAHOO, "Yahoo Finance (chart)", setOf(ProviderCapability.QUOTES, ProviderCapability.HISTORY), requiresApiKey = false,
        official = false, homepage = "https://finance.yahoo.com",
        termsNote = "Endpoint pubblico non documentato: uso personale, può cambiare o smettere di funzionare senza preavviso. Nessun accordo di licenza.",
        defaultEnabled = true,
    )
    val STOOQ = ProviderDescriptor(
        ProviderIds.STOOQ, "Stooq (CSV)", setOf(ProviderCapability.HISTORY), requiresApiKey = false, official = false,
        homepage = "https://stooq.com",
        termsNote = "Download CSV protetto da verifica JavaScript del browser (rilevato ottobre 2026): non utilizzabile da un'app senza aggirare il controllo, quindi disattivato.",
        defaultEnabled = false,
    )
    val ALPHA_VANTAGE = ProviderDescriptor(
        ProviderIds.ALPHA_VANTAGE, "Alpha Vantage", setOf(ProviderCapability.QUOTES, ProviderCapability.HISTORY), requiresApiKey = true,
        official = true, homepage = "https://www.alphavantage.co",
        termsNote = "Richiede una chiave personale gratuita (limiti: poche richieste al minuto/giorno). La chiave resta cifrata sul telefono.",
        defaultEnabled = true,
    )
    val FINNHUB = ProviderDescriptor(
        ProviderIds.FINNHUB, "Finnhub", setOf(ProviderCapability.QUOTES, ProviderCapability.NEWS), requiresApiKey = true, official = true,
        homepage = "https://finnhub.io", termsNote = "Richiede una chiave personale gratuita. Notizie societarie e calendario trimestrali.", defaultEnabled = true,
    )
    val SEC = ProviderDescriptor(
        ProviderIds.SEC, "SEC EDGAR", setOf(ProviderCapability.INSIDERS, ProviderCapability.INSTITUTIONAL, ProviderCapability.FUNDAMENTALS),
        requiresApiKey = false, official = true, homepage = "https://www.sec.gov/edgar",
        termsNote = "Dati pubblici ufficiali. Rispettata la policy di accesso equo (max 10 richieste/s, User-Agent dichiarato).", defaultEnabled = true,
    )
    val FRED = ProviderDescriptor(
        ProviderIds.FRED, "FRED (St. Louis Fed)", setOf(ProviderCapability.MACRO), requiresApiKey = false, official = true,
        homepage = "https://fred.stlouisfed.org", termsNote = "Download CSV pubblico delle serie (rendimenti Treasury, VIX).", defaultEnabled = true,
    )
    val CBOE = ProviderDescriptor(
        ProviderIds.CBOE, "Cboe (storico VIX)", setOf(ProviderCapability.MACRO), requiresApiKey = false, official = true,
        homepage = "https://www.cboe.com/tradable_products/vix/vix_historical_data/", termsNote = "CSV storico ufficiale del VIX pubblicato da Cboe.", defaultEnabled = true,
    )
    val ECB = ProviderDescriptor(
        ProviderIds.ECB, "BCE - tassi di cambio di riferimento", setOf(ProviderCapability.FX), requiresApiKey = false, official = true,
        homepage = "https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/",
        termsNote = "Tassi di riferimento ufficiali BCE (pubblicati intorno alle 16:00 CET nei giorni lavorativi).", defaultEnabled = true,
    )
    val FED_RSS = ProviderDescriptor(
        ProviderIds.FED_RSS, "Federal Reserve (RSS comunicati)", setOf(ProviderCapability.NEWS), requiresApiKey = false, official = true,
        homepage = "https://www.federalreserve.gov/feeds/feeds.htm", termsNote = "Feed RSS ufficiale.", defaultEnabled = true,
    )
    val SEC_RSS = ProviderDescriptor(
        ProviderIds.SEC_RSS, "SEC (RSS comunicati)", setOf(ProviderCapability.NEWS), requiresApiKey = false, official = true,
        homepage = "https://www.sec.gov/about/rss-feeds", termsNote = "Feed RSS ufficiale.", defaultEnabled = true,
    )
    val YAHOO_RSS = ProviderDescriptor(
        ProviderIds.YAHOO_RSS, "Yahoo Finance (RSS titoli)", setOf(ProviderCapability.NEWS), requiresApiKey = false, official = false,
        homepage = "https://finance.yahoo.com", termsNote = "Feed RSS pubblico per titolo; solo titoli e link all'editore originale.", defaultEnabled = true,
    )
    val REDDIT = ProviderDescriptor(
        ProviderIds.REDDIT, "Reddit (API ufficiale OAuth)", setOf(ProviderCapability.SOCIAL), requiresApiKey = true, official = true,
        homepage = "https://www.reddit.com/prefs/apps",
        termsNote = "Richiede un client ID personale di tipo \"installed app\" (nessun secret). L'accesso anonimo è bloccato da Reddit.",
        defaultEnabled = true,
    )

    val all = listOf(YAHOO, ALPHA_VANTAGE, FINNHUB, SEC, CBOE, FRED, ECB, FED_RSS, SEC_RSS, YAHOO_RSS, REDDIT, STOOQ)

    /** Human-readable source name for an id (falls back to the id). */
    fun displayName(id: String): String = all.firstOrNull { it.id == id }?.name ?: id

    /** Short Italian explanation of a stored technical error, for display to the user. */
    fun friendlyError(raw: String?): String? {
        val e = raw ?: return null
        return when {
            "CertPath" in e || "Trust anchor" in e || "SSLHandshake" in e ->
                "Il certificato del sito non è riconosciuto da questo telefono: la connessione è stata rifiutata per sicurezza."
            "UnknownHost" in e || "Unable to resolve host" in e -> "Sito non raggiungibile: controlla la connessione."
            "timeout" in e.lowercase() || "Timeout" in e -> "Il sito non ha risposto in tempo."
            "429" in e -> "Troppe richieste: il sito ha chiesto di riprovare più tardi."
            else -> e.substringBefore(": java.").substringBefore(" java.").take(160)
        }
    }
}
