package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.model.Quote
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.HistoricalDataProvider
import com.marketpilot.data.providers.MarketDataProvider
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.providers.ProviderIds
import com.marketpilot.data.providers.normalization.CandleNormalizer
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/** Parsed Yahoo chart payload (both quote meta and daily bars come from one request). */
data class YahooChart(
    val symbol: String,
    val currency: String?,
    val exchangeTimezone: ZoneId,
    val regularMarketPrice: Double?,
    val regularMarketTime: Instant?,
    val previousClose: Double?,
    val changePercent: Double?,
    val dayHigh: Double?,
    val dayLow: Double?,
    val volume: Long?,
    val fiftyTwoWeekHigh: Double?,
    val fiftyTwoWeekLow: Double?,
    val bars: List<YahooBar>,
)

data class YahooBar(val date: LocalDate, val open: Double?, val high: Double?, val low: Double?, val close: Double?, val adjClose: Double?, val volume: Long?)

object YahooChartParser {
    sealed interface Parsed {
        data class Ok(val chart: YahooChart) : Parsed
        data class Error(val message: String, val notFound: Boolean) : Parsed
    }

    fun parse(body: String): Parsed {
        val root = runCatching { lenientJson.parseToJsonElement(body) }.getOrElse { return Parsed.Error("Risposta non JSON", false) }
        val chart = root["chart"]
        chart["error"]?.let { e ->
            val desc = e["description"].str
            if (desc != null || e["code"].str != null) return Parsed.Error(desc ?: e["code"].str ?: "Errore", e["code"].str == "Not Found")
        }
        val r = chart["result"][0] ?: return Parsed.Error("Nessun risultato", true)
        val meta = r["meta"]
        val zone = runCatching { ZoneId.of(meta["exchangeTimezoneName"].str) }.getOrElse { ZoneOffset.UTC }
        val ts = r["timestamp"].arr.mapNotNull { it.lng }
        val q = r["indicators"]["quote"][0]
        val adj = r["indicators"]["adjclose"][0]["adjclose"].arr
        fun series(name: String) = q[name].arr
        val o = series("open"); val h = series("high"); val l = series("low"); val c = series("close"); val v = series("volume")
        val bars = ts.mapIndexed { i, t ->
            YahooBar(
                Instant.ofEpochSecond(t).atZone(zone).toLocalDate(),
                o.getOrNull(i).dbl, h.getOrNull(i).dbl, l.getOrNull(i).dbl, c.getOrNull(i).dbl, adj.getOrNull(i).dbl, v.getOrNull(i).lng,
            )
        }
        val price = meta["regularMarketPrice"].dbl
        val prev = meta["previousClose"].dbl ?: meta["chartPreviousClose"].dbl
        return Parsed.Ok(
            YahooChart(
                symbol = meta["symbol"].str ?: "",
                currency = meta["currency"].str,
                exchangeTimezone = zone,
                regularMarketPrice = price,
                regularMarketTime = meta["regularMarketTime"].lng?.let { Instant.ofEpochSecond(it) },
                previousClose = prev,
                changePercent = meta["regularMarketChangePercent"].dbl ?: if (price != null && prev != null && prev > 0) (price / prev - 1) * 100 else null,
                dayHigh = meta["regularMarketDayHigh"].dbl,
                dayLow = meta["regularMarketDayLow"].dbl,
                volume = meta["regularMarketVolume"].lng,
                fiftyTwoWeekHigh = meta["fiftyTwoWeekHigh"].dbl,
                fiftyTwoWeekLow = meta["fiftyTwoWeekLow"].dbl,
                bars = bars,
            ),
        )
    }
}

/**
 * Yahoo Finance chart endpoint (unofficial, no key). One request returns both the quote metadata and
 * daily bars. Only bars of completed sessions are kept; the running session is exposed only as a quote.
 */
