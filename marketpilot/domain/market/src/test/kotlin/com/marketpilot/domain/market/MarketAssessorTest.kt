package com.marketpilot.domain.market

import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.core.model.MarketRegime
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class MarketAssessorTest {
    private val asOf = LocalDate.of(2026, 10, 27)

    private fun series(id: String, n: Int, drift: Double, crashLast: Int = 0): List<Candle> = (0 until n).map { i ->
        var p = 100.0 * Math.pow(1 + drift, i.toDouble())
        if (crashLast > 0 && i >= n - crashLast) p *= Math.pow(0.97, (i - (n - crashLast) + 1).toDouble())
        Candle(id, asOf.minusDays((n - 1 - i).toLong()), p, p * 1.005, p * 0.995, p, null, 1_000_000)
    }

    private fun vix(level: Double) = (0 until 30).map { MacroObservation("VIX", asOf.minusDays((29 - it).toLong()), level) }

    @Test fun insufficientDataIsExplicit() {
        val a = MarketAssessor.assess(MarketInputs(asOf, series("SPY", 50, 0.001), series("QQQ", 50, 0.001)))
        assertEquals(MarketRegime.INSUFFICIENT_DATA, a.regime)
        assertNull(a.marketScore)
        assertTrue(a.coverage < 1.0)
    }

    @Test fun calmUptrendIsFavorable() {
        val sectors = listOf("XLK", "XLF", "XLE", "XLV", "XLY", "XLP", "XLI").associateWith { series(it, 260, 0.0015) }
        val universe = (1..25).associate { "S$it" to series("S$it", 260, 0.001) }
        val a = MarketAssessor.assess(MarketInputs(asOf, series("SPY", 300, 0.001), series("QQQ", 300, 0.0012), vix(13.0), sectors = sectors, universe = universe))
        assertEquals(MarketRegime.FAVORABLE, a.regime)
        assertTrue(a.marketScore!! >= 65)
        assertTrue(a.components.all { it.explanation.isNotBlank() })
    }

    @Test fun crashWithHighVixIsHighRisk() {
        val a = MarketAssessor.assess(MarketInputs(asOf, series("SPY", 300, 0.0005, crashLast = 12), series("QQQ", 300, 0.0005, crashLast = 12), vix(42.0)))
        assertEquals(MarketRegime.HIGH_RISK, a.regime)
        assertTrue(a.risks.any { it.contains("VIX") })
        assertTrue((a.swingOpportunityScore ?: 0) <= 30)
    }

    @Test fun futureBarsAreIgnored() {
        val spy = series("SPY", 300, 0.001) + Candle("SPY", asOf.plusDays(1), 1.0, 1.0, 1.0, 1.0, null, 1)
        val a = MarketAssessor.assess(MarketInputs(asOf, spy, series("QQQ", 300, 0.001), vix(14.0)))
        assertTrue(a.regime != MarketRegime.HIGH_RISK)
    }
}
