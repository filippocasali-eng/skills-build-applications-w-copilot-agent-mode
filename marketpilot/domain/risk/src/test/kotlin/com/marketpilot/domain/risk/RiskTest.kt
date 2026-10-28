package com.marketpilot.domain.risk

import com.marketpilot.core.model.Candle
import com.marketpilot.domain.indicators.TechnicalSnapshot
import java.time.LocalDate
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RiskTest {
    private val zeroCost = FeeModel(halfSpread = 0.0, slippage = 0.0, stopExtraSlippage = 0.0)

    private fun req(entry: Double = 100.0, stop: Double = 95.0, cash: Double = 10_000.0, equity: Double = 10_000.0, fees: FeeModel = zeroCost, fx: FxContext = FxContext("USD", 1.10), adv: Double? = null) =
        SizingRequest(equity, cash, entry, stop, fx, 0.005, RiskParameters(), fees, avgDailyVolume = adv, avgDollarVolume20 = 1e9, daysToEarnings = 30)

    @Test fun riskLimitedQuantityMatchesFormula() {
        // budget 50 EUR; per-share risk 5 USD = 4.545 EUR -> floor(11.0) = 11
        val r = PositionSizer.size(req())
        assertEquals(11, r.quantity)
        assertEquals(LimitingFactor.RISK, r.limitingFactor)
        assertTrue(abs(r.riskBudgetEur - 50.0) < 1e-9)
        assertTrue(r.estimatedLossAtStopEur <= 50.0)
    }

    @Test fun cashAndExposureLimits() {
        assertEquals(LimitingFactor.CASH, PositionSizer.size(req(cash = 500.0)).limitingFactor)
        assertEquals(5, PositionSizer.size(req(cash = 500.0)).quantity) // 500 / 90.909
        // tight stop -> exposure (15% of 10k = 1500 EUR -> 16 shares) binds before risk
        val tight = PositionSizer.size(req(stop = 99.9))
        assertEquals(LimitingFactor.EXPOSURE, tight.limitingFactor)
        assertEquals(16, tight.quantity)
        assertEquals(LimitingFactor.LIQUIDITY, PositionSizer.size(req(adv = 500.0)).limitingFactor)
    }

    @Test fun costsReduceQuantity() {
        val withCosts = PositionSizer.size(req(fees = FeeModel(fixedPerOrder = 5.0, fxConversionCost = 0.0025)))
        assertTrue(withCosts.quantity < 11)
    }

    @Test fun invalidInputsAreRejected() {
        assertTrue(PositionSizer.size(req(stop = 105.0)).errors.isNotEmpty())
        assertTrue(PositionSizer.size(req(equity = 0.0)).errors.isNotEmpty())
        assertTrue(PositionSizer.size(req(entry = -1.0)).errors.isNotEmpty())
        val tooMany = PositionSizer.size(req().copy(openPositions = 3))
        assertTrue(tooMany.errors.any { it.contains("posizioni") })
    }

    @Test fun riskRewardAndCommission() {
        assertEquals(2.0, PositionSizer.riskReward(100.0, 95.0, 110.0))
        assertEquals(null, PositionSizer.riskReward(100.0, 105.0, 110.0))
        val f = FeeModel(fixedPerOrder = 1.0, percentPerOrder = 0.001, minPerOrder = 2.0, maxPerOrder = 10.0)
        assertEquals(2.0, f.commission(100.0))
        assertEquals(10.0, f.commission(1_000_000.0))
        assertEquals(0.0, f.fxCost(100.0, "EUR"))
    }

    @Test fun currencyConversion() {
        val fx = FxContext("USD", 1.25)
        assertEquals(80.0, fx.toEur(100.0))
        assertEquals(125.0, fx.fromEur(100.0))
    }

    private fun trendCandles(n: Int, pullbackAtEnd: Boolean): List<Candle> {
        val start = LocalDate.of(2024, 1, 1)
        return (0 until n).map { i ->
            val base = 100.0 + i * 0.3 + 2.0 * kotlin.math.sin(i / 3.0)
            val p = if (pullbackAtEnd && i >= n - 4) base - (i - (n - 5)) * 0.8 else base
            Candle("X", start.plusDays(i.toLong()), p - 0.2, p + 1.0, p - 1.0, p, null, 2_000_000)
        }
    }

    @Test fun plannerProducesValidPlansOrExplicitNoTrade() {
        val snap = TechnicalSnapshot.from(trendCandles(260, pullbackAtEnd = true))!!
        when (val out = TradePlanner.plan(snap, RiskParameters())) {
            is PlanOutcome.Plan -> {
                val p = out.plan
                assertTrue(p.stop < p.entry && p.target1 > p.entry)
                assertTrue(p.riskReward >= 2.0 - 1e-9)
                p.riskRewardToResistance?.let { assertTrue(it >= 2.0) }
            }
            is PlanOutcome.NoTrade -> assertTrue(out.reason.isNotBlank())
        }
        val down = TechnicalSnapshot.from(trendCandles(260, false).map { it.copy(close = 300 - it.close, open = 300 - it.open, high = 300 - it.low, low = 300 - it.high) })!!
        assertTrue(TradePlanner.plan(down, RiskParameters()) is PlanOutcome.NoTrade)
    }
}
