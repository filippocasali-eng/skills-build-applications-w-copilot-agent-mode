package com.marketpilot.data.repositories

import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.database.DecisionSnapshotEntity
import com.marketpilot.core.database.EvaluationResultEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.ModelVersions
import com.marketpilot.core.model.Recommendation
import com.marketpilot.domain.backtesting.DecisionEvaluator
import com.marketpilot.domain.backtesting.DecisionSnapshot
import com.marketpilot.domain.backtesting.HorizonOutcome
import com.marketpilot.domain.backtesting.SnapshotKind
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.firstOrNull
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

data class TrackerOverview(
    val snapshots: Int,
    val evaluated: Int,
    val summaries: List<DecisionEvaluator.Summary>,
    val recent: List<Pair<DecisionSnapshot, List<HorizonOutcome>>>,
)

@Singleton
class DecisionTrackerRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val market: MarketDataRepository,
    private val settings: SettingsRepository,
) {
    private fun DecisionSnapshotEntity.toModel() = DecisionSnapshot(
        id, LocalDate.ofEpochDay(assessmentEpochDay), Instant.ofEpochMilli(createdAtMs), instrumentId, SnapshotKind.valueOf(kind),
        runCatching { Recommendation.valueOf(recommendation) }.getOrDefault(Recommendation.INSUFFICIENT_DATA), score,
        runCatching { dbJson.decodeFromString(componentListSerializer, componentsJson) }.getOrDefault(emptyList()), coverage, confidence,
        runCatching { dbJson.decodeFromString(stringMapSerializer, dataTimestampsJson) }.getOrDefault(emptyMap()),
        price, suggestedEntry, stop, target, runCatching { MarketRegime.valueOf(regime) }.getOrDefault(MarketRegime.INSUFFICIENT_DATA), modelVersion, strategyVersion,
    )

    private fun EvaluationResultEntity.toModel() = HorizonOutcome(
        horizonSessions, LocalDate.ofEpochDay(entryEpochDay), LocalDate.ofEpochDay(exitEpochDay), entryPrice, exitPrice, grossReturn, netReturn,
        runCatching { dbJson.decodeFromString(nullableDoubleMapSerializer, benchmarksJson) }.getOrDefault(emptyMap()), mae, mfe, stopHit, targetHit, ambiguous,
    )

    /** Saves one immutable snapshot per instrument per completed session (duplicates are ignored, never overwritten). */
    suspend fun saveSnapshots(asOf: LocalDate, now: Instant): Int {
        val rows = mutableListOf<DecisionSnapshotEntity>()
        val assessment = db.analysisDao().latestAssessment()?.toView()
        val regime = assessment?.regime ?: MarketRegime.INSUFFICIENT_DATA
        assessment?.let { a ->
            rows += DecisionSnapshotEntity(
                "$asOf:MARKET:MARKET", asOf.toEpochDay(), now.toEpochMilli(), InstrumentCatalog.SPY, SnapshotKind.MARKET.name,
                when (a.regime) {
                    MarketRegime.FAVORABLE -> Recommendation.BUY_CANDIDATE
                    MarketRegime.NEUTRAL -> Recommendation.WATCH
                    MarketRegime.CAUTION -> Recommendation.WAIT
                    MarketRegime.HIGH_RISK -> Recommendation.HIGH_RISK
                    MarketRegime.INSUFFICIENT_DATA -> Recommendation.INSUFFICIENT_DATA
                }.name,
                a.marketScore?.toDouble(), dbJson.encodeToString(componentListSerializer, a.components), a.coverage, a.coverage,
                dbJson.encodeToString(stringMapSerializer, mapOf("assessment" to a.asOf.toString())),
                market.candles(InstrumentCatalog.SPY).lastOrNull()?.close, null, null, null, a.regime.name, a.modelVersion, ModelVersions.STRATEGY,
            )
        }
        val scores = db.analysisDao().observeLatestStockScores().firstOrNull() ?: emptyList()
        for (e in scores) {
            if (e.epochDay != asOf.toEpochDay()) continue
            val dto = runCatching { dbJson.decodeFromString(StockScoreDto.serializer(), e.json) }.getOrNull() ?: continue
            rows += DecisionSnapshotEntity(
                "$asOf:${dto.instrumentId}:STOCK", asOf.toEpochDay(), now.toEpochMilli(), dto.instrumentId, SnapshotKind.STOCK.name, dto.recommendation,
                dto.score, dbJson.encodeToString(componentListSerializer, dto.components), dto.coverage, dto.confidence,
                dbJson.encodeToString(stringMapSerializer, mapOf("prices" to (dto.technical?.lastDate ?: "n/d"), "assessment" to dto.asOf)),
                dto.technical?.close, dto.plan?.entry, dto.plan?.stop, dto.plan?.target1, regime.name, ModelVersions.MODEL, ModelVersions.STRATEGY,
            )
        }
        val etfs = db.analysisDao().observeLatestEtfScores().firstOrNull() ?: emptyList()
        for (e in etfs) {
            val dto = runCatching { dbJson.decodeFromString(EtfAnalysisDto.serializer(), e.json) }.getOrNull() ?: continue
            val rec = when (dto.tactical.tone) {
                "POSITIVE" -> Recommendation.BUY_CANDIDATE
                "NEUTRAL" -> Recommendation.WATCH
                "CAUTION", "NEGATIVE" -> Recommendation.WAIT
                else -> Recommendation.INSUFFICIENT_DATA
            }
            rows += DecisionSnapshotEntity(
                "${dto.asOf}:${dto.instrumentId}:ETF", LocalDate.parse(dto.asOf).toEpochDay(), now.toEpochMilli(), dto.instrumentId, SnapshotKind.ETF.name, rec.name,
                dto.opportunityScore?.toDouble(), dbJson.encodeToString(componentListSerializer, dto.components), 1.0, 1.0,
                dbJson.encodeToString(stringMapSerializer, mapOf("prices" to (dto.technical?.lastDate ?: "n/d"))),
                dto.technical?.close, null, null, null, regime.name, ModelVersions.MODEL, ModelVersions.STRATEGY,
            )
        }
        return db.decisionDao().insertSnapshots(rows).count { it != -1L }
    }

    /** Evaluates every snapshot (no cherry-picking) at all horizons whose exit session is available. */
    suspend fun evaluatePending(): Int {
        val existing = db.decisionDao().evaluations().groupBy { it.snapshotId }
        val s = settings.current()
        val fees = SettingsRepository.fees(s)
        val benchmarks = mapOf(
            "SPY" to market.candles(InstrumentCatalog.SPY),
            "QQQ" to market.candles(InstrumentCatalog.QQQ),
            "VWCE" to market.candles(InstrumentCatalog.VWCE),
        )
        val cache = HashMap<String, List<com.marketpilot.core.model.Candle>>()
        var n = 0
        val out = mutableListOf<EvaluationResultEntity>()
        for (e in db.decisionDao().snapshots()) {
            if ((existing[e.id]?.size ?: 0) >= DecisionEvaluator.HORIZONS.size) continue
            val snap = e.toModel()
            val inst = market.instrument(snap.instrumentId) ?: continue
            val candles = cache.getOrPut(inst.id) { market.candles(inst.id) }
            val usd = inst.currency != "EUR"
            val roundTrip = 2 * (fees.halfSpread + fees.slippage + fees.percentPerOrder + if (usd) fees.fxConversionCost else 0.0)
            val outcomes = DecisionEvaluator.evaluate(snap, candles, benchmarks, Calendars.forExchange(inst.exchange), roundTrip)
            val done = existing[e.id]?.map { it.horizonSessions }?.toSet() ?: emptySet()
            outcomes.filter { it.horizonSessions !in done }.forEach { o ->
                out += EvaluationResultEntity(
                    e.id, o.horizonSessions, o.entryDate.toEpochDay(), o.exitDate.toEpochDay(), o.entryPrice, o.exitPrice, o.grossReturn, o.netReturn,
                    dbJson.encodeToString(nullableDoubleMapSerializer, o.benchmarkReturns), o.maxAdverseExcursion, o.maxFavorableExcursion,
                    o.stopHit, o.targetHit, o.stopTargetAmbiguous, System.currentTimeMillis(),
                )
                n++
            }
        }
        if (out.isNotEmpty()) db.decisionDao().upsertEvaluations(out)
        return n
    }

    fun observeOverview(kind: SnapshotKind? = null): Flow<TrackerOverview> =
        combine(db.decisionDao().observeSnapshots(), db.decisionDao().observeEvaluations()) { snaps, evals ->
            val byId = evals.groupBy { it.snapshotId }
            val pairs = snaps.map { it.toModel() }.filter { kind == null || it.kind == kind }.map { it to (byId[it.id]?.map { e -> e.toModel() } ?: emptyList()) }
            TrackerOverview(
                snapshots = pairs.size,
                evaluated = pairs.count { it.second.isNotEmpty() },
                summaries = DecisionEvaluator.HORIZONS.map { h -> DecisionEvaluator.summarize(pairs, h, "SPY") },
                recent = pairs.sortedByDescending { it.first.assessmentDate }.take(60),
            )
        }
}
