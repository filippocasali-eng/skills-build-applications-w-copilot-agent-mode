package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.EarningsEvent
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.model.Quote
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.EarningsCalendarProvider
import com.marketpilot.data.providers.HistoricalDataProvider
import com.marketpilot.data.providers.MarketDataProvider
import com.marketpilot.data.providers.NewsProvider
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.providers.ProviderIds
import com.marketpilot.data.providers.normalization.CandleNormalizer
import com.marketpilot.domain.scoring.NewsClassifier
import kotlinx.coroutines.CancellationException
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.scalars.ScalarsConverterFactory
import retrofit2.http.GET
import retrofit2.http.Query
import java.io.IOException
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Retrofit services for the key-based REST APIs (keys are user-supplied, never bundled). */
interface AlphaVantageApi {
    @GET("query")
    suspend fun query(
        @Query("function") function: String,
        @Query("symbol") symbol: String?,
        @Query("apikey") apiKey: String,
        @Query("outputsize") outputSize: String? = null,
        @Query("horizon") horizon: String? = null,
    ): Response<String>
}

interface FinnhubApi {
    @GET("api/v1/quote")
    suspend fun quote(@Query("symbol") symbol: String, @Query("token") token: String): Response<String>

    @GET("api/v1/company-news")
    suspend fun companyNews(@Query("symbol") symbol: String, @Query("from") from: String, @Query("to") to: String, @Query("token") token: String): Response<String>

    @GET("api/v1/calendar/earnings")
    suspend fun earnings(@Query("from") from: String, @Query("to") to: String, @Query("token") token: String): Response<String>
}

internal sealed interface ApiBody {
    data class Ok(val body: String) : ApiBody
    data class Err(val error: ProviderError) : ApiBody
}

internal suspend fun callApi(http: HttpFetcher, host: String, block: suspend () -> Response<String>): ApiBody {
    http.limiter.acquire(host)
    return try {
        val r = block()
        when {
            r.isSuccessful -> ApiBody.Ok(r.body() ?: "")
            r.code() == 429 -> ApiBody.Err(ProviderError(ProviderErrorKind.RATE_LIMITED, "Limite di richieste raggiunto", 429))
            r.code() == 401 || r.code() == 403 -> ApiBody.Err(ProviderError(ProviderErrorKind.AUTH, "Chiave API non valida o non autorizzata", r.code()))
            else -> ApiBody.Err(ProviderError(ProviderErrorKind.HTTP, "Errore HTTP ${r.code()}", r.code()))
        }
    } catch (e: CancellationException) {
        throw e
    } catch (e: IOException) {
        ApiBody.Err(ProviderError(ProviderErrorKind.NETWORK, "Errore di rete: ${e.message ?: e.javaClass.simpleName}"))
    }
}

object AlphaVantageParser {
    /** Detects the textual rate-limit / premium notices Alpha Vantage returns with HTTP 200. */
    fun notice(body: String): String? {
        val root = runCatching { lenientJson.parseToJsonElement(body) }.getOrNull() ?: return "Risposta non JSON"
        return root["Note"].str ?: root["Information"].str ?: root["Error Message"].str
    }

    fun daily(body: String, instrumentId: String): List<Candle> {
        val root = lenientJson.parseToJsonElement(body)
        val series = root["Time Series (Daily)"] as? kotlinx.serialization.json.JsonObject ?: return emptyList()
        return series.mapNotNull { (date, v) ->
            val d = runCatching { LocalDate.parse(date) }.getOrNull() ?: return@mapNotNull null
            Candle(instrumentId, d, v["1. open"].dbl ?: return@mapNotNull null, v["2. high"].dbl ?: return@mapNotNull null,
                v["3. low"].dbl ?: return@mapNotNull null, v["4. close"].dbl ?: return@mapNotNull null, null, v["5. volume"].lng)
        }.sortedBy { it.date }
    }

    /** EARNINGS_CALENDAR CSV: symbol,name,reportDate,fiscalDateEnding,estimate,currency,... */
    fun earningsCsv(csv: String, symbols: Set<String>): List<EarningsEvent> = csv.lineSequence().drop(1).mapNotNull { line ->
        val p = splitCsvLine(line)
        if (p.size < 3) return@mapNotNull null
        val sym = p[0].uppercase()
        if (sym !in symbols) return@mapNotNull null
        EarningsEvent(sym, runCatching { LocalDate.parse(p[2]) }.getOrNull() ?: return@mapNotNull null, ProviderIds.ALPHA_VANTAGE)
    }.toList()
}

