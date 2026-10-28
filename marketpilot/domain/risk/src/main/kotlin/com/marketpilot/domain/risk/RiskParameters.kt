package com.marketpilot.domain.risk

/** Configurable risk-control defaults (not guarantees). Percentages are fractions (0.005 = 0.5%). */
data class RiskParameters(
    val riskPerTrade: Double = 0.005,
    val maxPositionExposure: Double = 0.15,
    val maxOpenPositions: Int = 3,
    val maxAggregateOpenRisk: Double = 0.02,
    val minRiskReward: Double = 2.0,
    val allowLeverage: Boolean = false,
    val allowShortSelling: Boolean = false,
    /** Max share of 20-day average daily volume a simulated order may represent. */
    val maxShareOfAdv: Double = 0.01,
) {
    fun validate(): List<String> = buildList {
        if (riskPerTrade <= 0 || riskPerTrade > 0.05) add("Rischio per trade deve essere tra 0% e 5%.")
        if (maxPositionExposure <= 0 || maxPositionExposure > 1) add("Esposizione massima per posizione non valida.")
        if (maxOpenPositions < 1) add("Numero massimo di posizioni deve essere almeno 1.")
        if (maxAggregateOpenRisk < riskPerTrade) add("Rischio aggregato inferiore al rischio per trade.")
        if (minRiskReward < 0.5) add("Rapporto rischio/rendimento minimo troppo basso.")
    }
}

/**
 * Broker-like cost model. All costs are applied to simulated fills and to sizing.
 * Default values are placeholders for a typical online broker and must be configured by the user.
 */
data class FeeModel(
    val fixedPerOrder: Double = 0.0,
    val percentPerOrder: Double = 0.0,
    val minPerOrder: Double = 0.0,
    val maxPerOrder: Double? = null,
    /** Currency of the fixed amounts (account base currency). */
    val feeCurrency: String = "EUR",
    /** FX conversion spread charged when the instrument currency differs from EUR. */
    val fxConversionCost: Double = 0.0,
    /** Half bid/ask spread assumption (fraction of price). */
    val halfSpread: Double = 0.0005,
    /** Slippage applied to market/stop fills (fraction of price). */
    val slippage: Double = 0.0005,
    /** Additional slippage when a stop is triggered (stops are not guaranteed). */
    val stopExtraSlippage: Double = 0.001,
) {
    /** Commission for an order with notional [notionalBase] expressed in the account currency. */
    fun commission(notionalBase: Double): Double {
        val raw = fixedPerOrder + percentPerOrder * notionalBase
        val withMin = maxOf(raw, minPerOrder)
        return maxPerOrder?.let { minOf(withMin, it) } ?: withMin
    }

    fun fxCost(notionalBase: Double, instrumentCurrency: String, baseCurrency: String = "EUR"): Double =
        if (instrumentCurrency.equals(baseCurrency, ignoreCase = true)) 0.0 else notionalBase * fxConversionCost

    fun validate(): List<String> = buildList {
        if (fixedPerOrder < 0 || percentPerOrder < 0 || minPerOrder < 0) add("Le commissioni non possono essere negative.")
        if (halfSpread < 0 || slippage < 0 || stopExtraSlippage < 0 || fxConversionCost < 0) add("Spread/slippage non validi.")
    }
}

/** Converts instrument-currency amounts to the EUR base: 1 EUR = [eurToCcy] units of currency. */
data class FxContext(val currency: String, val eurToCcy: Double) {
    init { require(eurToCcy > 0) { "Tasso di cambio non valido" } }
    fun toEur(amountCcy: Double) = amountCcy / eurToCcy
    fun fromEur(amountEur: Double) = amountEur * eurToCcy

    companion object { val EUR = FxContext("EUR", 1.0) }
}
