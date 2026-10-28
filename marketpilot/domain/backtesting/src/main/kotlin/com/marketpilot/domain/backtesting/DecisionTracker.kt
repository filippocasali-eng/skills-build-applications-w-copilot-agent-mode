package com.marketpilot.domain.backtesting

import com.marketpilot.core.common.TradingCalendar
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.ModelVersions
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.ScoreComponent
import java.time.Instant
import java.time.LocalDate

enum class SnapshotKind { STOCK, ETF, MARKET }

/** Immutable record of a completed daily assessment. Never updated after creation. */
data class DecisionSnapshot(
    val id: String,
    val assessmentDate: LocalDate,
    val createdAt: Instant,
    val instrumentId: String,
    val kind: SnapshotKind,
    val recommendation: Recommendation,
    val score: Double?,
    val components: List<ScoreComponent>,
    val coverage: Double,
    val confidence: Double,
    /** Data timestamps used (e.g. "prices" -> last bar date, "insider" -> retrieval time). */
    val dataTimestamps: Map<String, String>,
    val price: Double?,
    val suggestedEntry: Double?,
    val stop: Double?,
    val target: Double?,
    val regime: MarketRegime,
    val modelVersion: String = ModelVersions.MODEL,
    val strategyVersion: String = ModelVersions.STRATEGY,
) {
    val isDirectionalLong: Boolean get() = recommendation == Recommendation.BUY_CANDIDATE || recommendation == Recommendation.WATCH
}

data class HorizonOutcome(
    val horizonSessions: Int,
    val entryDate: LocalDate,
    val exitDate: LocalDate,
    /** Entry at the open of the session after the assessment (no look-ahead). */
    val entryPrice: Double,
    val exitPrice: Double,
    val grossReturn: Double,
    val netReturn: Double,
    val benchmarkReturns: Map<String, Double?>,
    val maxAdverseExcursion: Double,
    val maxFavorableExcursion: Double,
    val stopHit: Boolean?,
    val targetHit: Boolean?,
    val stopTargetAmbiguous: Boolean,
) {
    fun excessVs(benchmark: String): Double? = benchmarkReturns[benchmark]?.let { netReturn - it }
}

object DecisionEvaluator {
    val HORIZONS = listOf(1, 5, 20, 60, 90)

    private fun openOn(series: List<Candle>, date: LocalDate) = series.firstOrNull { it.date == date }

    /**
     * Evaluates a snapshot at each horizon whose exit session is already available.
     * Horizons are counted in trading sessions using [calendar]; the entry session is day 1.
     * If a required session bar is missing, that horizon is not evaluated (no guessing).
     */
    fun evaluate(
        s: DecisionSnapshot,
        candles: List<Candle>,
        benchmarks: Map<String, List<Candle>>,
        calendar: TradingCalendar,
        roundTripCost: Double,
        horizons: List<Int> = HORIZONS,
    ): List<HorizonOutcome> {
        val series = candles.sortedBy { it.date }
        val entryDate = calendar.nextTradingDay(s.assessmentDate)
        val entryBar = openOn(series, entryDate) ?: return emptyList()
        val entry = entryBar.open
        return horizons.mapNotNull { h ->
            val exitDate = calendar.plusSessions(entryDate, h - 1)
            val exitBar = openOn(series, exitDate) ?: return@mapNotNull null
            val window = series.filter { !it.date.isBefore(entryDate) && !it.date.isAfter(exitDate) }
            if (window.size < calendar.sessionsBetween(entryDate.minusDays(1), exitDate)) return@mapNotNull null // data gap
            val gross = exitBar.close / entry - 1
            val mae = window.minOf { it.low } / entry - 1
            val mfe = window.maxOf { it.high } / entry - 1
            var stopHit: Boolean? = null
            var targetHit: Boolean? = null
            var ambiguous = false
            if (s.stop != null || s.target != null) {
                stopHit = false; targetHit = false
                for (b in window) {
                    val st = s.stop != null && b.low <= s.stop
                    val tg = s.target != null && b.high >= s.target
                    if (st && tg) { ambiguous = true; stopHit = true; break }
                    if (st) { stopHit = true; break }
                    if (tg) { targetHit = true; break }
                }
            }
            val bench = benchmarks.mapValues { (_, b) ->
                val sorted = b.sortedBy { it.date }
                val bi = openOn(sorted, entryDate)
                val bo = openOn(sorted, exitDate)
                if (bi != null && bo != null) bo.close / bi.open - 1 else null
            } + ("CASH" to 0.0)
            HorizonOutcome(h, entryDate, exitDate, entry, exitBar.close, gross, gross - roundTripCost, bench, mae, mfe, stopHit, targetHit, ambiguous)
        }
    }

