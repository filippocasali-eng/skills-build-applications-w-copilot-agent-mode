package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.HistoricalDataProvider
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.providers.normalization.CandleNormalizer
import java.time.LocalDate

/**
 * Stooq CSV downloads. Since 2026 the endpoint answers with a JavaScript browser-verification page;
 * the app does not try to bypass it and reports the provider as BLOCKED. Disabled by default.
 */
class StooqProvider(private val http: HttpFetcher, private val clock: AppClock = AppClock.SYSTEM) : HistoricalDataProvider {
    override val descriptor = ProviderCatalog.STOOQ

    override suspend fun dailyHistory(instrument: Instrument, from: LocalDate): ProviderResult<List<Candle>> {
        val now = clock.now()
        val sym = if (instrument.isUsListed) "${instrument.symbol.lowercase()}.us" else return fail(descriptor, "stooq", now, ProviderError(ProviderErrorKind.UNSUPPORTED, "Solo titoli USA"), instrument.id)
        val url = "https://stooq.com/q/d/l/?s=$sym&i=d&d1=${from.toString().replace("-", "")}"
        return when (val r = http.get(url)) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, url, now, r, instrument.id)
            is FetchResult.Ok -> {
                val body = r.response.body
                if (looksLikeBotWall(body)) return fail(descriptor, url, now, ProviderError(ProviderErrorKind.BLOCKED, "Stooq richiede una verifica del browser (JavaScript): fonte non utilizzabile"), instrument.id)
                val candles = parseCsv(body, instrument.id)
                val norm = CandleNormalizer.normalize(candles, Calendars.forExchange(instrument.exchange), now)
                if (norm.candles.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Nessun dato Stooq"), instrument.id)
                else ok(descriptor, url, norm.candles, null, now, MarketSessions.classifyBarDate(Calendars.forExchange(instrument.exchange), norm.candles.last().date, now), instrument.currency, instrument.id, norm.quality)
            }
        }
    }

    companion object {
        /** Stooq CSV: Date,Open,High,Low,Close,Volume */
        fun parseCsv(csv: String, instrumentId: String): List<Candle> = csv.lineSequence().drop(1).mapNotNull { line ->
            val p = line.split(',')
            if (p.size < 5) return@mapNotNull null
            val d = runCatching { LocalDate.parse(p[0]) }.getOrNull() ?: return@mapNotNull null
            Candle(instrumentId, d, p[1].toDoubleOrNull() ?: return@mapNotNull null, p[2].toDoubleOrNull() ?: return@mapNotNull null,
                p[3].toDoubleOrNull() ?: return@mapNotNull null, p[4].toDoubleOrNull() ?: return@mapNotNull null, null, p.getOrNull(5)?.toDoubleOrNull()?.toLong())
        }.toList()
    }
}
