package com.marketpilot.domain.indicators

import com.marketpilot.core.model.Candle
import java.time.LocalDate
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class IndicatorsTest {
    private fun assertClose(expected: Double, actual: Double?, tol: Double = 1e-9) {
        assertNotNull(actual)
        assertTrue(abs(expected - actual) <= tol, "expected $expected but was $actual")
    }

    @Test fun smaIsAlignedAndNullBeforeWarmup() {
        val s = Indicators.sma(listOf(1.0, 2.0, 3.0, 4.0, 5.0), 3)
        assertNull(s[1])
        assertClose(2.0, s[2]); assertClose(3.0, s[3]); assertClose(4.0, s[4])
    }

    @Test fun emaSeededWithSmaThenSmoothed() {
        val e = Indicators.ema(listOf(1.0, 2.0, 3.0, 4.0), 3)
        assertNull(e[1])
        assertClose(2.0, e[2]) // seed = SMA(1,2,3)
        assertClose(3.0, e[3]) // 4*0.5 + 2*0.5
    }

    /**
     * Wilder's RSI worked example (StockCharts). The published table rounds intermediate averages to
     * two decimals, so it differs by <0.1 from full precision; exact values were recomputed independently.
     */
    @Test fun rsiMatchesWilderReference() {
        val closes = listOf(
            44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61, 46.28,
            46.28, 46.00, 46.03, 46.41, 46.22, 45.64,
        )
        val r = Indicators.rsi(closes, 14)
        assertNull(r[13])
        val published = listOf(70.53, 66.32, 66.55, 69.41, 66.36, 57.97)
        val exact = listOf(70.464, 66.25, 66.48, 69.35, 66.29, 57.92)
        for (k in published.indices) {
            assertClose(exact[k], r[14 + k], 0.01)
            assertClose(published[k], r[14 + k], 0.1)
        }
    }

    @Test fun rsiExtremes() {
        val up = (1..30).map { it.toDouble() }
        assertClose(100.0, Indicators.rsi(up).last())
        val flat = List(30) { 10.0 }
        assertClose(50.0, Indicators.rsi(flat).last())
    }

    @Test fun macdOfConstantSeriesIsZero() {
        val m = Indicators.macd(List(60) { 100.0 })
        assertClose(0.0, m.macd.last()); assertClose(0.0, m.signal.last()); assertClose(0.0, m.histogram.last())
        assertNull(m.signal[30]) // signal needs 26 + 9 - 1 bars
        assertNotNull(m.signal[33])
    }

    @Test fun macdPositiveInUptrend() {
        val m = Indicators.macd((1..80).map { 100.0 * Math.pow(1.01, it.toDouble()) })
        assertTrue(m.macd.last()!! > 0)
    }

    @Test fun atrOfConstantRangeEqualsRange() {
        val n = 30
        val close = List(n) { 100.0 }
        val atr = Indicators.atr(List(n) { 101.0 }, List(n) { 99.0 }, close, 14)
        assertNull(atr[12])
        assertClose(2.0, atr[13]); assertClose(2.0, atr.last())
    }

    @Test fun trueRangeIncludesGaps() {
        val tr = Indicators.trueRange(listOf(10.0, 15.0), listOf(9.0, 14.0), listOf(9.5, 14.5))
        assertClose(5.5, tr[1]) // |15 - 9.5|
    }

    @Test fun drawdownComputation() {
        val dd = Indicators.drawdown(listOf(100.0, 120.0, 90.0, 110.0))!!
        assertClose(-0.25, dd.maxDrawdown)
        assertClose(110.0 / 120.0 - 1, dd.currentDrawdown)
    }

    @Test fun volatilityOfConstantGrowthIsZero() {
        val closes = (0..30).map { 100.0 * Math.pow(1.001, it.toDouble()) }
        assertClose(0.0, Indicators.historicalVolatility(closes, 20), 1e-9)
        assertNull(Indicators.historicalVolatility(closes.take(10), 20))
    }

    @Test fun bollingerBandsAroundMean() {
        val closes = List(19) { 10.0 } + 30.0
        val b = Indicators.bollinger(closes, 20, 2.0)
        assertClose(11.0, b.middle.last())
        assertTrue(b.upper.last()!! > 11.0 && b.lower.last()!! < 11.0)
    }

    @Test fun returnAndRelativeStrength() {
        assertClose(0.1, Indicators.returnOver(listOf(100.0, 105.0, 110.0), 2))
        assertNull(Indicators.returnOver(listOf(100.0), 1))
        assertClose(0.05, Indicators.relativeStrength(listOf(100.0, 110.0), listOf(100.0, 105.0), 1))
    }

    @Test fun supportResistanceUsesOnlyConfirmedPivots() {
        // zig-zag between 90 and 110
        val closes = (0 until 60).map { if ((it / 5) % 2 == 0) 90.0 + (it % 5) * 5 else 110.0 - (it % 5) * 5 }
        val levels = SupportResistance.levels(closes.map { it + 1 }, closes.map { it - 1 }, closes)
        assertTrue(levels.isNotEmpty())
        val price = closes.last()
        SupportResistance.nearestSupport(levels, price)?.let { assertTrue(it.price < price) }
        SupportResistance.nearestResistance(levels, price)?.let { assertTrue(it.price > price) }
    }

    @Test fun technicalSnapshotDoesNotUseFutureBars() {
        val start = LocalDate.of(2024, 1, 1)
        val candles = (0 until 260).map {
            val p = 100.0 + it * 0.2
            Candle("X", start.plusDays(it.toLong()), p, p + 1, p - 1, p, null, 1_000_000)
        }
        val snapFull = TechnicalSnapshot.from(candles)!!
        val snapPrefix = TechnicalSnapshot.from(candles.take(200))!!
        assertEquals(candles[199].date, snapPrefix.lastDate)
        assertClose(candles[199].close, snapPrefix.close)
        assertEquals(Trend.UPTREND, snapFull.trend)
        assertNotNull(snapFull.sma200)
        assertNotNull(snapFull.avgDollarVolume20)
    }
}