class AlphaVantageProvider(
    private val http: HttpFetcher,
    private val apiKey: () -> String?,
    private val clock: AppClock = AppClock.SYSTEM,
    baseUrl: String = "https://www.alphavantage.co/",
) : HistoricalDataProvider, MarketDataProvider, EarningsCalendarProvider {
    override val descriptor = ProviderCatalog.ALPHA_VANTAGE
    private val api = Retrofit.Builder().baseUrl(baseUrl).client(http.client).addConverterFactory(ScalarsConverterFactory.create()).build().create(AlphaVantageApi::class.java)
    private val host = java.net.URI(baseUrl).host

    private fun src(function: String, symbol: String?) = "https://www.alphavantage.co/query?function=$function" + (symbol?.let { "&symbol=$it" } ?: "")

    override suspend fun dailyHistory(instrument: Instrument, from: LocalDate): ProviderResult<List<Candle>> {
        val now = clock.now()
        val url = src("TIME_SERIES_DAILY", instrument.symbol)
        val key = apiKey()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, url, now, notConfigured(descriptor, "Chiave API"), instrument.id)
        if (!instrument.isUsListed) return fail(descriptor, url, now, ProviderError(ProviderErrorKind.UNSUPPORTED, "Solo strumenti quotati negli USA"), instrument.id)
        val sym = instrument.symbolFor(ProviderIds.ALPHA_VANTAGE) ?: instrument.symbol
        return when (val b = callApi(http, host) { api.query("TIME_SERIES_DAILY", sym, key, outputSize = "compact") }) {
            is ApiBody.Err -> fail(descriptor, url, now, b.error, instrument.id)
            is ApiBody.Ok -> {
                AlphaVantageParser.notice(b.body)?.let { return fail(descriptor, url, now, ProviderError(ProviderErrorKind.RATE_LIMITED, "Alpha Vantage: $it"), instrument.id) }
                val cal = Calendars.forExchange(instrument.exchange)
                val norm = CandleNormalizer.normalize(AlphaVantageParser.daily(b.body, instrument.id).filter { !it.date.isBefore(from) }, cal, now)
                if (norm.candles.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Nessuna barra"), instrument.id)
                else ok(descriptor, url, norm.candles, null, now, MarketSessions.classifyBarDate(cal, norm.candles.last().date, now), instrument.currency, instrument.id,
                    norm.quality.copy(warnings = norm.quality.warnings + "Piano gratuito: solo ~100 sedute recenti (output compatto)."))
            }
        }
    }

    override suspend fun quote(instrument: Instrument): ProviderResult<Quote> {
        val now = clock.now()
        val url = src("GLOBAL_QUOTE", instrument.symbol)
        val key = apiKey()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, url, now, notConfigured(descriptor, "Chiave API"), instrument.id)
        return when (val b = callApi(http, host) { api.query("GLOBAL_QUOTE", instrument.symbol, key) }) {
            is ApiBody.Err -> fail(descriptor, url, now, b.error, instrument.id)
            is ApiBody.Ok -> {
                AlphaVantageParser.notice(b.body)?.let { return fail(descriptor, url, now, ProviderError(ProviderErrorKind.RATE_LIMITED, "Alpha Vantage: $it"), instrument.id) }
                val q = lenientJson.parseToJsonElement(b.body)["Global Quote"]
                val price = q["05. price"].dbl ?: return fail(descriptor, url, now, parseError("Prezzo assente"), instrument.id)
                val day = q["07. latest trading day"].str?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return fail(descriptor, url, now, parseError("Data assente"), instrument.id)
                val cal = Calendars.forExchange(instrument.exchange)
                // Global Quote gives only the trading day: the observation time is the session close (end-of-day value).
                val observed = day.atTime(cal.closeTime(day)).atZone(cal.zone).toInstant()
                ok(descriptor, url, Quote(instrument.id, price, instrument.currency, observed, q["08. previous close"].dbl, q["10. change percent"].str?.removeSuffix("%")?.toDoubleOrNull(),
                    q["03. high"].dbl, q["04. low"].dbl, q["06. volume"].lng), observed, now, MarketSessions.classifyBarDate(cal, day, now), instrument.currency, instrument.id)
            }
        }
    }

    override suspend fun upcomingEarnings(symbols: Set<String>): ProviderResult<List<EarningsEvent>> {
        val now = clock.now()
        val url = src("EARNINGS_CALENDAR", null)
        val key = apiKey()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, url, now, notConfigured(descriptor, "Chiave API"))
        return when (val b = callApi(http, host) { api.query("EARNINGS_CALENDAR", null, key, horizon = "3month") }) {
            is ApiBody.Err -> fail(descriptor, url, now, b.error)
            is ApiBody.Ok -> if (b.body.trimStart().startsWith("{")) fail(descriptor, url, now, ProviderError(ProviderErrorKind.RATE_LIMITED, AlphaVantageParser.notice(b.body) ?: "Risposta inattesa"))
            else ok(descriptor, url, AlphaVantageParser.earningsCsv(b.body, symbols), now, now, Freshness.END_OF_DAY)
        }
    }
}

