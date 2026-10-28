package com.marketpilot.data.providers.normalization

import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.common.TradingCalendar
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.DataQuality
import java.time.Instant
import java.time.LocalDate

data class NormalizedCandles(val candles: List<Candle>, val quality: DataQuality, val droppedPartialSession: Boolean)

/**
 * Normalizes provider bars: sorts, de-duplicates by date, drops impossible bars, drops non-trading-day
 * bars and the bar of a session that has not completed yet (it would change later). Reports completeness
 * against the exchange calendar.
 */
object CandleNormalizer {
    fun normalize(raw: List<Candle>, calendar: TradingCalendar, now: Instant): NormalizedCandles {
        val warnings = mutableListOf<String>()
        val lastCompleted = MarketSessions.lastCompletedSession(calendar, now)
        val byDate = raw.groupBy { it.date }.mapValues { it.value.last() }
        val sorted = byDate.values.sortedBy { it.date }
        val inconsistent = sorted.count { !it.isConsistent() }
        if (inconsistent > 0) warnings += "$inconsistent barre con valori OHLC incoerenti scartate"
        val nonTrading = sorted.count { !calendar.isTradingDay(it.date) }
        if (nonTrading > 0) warnings += "$nonTrading barre in giorni di borsa chiusa scartate"
        val partial = sorted.any { it.date.isAfter(lastCompleted) }
        if (partial) warnings += "Barra della seduta in corso esclusa (non definitiva)"
        val clean = sorted.filter { it.isConsistent() && calendar.isTradingDay(it.date) && !it.date.isAfter(lastCompleted) }
        val completeness = if (clean.size < 2) (if (clean.isEmpty()) 0.0 else 1.0) else {
            val expected = calendar.sessionsBetween(clean.first().date.minusDays(1), clean.last().date)
            (clean.size.toDouble() / expected).coerceAtMost(1.0)
        }
        if (completeness < 0.98 && clean.size > 1) warnings += "Mancano ${"%.1f".format((1 - completeness) * 100)}% delle sedute attese"
        return NormalizedCandles(clean, DataQuality(completeness, warnings), partial)
    }

    /** Merges newly downloaded bars into stored ones: new values replace old ones for the same date. */
    fun merge(existing: List<Candle>, incoming: List<Candle>): List<Candle> =
        (existing.associateBy { it.date } + incoming.associateBy { it.date }).values.sortedBy { it.date }

    fun firstMissingFrom(existing: List<Candle>, defaultStart: LocalDate, overlapSessions: Long = 10): LocalDate =
        existing.maxOfOrNull { it.date }?.minusDays(overlapSessions) ?: defaultStart
}
