package com.marketpilot.domain.backtesting

import com.marketpilot.core.common.Calendars
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.Recommendation
import java.time.Instant
import java.time.LocalDate
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DecisionTrackerTest {
    private val cal = Calendars.NYSE

    private fun sessions(from: LocalDate, n: Int): List<LocalDate> {
        val out = mutableListOf<LocalDate>()
        var d = from
        while (out.size < n) { if (cal.isTradingDay(d)) out += d; d = d.plusDays(1) }
        return out
    }

    private fun candles(id: String, from: LocalDate, n: Int, f: (Int) -> Double) =
        sessions(from, n).mapIndexed { i, d -> val p = f(i); Candle(id, d, p, p * 1.01, p * 0.99, p, null, 1000) }

    private fun snapshot(date: LocalDate, rec: Recommendation, score: Double, stop: Double? = null, target: Double? = null) = DecisionSnapshot(
        "s", date, Instant.parse("2026-01-01T00:00:00Z"), "X", SnapshotKind.STOCK, rec, score, emptyList(), 1.0, 1.0, emptyMap(),
        100.0, 100.0, stop, target, MarketRegime.NEUTRAL,
    )

    @Test fun horizonsUseSessionsAndNextOpenEntry() {
        // Assessment on Thu 2026-04-02; next session is Mon 2026-04-06 (Good Friday holiday).
        val c = candles("X", LocalDate.of(2026, 4, 1), 120) { 100.0 + it }
        val s = snapshot(LocalDate.of(2026, 4, 2), Recommendation.BUY_CANDIDATE, 70.0)
        val out = DecisionEvaluator.evaluate(s, c, emptyMap(), cal, 0.002)
        assertEquals(LocalDate.of(2026, 4, 6), out.first().entryDate)
        assertEquals(listOf(1, 5, 20, 60, 90), out.map { it.horizonSessions })
        val h1 = out.first()
        assertEquals(h1.entryDate, h1.exitDate)
        assertTrue(abs(h1.netReturn - (h1.grossReturn - 0.002)) < 1e-12)
        assertEquals(cal.plusSessions(h1.entryDate, 4), out[1].exitDate)
    }

    @Test fun incompleteHorizonsAreNotEvaluated() {
        val c = candles("X", LocalDate.of(2026, 4, 1), 10) { 100.0 }
        val out = DecisionEvaluator.evaluate(snapshot(LocalDate.of(2026, 4, 1), Recommendation.WATCH, 60.0), c, emptyMap(), cal, 0.0)
        assertEquals(listOf(1, 5), out.map { it.horizonSessions })
    }

    @Test fun successRequiresBeatingBenchmarkNotJustRising() {
        val from = LocalDate.of(2026, 4, 1)
        val asset = candles("X", from, 30) { 100.0 + it * 0.1 } // rises a little
        val spy = candles("SPY", from, 30) { 100.0 + it * 1.0 } // rises a lot
        val s = snapshot(from, Recommendation.BUY_CANDIDATE, 80.0)
        val eval = listOf(s to DecisionEvaluator.evaluate(s, asset, mapOf("SPY" to spy), cal, 0.0))
        val sum = DecisionEvaluator.summarize(eval, 20)
        assertTrue(eval.first().second.first { it.horizonSessions == 20 }.grossReturn > 0)
        assertEquals(0.0, sum.directionalAccuracy)
        assertEquals(1, sum.buckets.first { it.bucket.label == "75-100" }.count)
    }

    @Test fun stopTargetSameBarIsAmbiguousAndConservative() {
        val from = LocalDate.of(2026, 4, 1)
        val c = sessions(from, 10).mapIndexed { i, d ->
            if (i == 2) Candle("X", d, 100.0, 120.0, 80.0, 100.0, null, 1) else Candle("X", d, 100.0, 101.0, 99.0, 100.0, null, 1)
        }
        val out = DecisionEvaluator.evaluate(snapshot(from, Recommendation.BUY_CANDIDATE, 70.0, stop = 90.0, target = 110.0), c, emptyMap(), cal, 0.0)
        val h5 = out.first { it.horizonSessions == 5 }
        assertTrue(h5.stopTargetAmbiguous)
        assertEquals(true, h5.stopHit)
        assertTrue(h5.maxAdverseExcursion <= -0.19)
    }

    @Test fun entryStrategyComparisonOnSeries() {
        val c = candles("V", LocalDate.of(2020, 1, 1), 1000) { 100.0 * Math.pow(1.0004, it.toDouble()) }
        val r = EntryStrategyBacktest.compare(c, 10_000.0)!!
        assertEquals(4, r.stats.size)
        // In a steadily rising market lump sum wins every window.
        assertEquals(1.0, r.stats.first { it.strategy == EntryStrategy.PAC_12 }.lumpSumWinRate)
        assertEquals(null, EntryStrategyBacktest.compare(c.take(100), 10_000.0))
    }
}
