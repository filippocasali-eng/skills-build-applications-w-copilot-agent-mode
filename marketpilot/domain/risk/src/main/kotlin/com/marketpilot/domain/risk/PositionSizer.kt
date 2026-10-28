package com.marketpilot.domain.risk

import kotlin.math.abs
import kotlin.math.floor

data class SizingRequest(
    val equityEur: Double,
    val availableCashEur: Double,
    val entry: Double,
    val stop: Double,
    val fx: FxContext,
    val riskFraction: Double,
    val params: RiskParameters,
    val fees: FeeModel,
    val avgDailyVolume: Double? = null,
    val openPositions: Int = 0,
    val currentOpenRiskEur: Double = 0.0,
    val isLong: Boolean = true,
    val atrPercent: Double? = null,
    val volatility20d: Double? = null,
    val avgDollarVolume20: Double? = null,
    val daysToEarnings: Int? = null,
)

enum class LimitingFactor(val label: String) {
    RISK("budget di rischio"), CASH("liquidità disponibile"), EXPOSURE("esposizione massima"),
    LIQUIDITY("liquidità del titolo"), AGGREGATE_RISK("rischio aggregato"),
}

data class SizingResult(
    val quantity: Int,
    val limitingFactor: LimitingFactor?,
    val riskBudgetEur: Double,
    val perShareRiskEur: Double,
    val estimatedLossAtStopEur: Double,
    val exposureEur: Double,
    val exposurePercent: Double,
    val estimatedEntryCostsEur: Double,
    val candidates: Map<LimitingFactor, Int>,
    val warnings: List<String>,
    val errors: List<String>,
) {
    val isValid: Boolean get() = errors.isEmpty() && quantity > 0
}

/**
 * Position sizing:
 *   risk_budget = equity x risk%, per_share_risk = |entry - stop| (+ stop slippage, costs, FX),
 *   quantity = min(risk-limited, cash-limited, exposure-limited, liquidity-limited).
 * Invalid inputs return errors instead of a size.
 */