class YahooChartProvider(
    private val http: HttpFetcher,
    private val clock: AppClock = AppClock.SYSTEM,
    private val baseUrl: String = "https://query1.finance.yahoo.com",
) : MarketDataProvider, HistoricalDataProvider {
    override val descriptor = ProviderCatalog.YAHOO

    private fun url(symbol: String, from: LocalDate?, range: String?): String {
        val enc = URLEncoder.encode(symbol, "UTF-8")
        val params = if (from != null) {
            "period1=${from.atStartOfDay(ZoneOffset.UTC).toEpochSecond()}&period2=${clock.now().epochSecond + 86_400}"
        } else "range=${range ?: "5d"}"
        return "$baseUrl/v8/finance/chart/$enc?$params&interval=1d&includeAdjustedClose=true"
    }

    private suspend fun fetch(instrument: Instrument, from: LocalDate?, range: String?): Pair<String, Any> {
        val sym = instrument.symbolFor(ProviderIds.YAHOO) ?: return "" to ProviderError(ProviderErrorKind.UNSUPPORTED, "Simbolo Yahoo non definito per ${instrument.symbol}")
        val u = url(sym, from, range)
        return when (val r = http.get(u)) {
            is FetchResult.Failed -> u to r
            is FetchResult.Ok -> when (val p = YahooChartParser.parse(r.response.body)) {
                is YahooChartParser.Parsed.Error -> u to ProviderError(if (p.notFound) ProviderErrorKind.EMPTY else ProviderErrorKind.PARSE, "Yahoo: ${p.message}")
                is YahooChartParser.Parsed.Ok -> {
                    val ccy = p.chart.currency
                    if (ccy != null && !ccy.equals(instrument.currency, ignoreCase = false)) {
                        u to ProviderError(ProviderErrorKind.PARSE, "Valuta restituita ($ccy) diversa da quella attesa (${instrument.currency}): dati scartati")
                    } else u to p.chart
                }
            }
        }
    }

    override suspend fun quote(instrument: Instrument): ProviderResult<Quote> {
        val now = clock.now()
        val (u, res) = fetch(instrument, null, "5d")
        return when (res) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, u, now, res, instrument.id)
            is ProviderError -> fail(descriptor, u, now, res, instrument.id)
            is YahooChart -> {
                val price = res.regularMarketPrice ?: return fail(descriptor, u, now, parseError("Prezzo assente"), instrument.id)
                val observed = res.regularMarketTime ?: return fail(descriptor, u, now, parseError("Orario del prezzo assente"), instrument.id)
                val cal = Calendars.forExchange(instrument.exchange)
                ok(
                    descriptor, u,
                    Quote(instrument.id, price, instrument.currency, observed, res.previousClose, res.changePercent, res.dayHigh, res.dayLow, res.volume, res.fiftyTwoWeekHigh, res.fiftyTwoWeekLow),
                    observed, now, MarketSessions.classify(cal, observed, now), instrument.currency, instrument.id,
                )
            }
            else -> fail(descriptor, u, now, parseError("Risposta inattesa"), instrument.id)
        }
    }

    override suspend fun dailyHistory(instrument: Instrument, from: LocalDate): ProviderResult<List<Candle>> {
        val now = clock.now()
        val (u, res) = fetch(instrument, from, null)
        return when (res) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, u, now, res, instrument.id)
            is ProviderError -> fail(descriptor, u, now, res, instrument.id)
            is YahooChart -> {
                val raw = res.bars.mapNotNull { b ->
                    if (b.open == null || b.high == null || b.low == null || b.close == null) null
                    else Candle(instrument.id, b.date, b.open, b.high, b.low, b.close, b.adjClose, b.volume)
                }
                val cal = Calendars.forExchange(instrument.exchange)
                val norm = CandleNormalizer.normalize(raw, cal, now)
                if (norm.candles.isEmpty()) return fail(descriptor, u, now, ProviderError(ProviderErrorKind.EMPTY, "Nessuna barra giornaliera valida"), instrument.id)
                val last = norm.candles.last().date
                ok(
                    descriptor, u, norm.candles, last.atTime(cal.closeTime(last)).atZone(cal.zone).toInstant(), now,
                    MarketSessions.classifyBarDate(cal, last, now), instrument.currency, instrument.id, norm.quality,
                )
            }
            else -> fail(descriptor, u, now, parseError("Risposta inattesa"), instrument.id)
        }
    }

    companion object {
        fun freshnessLabel(f: Freshness) = f.name
    }
}
