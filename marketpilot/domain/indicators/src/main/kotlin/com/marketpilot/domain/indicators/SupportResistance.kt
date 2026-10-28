package com.marketpilot.domain.indicators

import kotlin.math.abs

/**
 * Support/resistance from confirmed swing pivots (a pivot needs [wing] bars on both sides,
 * so the most recent [wing] bars can never create a level: no look-ahead).
 * Nearby pivots are clustered within [clusterTolerance] (fraction of price).
 */
object SupportResistance {
    data class Level(val price: Double, val touches: Int, val kind: Kind)
    enum class Kind { SUPPORT, RESISTANCE }

    fun levels(
        high: List<Double>,
        low: List<Double>,
        close: List<Double>,
        lookback: Int = 120,
        wing: Int = 3,
        clusterTolerance: Double = 0.015,
    ): List<Level> {
        val n = close.size
        if (n < wing * 2 + 1) return emptyList()
        val start = maxOf(wing, n - lookback)
        val pivots = mutableListOf<Double>()
        for (i in start until n - wing) {
            val isHigh = (1..wing).all { high[i] >= high[i - it] && high[i] >= high[i + it] }
            val isLow = (1..wing).all { low[i] <= low[i - it] && low[i] <= low[i + it] }
            if (isHigh) pivots += high[i]
            if (isLow) pivots += low[i]
        }
        val clusters = mutableListOf<MutableList<Double>>()
        for (p in pivots.sorted()) {
            val last = clusters.lastOrNull()
            if (last != null && abs(p / last.average() - 1) <= clusterTolerance) last += p else clusters += mutableListOf(p)
        }
        val price = close.last()
        return clusters.map { c ->
            val level = c.average()
            Level(level, c.size, if (level <= price) Kind.SUPPORT else Kind.RESISTANCE)
        }
    }

    fun nearestSupport(levels: List<Level>, price: Double): Level? =
        levels.filter { it.kind == Kind.SUPPORT && it.price < price }.maxByOrNull { it.price }

    fun nearestResistance(levels: List<Level>, price: Double): Level? =
        levels.filter { it.kind == Kind.RESISTANCE && it.price > price }.minByOrNull { it.price }
}