object PositionSizer {
    fun size(r: SizingRequest): SizingResult {
        val errors = mutableListOf<String>()
        val warnings = mutableListOf<String>()
        if (r.equityEur <= 0) errors += "Capitale di trading non configurato o pari a zero."
        if (r.entry <= 0 || r.stop <= 0) errors += "Prezzo di ingresso e stop devono essere positivi."
        if (r.riskFraction <= 0 || r.riskFraction > 0.05) errors += "Rischio per trade fuori intervallo (0-5%)."
        if (r.isLong && r.stop >= r.entry) errors += "Per un acquisto lo stop deve essere sotto il prezzo di ingresso."
        if (!r.isLong && !r.params.allowShortSelling) errors += "Vendite allo scoperto disabilitate."
        if (!r.isLong && r.stop <= r.entry) errors += "Per una vendita allo scoperto lo stop deve essere sopra l'ingresso."
        if (r.openPositions >= r.params.maxOpenPositions) errors += "Raggiunto il numero massimo di posizioni aperte (${r.params.maxOpenPositions})."
        errors += r.params.validate()
        errors += r.fees.validate()
        if (errors.isNotEmpty()) return empty(errors)

        val riskBudget = r.equityEur * r.riskFraction
        val remainingAggregate = r.equityEur * r.params.maxAggregateOpenRisk - r.currentOpenRiskEur
        val stopSlip = r.stop * (r.fees.slippage + r.fees.stopExtraSlippage)
        val spreadCost = (r.entry + r.stop) * r.fees.halfSpread
        val pctCosts = (r.entry + r.stop) * (r.fees.percentPerOrder + if (r.fx.currency != "EUR") r.fees.fxConversionCost else 0.0)
        val perShareRiskCcy = abs(r.entry - r.stop) + stopSlip + spreadCost + pctCosts
        val perShareRiskEur = r.fx.toEur(perShareRiskCcy)
        val fixedRoundTrip = 2 * maxOf(r.fees.fixedPerOrder, r.fees.minPerOrder)
        val usableBudget = minOf(riskBudget, remainingAggregate) - fixedRoundTrip
        if (usableBudget <= 0) {
            return empty(listOf("Budget di rischio insufficiente a coprire i costi fissi o rischio aggregato esaurito."))
        }
        val priceEur = r.fx.toEur(r.entry * (1 + r.fees.halfSpread + r.fees.slippage))
        val perShareCashEur = priceEur * (1 + r.fees.percentPerOrder + if (r.fx.currency != "EUR") r.fees.fxConversionCost else 0.0)

        val candidates = linkedMapOf<LimitingFactor, Int>()
        candidates[LimitingFactor.RISK] = floor((riskBudget - fixedRoundTrip) / perShareRiskEur).toInt().coerceAtLeast(0)
        if (remainingAggregate < riskBudget) candidates[LimitingFactor.AGGREGATE_RISK] = floor(usableBudget / perShareRiskEur).toInt()
        val cashForShares = r.availableCashEur - maxOf(r.fees.fixedPerOrder, r.fees.minPerOrder)
        candidates[LimitingFactor.CASH] = if (r.params.allowLeverage) Int.MAX_VALUE else floor(cashForShares / perShareCashEur).toInt().coerceAtLeast(0)
        candidates[LimitingFactor.EXPOSURE] = floor(r.equityEur * r.params.maxPositionExposure / priceEur).toInt()
        r.avgDailyVolume?.let { candidates[LimitingFactor.LIQUIDITY] = floor(it * r.params.maxShareOfAdv).toInt() }

        val (factor, qty) = candidates.minByOrNull { it.value }!!.toPair()
        val quantity = qty.coerceAtLeast(0)
        if (quantity == 0) warnings += "Quantità nulla: limitata da ${factor.label}."

        r.atrPercent?.let { if (it > 0.05) warnings += "Volatilità giornaliera elevata (ATR ${"%.1f".format(it * 100)}%): rischio di gap oltre lo stop." }
        r.volatility20d?.let { if (it > 0.6) warnings += "Volatilità estrema (${"%.0f".format(it * 100)}% annua)." }
        r.avgDollarVolume20?.let { if (it < 20_000_000) warnings += "Liquidità bassa: controvalore medio giornaliero inferiore a 20 milioni USD." }
        if (r.avgDollarVolume20 == null) warnings += "Liquidità non stimabile: volumi non disponibili."
        r.daysToEarnings?.let { if (it in 0..7) warnings += "Trimestrale prevista entro $it giorni: rischio di gap." }
        if (r.daysToEarnings == null) warnings += "Data della prossima trimestrale non disponibile: verifica prima di operare."
        warnings += "Lo stop non garantisce il prezzo di uscita: in caso di gap la perdita può superare la stima."

        val exposure = quantity * priceEur
        val commission = r.fees.commission(exposure)
        return SizingResult(
            quantity = quantity,
            limitingFactor = factor,
            riskBudgetEur = riskBudget,
            perShareRiskEur = perShareRiskEur,
            estimatedLossAtStopEur = quantity * perShareRiskEur + fixedRoundTrip,
            exposureEur = exposure,
            exposurePercent = if (r.equityEur > 0) exposure / r.equityEur else 0.0,
            estimatedEntryCostsEur = commission + r.fees.fxCost(exposure, r.fx.currency),
            candidates = candidates,
            warnings = warnings,
            errors = emptyList(),
        )
    }

    private fun empty(errors: List<String>) = SizingResult(0, null, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, emptyMap(), emptyList(), errors)

    /** Reward/risk ratio for a long trade; null if inputs are invalid. */
    fun riskReward(entry: Double, stop: Double, target: Double): Double? {
        val risk = entry - stop
        val reward = target - entry
        if (risk <= 0 || reward <= 0) return null
        return reward / risk
    }
}