    data class Bucket(val label: String, val from: Double, val to: Double)

    val BUCKETS = listOf(Bucket("0-40", 0.0, 40.0), Bucket("40-55", 40.0, 55.0), Bucket("55-65", 55.0, 65.0), Bucket("65-75", 65.0, 75.0), Bucket("75-100", 75.0, 100.01))

    data class BucketStats(val bucket: Bucket, val count: Int, val avgNetReturn: Double?, val hitRate: Double?, val avgExcessVsBenchmark: Double?)

    data class Summary(
        val horizon: Int,
        val evaluated: Int,
        val directionalCalls: Int,
        val directionalAccuracy: Double?,
        val avgNetReturnDirectional: Double?,
        val avgExcessDirectional: Double?,
        /** For WAIT/NO_TRADE/HIGH_RISK calls: average benchmark return minus asset return (positive = avoiding helped). */
        val avoidanceValue: Double?,
        val buckets: List<BucketStats>,
        val stopFirstRate: Double?,
        val ambiguousCount: Int,
    )

    /**
     * Aggregates ALL snapshots that reached the horizon (no cherry-picking: every saved snapshot counts).
     * A directional call is "correct" only if its net return beat the [benchmark] over the same window,
     * not merely if the price went up.
     */
    fun summarize(evaluations: List<Pair<DecisionSnapshot, List<HorizonOutcome>>>, horizon: Int, benchmark: String = "SPY"): Summary {
        val rows = evaluations.mapNotNull { (s, o) -> o.firstOrNull { it.horizonSessions == horizon }?.let { s to it } }
        val directional = rows.filter { it.first.isDirectionalLong }
        val correct = directional.count { (_, o) -> (o.excessVs(benchmark) ?: o.netReturn) > 0 }
        val avoid = rows.filter { it.first.recommendation in setOf(Recommendation.WAIT, Recommendation.NO_TRADE, Recommendation.HIGH_RISK) }
            .mapNotNull { (_, o) -> o.benchmarkReturns[benchmark]?.let { it - o.grossReturn } }
        val buckets = BUCKETS.map { b ->
            val inB = rows.filter { (s, _) -> s.score != null && s.score >= b.from && s.score < b.to }
            BucketStats(
                b, inB.size,
                inB.takeIf { it.isNotEmpty() }?.map { it.second.netReturn }?.average(),
                inB.takeIf { it.isNotEmpty() }?.let { l -> l.count { it.second.netReturn > 0 }.toDouble() / l.size },
                inB.mapNotNull { it.second.excessVs(benchmark) }.takeIf { it.isNotEmpty() }?.average(),
            )
        }
        val withStops = rows.filter { it.second.stopHit != null }
        return Summary(
            horizon = horizon,
            evaluated = rows.size,
            directionalCalls = directional.size,
            directionalAccuracy = if (directional.isEmpty()) null else correct.toDouble() / directional.size,
            avgNetReturnDirectional = directional.takeIf { it.isNotEmpty() }?.map { it.second.netReturn }?.average(),
            avgExcessDirectional = directional.mapNotNull { it.second.excessVs(benchmark) }.takeIf { it.isNotEmpty() }?.average(),
            avoidanceValue = avoid.takeIf { it.isNotEmpty() }?.average(),
            buckets = buckets,
            stopFirstRate = withStops.takeIf { it.isNotEmpty() }?.let { l -> l.count { it.second.stopHit == true }.toDouble() / l.size },
            ambiguousCount = rows.count { it.second.stopTargetAmbiguous },
        )
    }
}
