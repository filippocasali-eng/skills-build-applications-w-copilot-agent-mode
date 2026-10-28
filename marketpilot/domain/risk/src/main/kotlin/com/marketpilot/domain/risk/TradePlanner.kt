package com.marketpilot.domain.risk

import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.indicators.Trend

enum class SetupType(val label: String) { BREAKOUT("Breakout"), PULLBACK("Pullback in trend"), NONE("Nessun setup") }

/** Model-derived scenario. Never a guarantee: the UI labels every level as a model output. */
data class TradePlan(
    val setup: SetupType,
    val entryLow: Double,
    val entryHigh: Double,
    val entry: Double,
    val entryTrigger: String,
    val stop: Double,
    val stopMethod: String,
    val target1: Double,
    val target2: Double,
    val riskReward: Double,
    val riskRewardToResistance: Double?,
    val notes: List<String>,
)

sealed interface PlanOutcome {
    data class Plan(val plan: TradePlan) : PlanOutcome
    data class NoTrade(val reason: String) : PlanOutcome
}

object TradePlanner {
    fun plan(s: TechnicalSnapshot, params: RiskParameters): PlanOutcome {
        val atr = s.atr14 ?: return PlanOutcome.NoTrade("ATR non disponibile: storico insufficiente.")
        if (s.trend != Trend.UPTREND) return PlanOutcome.NoTrade("Trend non rialzista (${s.trend.label}): nessun setup long.")
        val high20 = s.high20
        val ema21 = s.ema21 ?: s.sma20 ?: return PlanOutcome.NoTrade("Medie di breve non disponibili.")
        val notes = mutableListOf<String>()

        val setup: SetupType
        val entryLow: Double
        val entryHigh: Double
        val entry: Double
        val trigger: String
        var stop: Double
        val stopMethod: String
        when {
            high20 != null && s.close >= high20 * 0.98 && s.close <= high20 + atr -> {
                setup = SetupType.BREAKOUT
                entry = high20 + 0.1 * atr
                entryLow = entry
                entryHigh = entry + 0.5 * atr
                trigger = "Ordine stop d'acquisto sopra il massimo a 20 sedute (${"%.2f".format(high20)})."
                stop = entry - 2 * atr
                stopMethod = "2 x ATR(14) sotto l'ingresso"
                s.support?.let { sup -> if (sup < entry && sup > stop) { stop = sup - 0.25 * atr; } }
            }
            kotlin.math.abs(s.close - ema21) <= 1.0 * atr && (s.rsi14 ?: 50.0) in 35.0..65.0 -> {
                setup = SetupType.PULLBACK
                entryLow = ema21 - 0.5 * atr
                entryHigh = ema21 + 0.5 * atr
                entry = ema21
                trigger = "Ordine limite nella zona della EMA21 (${"%.2f".format(entryLow)}-${"%.2f".format(entryHigh)})."
                val structural = s.support?.takeIf { it < entry }?.let { it - 0.25 * atr }
                stop = maxOf(entry - 2.5 * atr, minOf(entry - 1.5 * atr, structural ?: (entry - 1.5 * atr)))
                stopMethod = if (structural != null) "Sotto il supporto più vicino (limitato a 1,5-2,5 ATR)" else "1,5 x ATR(14) sotto l'ingresso"
            }
            else -> return PlanOutcome.NoTrade("Prezzo lontano sia dal breakout sia dalla zona di pullback: attendere un punto di ingresso.")
        }
        if (stop <= 0 || stop >= entry) return PlanOutcome.NoTrade("Livello di stop non valido.")
        val risk = entry - stop
        val target1 = entry + params.minRiskReward * risk
        val resistance = s.resistance?.takeIf { it > entry }
        val target2 = if (resistance != null && resistance > target1) resistance else entry + (params.minRiskReward + 1) * risk
        val rrRes = resistance?.let { (it - entry) / risk }
        if (rrRes != null && rrRes < params.minRiskReward) {
            return PlanOutcome.NoTrade(
                "Resistenza a ${"%.2f".format(resistance)} troppo vicina: rapporto rendimento/rischio ${"%.2f".format(rrRes)} < ${params.minRiskReward}.",
            )
        }
        if (resistance == null) notes += "Nessuna resistenza storica sopra il prezzo: target basati solo su multipli di rischio."
        notes += "Livelli derivati dal modello su dati giornalieri: scenari, non previsioni."
        return PlanOutcome.Plan(
            TradePlan(setup, entryLow, entryHigh, entry, trigger, stop, stopMethod, target1, target2, (target1 - entry) / risk, rrRes, notes),
        )
    }
}
