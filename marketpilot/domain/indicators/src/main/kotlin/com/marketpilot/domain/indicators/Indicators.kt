package com.marketpilot.domain.indicators

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Deterministic technical indicators. Every function returns a list aligned with the input
 * (index i refers to bar i); values are null until enough history exists (no back-filling).
 */
object Indicators {

    fun sma(values: List<Double>, period: Int): List<Double?> {
        require(period > 0)
        val out = MutableList<Double?>(values.size) { null }
        var sum = 0.0
        for (i in values.indices) {
            sum += values[i]
            if (i >= period) sum -= values[i - period]
            if (i >= period - 1) out[i] = sum / period
        }
        return out
    }

    /** EMA seeded with the SMA of the first [period] values. */
    fun ema(values: List<Double>, period: Int): List<Double?> {
        require(period > 0)
        val out = MutableList<Double?>(values.size) { null }
        if (values.size < period) return out
        val k = 2.0 / (period + 1)
        var prev = values.take(period).average()
        out[period - 1] = prev
        for (i in period until values.size) {
            prev = values[i] * k + prev * (1 - k)
            out[i] = prev
        }
        return out
    }

    /** RSI with Wilder smoothing. */
    fun rsi(closes: List<Double>, period: Int = 14): List<Double?> {
        val out = MutableList<Double?>(closes.size) { null }
        if (closes.size <= period) return out
        var gain = 0.0
        var loss = 0.0
        for (i in 1..period) {
            val d = closes[i] - closes[i - 1]
            if (d >= 0) gain += d else loss -= d
        }
        var avgGain = gain / period
        var avgLoss = loss / period
        out[period] = rsiValue(avgGain, avgLoss)
        for (i in period + 1 until closes.size) {
            val d = closes[i] - closes[i - 1]
            avgGain = (avgGain * (period - 1) + max(d, 0.0)) / period
            avgLoss = (avgLoss * (period - 1) + max(-d, 0.0)) / period
            out[i] = rsiValue(avgGain, avgLoss)
        }
        return out
    }

    private fun rsiValue(avgGain: Double, avgLoss: Double): Double = when {
        avgLoss == 0.0 && avgGain == 0.0 -> 50.0
        avgLoss == 0.0 -> 100.0
        else -> 100.0 - 100.0 / (1.0 + avgGain / avgLoss)
    }

    data class Macd(val macd: List<Double?>, val signal: List<Double?>, val histogram: List<Double?>)

    fun macd(closes: List<Double>, fast: Int = 12, slow: Int = 26, signalPeriod: Int = 9): Macd {
        val emaFast = ema(closes, fast)
        val emaSlow = ema(closes, slow)
        val line = closes.indices.map { i -> emaFast[i]?.let { f -> emaSlow[i]?.let { s -> f - s } } }
        val firstValid = line.indexOfFirst { it != null }
        val signal = MutableList<Double?>(closes.size) { null }
        if (firstValid >= 0) {
            val compact = line.subList(firstValid, line.size).map { it!! }
            val sig = ema(compact, signalPeriod)
            sig.forEachIndexed { j, v -> signal[firstValid + j] = v }
        }
        val hist = closes.indices.map { i -> line[i]?.let { m -> signal[i]?.let { s -> m - s } } }
        return Macd(line, signal, hist)
    }

    fun trueRange(high: List<Double>, low: List<Double>, close: List<Double>): List<Double> =
        high.indices.map { i ->
            if (i == 0) high[0] - low[0]
            else maxOf(high[i] - low[i], abs(high[i] - close[i - 1]), abs(low[i] - close[i - 1]))
        }

    /** ATR with Wilder smoothing, seeded with the mean of the first [period] true ranges. */
    fun atr(high: List<Double>, low: List<Double>, close: List<Double>, period: Int = 14): List<Double?> {
        val tr = trueRange(high, low, close)
        val out = MutableList<Double?>(tr.size) { null }
        if (tr.size < period) return out
        var prev = tr.take(period).average()
        out[period - 1] = prev
        for (i in period until tr.size) {
            prev = (prev * (period - 1) + tr[i]) / period
            out[i] = prev
        }
        return out
    }

    data class Bollinger(val middle: List<Double?>, val upper: List<Double?>, val lower: List<Double?>)

    fun bollinger(closes: List<Double>, period: Int = 20, k: Double = 2.0): Bollinger {
        val mid = sma(closes, period)
        val up = MutableList<Double?>(closes.size) { null }
        val lo = MutableList<Double?>(closes.size) { null }
        for (i in closes.indices) {
            val m = mid[i] ?: continue
            val window = closes.subList(i - period + 1, i + 1)
            val sd = sqrt(window.sumOf { (it - m) * (it - m) } / period)
            up[i] = m + k * sd
            lo[i] = m - k * sd
        }
        return Bollinger(mid, up, lo)
    }

    fun logReturns(closes: List<Double>): List<Double> =
        (1 until closes.size).map { ln(closes[it] / closes[it - 1]) }

    /** Annualised historical volatility of daily log returns over [period] sessions (sample stdev). */
    fun historicalVolatility(closes: List<Double>, period: Int = 20, sessionsPerYear: Int = 252): Double? {
        if (closes.size < period + 1) return null
        val r = logReturns(closes.takeLast(period + 1))
        val mean = r.average()
        val variance = r.sumOf { (it - mean) * (it - mean) } / (r.size - 1)
        return sqrt(variance) * sqrt(sessionsPerYear.toDouble())
    }

    data class DrawdownStats(val maxDrawdown: Double, val currentDrawdown: Double, val peak: Double)

    /** Drawdowns as negative fractions (e.g. -0.12 = -12%). */
    fun drawdown(closes: List<Double>): DrawdownStats? {
        if (closes.isEmpty()) return null
        var peak = closes.first()
        var maxDd = 0.0
        for (c in closes) {
            peak = max(peak, c)
            maxDd = min(maxDd, c / peak - 1)
        }
        return DrawdownStats(maxDd, closes.last() / peak - 1, peak)
    }

    /** Return over the last [sessions] bars, null without enough history. */
    fun returnOver(closes: List<Double>, sessions: Int): Double? {
        if (closes.size <= sessions) return null
        return closes.last() / closes[closes.size - 1 - sessions] - 1
    }

    fun highest(values: List<Double>, lookback: Int): Double? =
        if (values.isEmpty()) null else values.takeLast(lookback).maxOrNull()

    fun lowest(values: List<Double>, lookback: Int): Double? =
        if (values.isEmpty()) null else values.takeLast(lookback).minOrNull()

    /** Relative strength: asset return minus benchmark return over the same window. */
    fun relativeStrength(asset: List<Double>, benchmark: List<Double>, sessions: Int): Double? {
        val a = returnOver(asset, sessions) ?: return null
        val b = returnOver(benchmark, sessions) ?: return null
        return a - b
    }

    fun distanceFrom(price: Double, reference: Double?): Double? =
        reference?.takeIf { it > 0 }?.let { price / it - 1 }

    /** Slope of a series over [lookback] bars as a fraction of the starting value. */
    fun slope(series: List<Double?>, lookback: Int): Double? {
        if (series.size <= lookback) return null
        val end = series.last() ?: return null
        val start = series[series.size - 1 - lookback] ?: return null
        return end / start - 1
    }
}