object FinnhubParser {
    fun news(body: String, symbol: String): List<NewsItem> = lenientJson.parseToJsonElement(body).arr.mapNotNull { n ->
        val url = n["url"].str?.takeIf { it.startsWith("https://") } ?: return@mapNotNull null
        val headline = n["headline"].str?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
        NewsItem(
            id = RssNewsProvider.sha1(url), headline = headline, publisher = n["source"].str ?: "Finnhub",
            publishedAt = Instant.ofEpochSecond(n["datetime"].lng ?: return@mapNotNull null), url = url, relatedSymbols = listOf(symbol),
            category = NewsClassifier.categorize(headline, n["summary"].str), description = n["summary"].str?.take(500), providerId = ProviderIds.FINNHUB,
        )
    }

    fun earnings(body: String, symbols: Set<String>): List<EarningsEvent> =
        lenientJson.parseToJsonElement(body)["earningsCalendar"].arr.mapNotNull { e ->
            val s = e["symbol"].str?.uppercase()?.takeIf { it in symbols } ?: return@mapNotNull null
            EarningsEvent(s, e["date"].str?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return@mapNotNull null, ProviderIds.FINNHUB)
        }
}

class FinnhubProvider(
    private val http: HttpFetcher,
    private val apiKey: () -> String?,
    private val clock: AppClock = AppClock.SYSTEM,
    baseUrl: String = "https://finnhub.io/",
) : NewsProvider, EarningsCalendarProvider {
    override val descriptor = ProviderCatalog.FINNHUB
    private val api = Retrofit.Builder().baseUrl(baseUrl).client(http.client).addConverterFactory(ScalarsConverterFactory.create()).build().create(FinnhubApi::class.java)
    private val host = java.net.URI(baseUrl).host

    override suspend fun news(symbols: List<String>, since: LocalDate): ProviderResult<List<NewsItem>> {
        val now = clock.now()
        val url = "https://finnhub.io/api/v1/company-news"
        val key = apiKey()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, url, now, notConfigured(descriptor, "Chiave API"))
        val to = now.atZone(ZoneOffset.UTC).toLocalDate()
        val out = mutableListOf<NewsItem>()
        var err: ProviderError? = null
        for (s in symbols) {
            when (val b = callApi(http, host) { api.companyNews(s, since.toString(), to.toString(), key) }) {
                is ApiBody.Err -> { err = b.error; if (b.error.kind == ProviderErrorKind.AUTH || b.error.kind == ProviderErrorKind.RATE_LIMITED) break }
                is ApiBody.Ok -> runCatching { out += FinnhubParser.news(b.body, s) }.onFailure { err = parseError("Risposta Finnhub non valida") }
            }
        }
        if (out.isEmpty() && err != null) return fail(descriptor, url, now, err!!)
        return ok(descriptor, url, out.toList(), out.maxOfOrNull { it.publishedAt }, now, Freshness.DELAYED)
    }

    override suspend fun upcomingEarnings(symbols: Set<String>): ProviderResult<List<EarningsEvent>> {
        val now = clock.now()
        val url = "https://finnhub.io/api/v1/calendar/earnings"
        val key = apiKey()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, url, now, notConfigured(descriptor, "Chiave API"))
        val from = now.atZone(ZoneOffset.UTC).toLocalDate()
        return when (val b = callApi(http, host) { api.earnings(from.toString(), from.plusDays(60).toString(), key) }) {
            is ApiBody.Err -> fail(descriptor, url, now, b.error)
            is ApiBody.Ok -> runCatching { FinnhubParser.earnings(b.body, symbols) }.fold(
                { ok(descriptor, url, it, now, now, Freshness.END_OF_DAY) },
                { fail(descriptor, url, now, parseError("Calendario Finnhub non valido")) },
            )
        }
    }
}
