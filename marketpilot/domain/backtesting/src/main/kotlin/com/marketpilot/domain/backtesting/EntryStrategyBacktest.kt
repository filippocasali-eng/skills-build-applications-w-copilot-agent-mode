package com.marketpilot.domain.backtesting

import com.marketpilot.core.model.Candle
import java.time.LocalDate

enum class EntryStrategy(val label: String, val tranches: Int) {
    LUMP_SUM("Unica soluzione", 1),
    TRANCHE_3("3 tranche mensili", 3),
    TRANCHE_6("6 tranche mensili", 6),
    PAC_12("PAC mensile (12 rate)", 12),
}

data class StrategyStats(
    val strategy: EntryStrategy,
    val windows: Int,
    val meanFinalValue: Double,
    val medianFinalValue: Double,
    val worstFinalValue: Double,
    val bestFinalValue: Double,
    /** Share of windows where lump sum ended above this strategy (null for lump sum itself). */
    val lumpSumWinRate: Double?,
)

data class EntryComparison(
    val amount: Double,
    val horizonSessions: Int,
    val firstWindowStart: LocalDate?,
    val lastWindowStart: LocalDate?,
    val stats: List<StrategyStats>,
    val notes: List<String>,
)

/**
 * Historical comparison of entry methods on real downloaded prices. Rolling windows start every
 * [stepSessions]; each tranche/rate is invested at the close [stepSessions] sessions apart; uninvested
 * cash earns 0% (stated explicitly). Past results do not predict future results.
 */
object EntryStrategyBacktest {
    fun compare(candles: List<Candle>, amount: Double, horizonSessions: Int = 252, stepSessions: Int = 21): EntryComparison? {
        val c = candles.sortedBy { it.date }.map { it.adjClose ?: it.close }
        val dates = candles.sortedBy { it.date }.map { it.date }
        val maxTranches = EntryStrategy.entries.maxOf { it.tranches }
        if (amount <= 0 || horizonSessions < (maxTranches - 1) * stepSessions + 1) return null
        val starts = (0 until c.size - horizonSessions step stepSessions).toList()
        if (starts.size < 3) return null
        val finals = EntryStrategy.entries.associateWith { strategy ->
            starts.map { s ->
                val per = amount / strategy.tranches
                var units = 0.0
                for (i in 0 until strategy.tranches) units += per / c[s + i * stepSessions]
                units * c[s + horizonSessions]
            }
        }
        val lump = finals.getValue(EntryStrategy.LUMP_SUM)
        val stats = finals.map { (strategy, values) ->
            val sorted = values.sorted()
            StrategyStats(
                strategy, values.size, values.average(), sorted[sorted.size / 2], sorted.first(), sorted.last(),
                if (strategy == EntryStrategy.LUMP_SUM) null else values.indices.count { lump[it] > values[it] }.toDouble() / values.size,
            )
        }
        return EntryComparison(
            amount, horizonSessions, dates[starts.first()], dates[starts.last()], stats,
            listOf(
                "Simulazione su ${starts.size} finestre storiche con prezzi reali scaricati (chiusure rettificate se disponibili).",
                "La liquidità non ancora investita non produce interessi (0%). Costi e tasse esclusi.",
                "I risultati passati non garantiscono risultati futuri: il market timing non batte in modo affidabile l'investimento regolare.",
            ),
        )
    }
}
