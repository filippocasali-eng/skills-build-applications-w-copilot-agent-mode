package com.marketpilot.data.repositories

import com.marketpilot.core.model.ScoreComponent
import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.risk.TradePlan
import com.marketpilot.domain.scoring.EtfAnalysis
import com.marketpilot.domain.scoring.EtfDecision
import com.marketpilot.domain.scoring.StockScore
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.nullable
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

internal val dbJson = Json { ignoreUnknownKeys = true; encodeDefaults = true; allowSpecialFloatingPointValues = true }

internal val componentListSerializer = ListSerializer(ScoreComponent.serializer())
internal val stringListSerializer = ListSerializer(String.serializer())
internal val stringMapSerializer = MapSerializer(String.serializer(), String.serializer())
internal val nullableDoubleMapSerializer = MapSerializer(String.serializer(), Double.serializer().nullable)

@Serializable
data class TechnicalDto(
    val lastDate: String,
    val close: Double,
    val bars: Int,
    val change1d: Double?, val change5d: Double?, val change21d: Double?, val change63d: Double?, val change252d: Double?,
    val high52w: Double?, val low52w: Double?, val rsi14: Double?,
    val sma20: Double?, val sma50: Double?, val sma200: Double?, val ema9: Double?, val ema21: Double?,
    val macd: Double?, val macdSignal: Double?, val macdHistogram: Double?,
    val atr14: Double?, val volatility20d: Double?, val maxDrawdown: Double?, val currentDrawdown: Double?,
    val support: Double?, val resistance: Double?, val trend: String, val avgDollarVolume20: Double?,
    val distanceFromSma50: Double?, val distanceFromSma200: Double?,
) {
    companion object {
        fun from(s: TechnicalSnapshot) = TechnicalDto(
            s.lastDate.toString(), s.close, s.bars, s.change1d, s.change5d, s.change21d, s.change63d, s.change252d,
            s.high52w, s.low52w, s.rsi14, s.sma20, s.sma50, s.sma200, s.ema9, s.ema21, s.macd, s.macdSignal, s.macdHistogram,
            s.atr14, s.volatility20d, s.maxDrawdown, s.currentDrawdown, s.support, s.resistance, s.trend.label, s.avgDollarVolume20,
            s.distanceFromSma50, s.distanceFromSma200,
        )
    }
}

@Serializable
data class TradePlanDto(
    val setup: String, val entryLow: Double, val entryHigh: Double, val entry: Double, val entryTrigger: String,
    val stop: Double, val stopMethod: String, val target1: Double, val target2: Double, val riskReward: Double,
    val riskRewardToResistance: Double?, val notes: List<String>,
) {
    companion object {
        fun from(p: TradePlan) = TradePlanDto(
            p.setup.label, p.entryLow, p.entryHigh, p.entry, p.entryTrigger, p.stop, p.stopMethod, p.target1, p.target2, p.riskReward, p.riskRewardToResistance, p.notes,
        )
    }
}

@Serializable
data class StockScoreDto(
    val instrumentId: String,
    val symbol: String,
    val name: String,
    val asOf: String,
    val score: Double?,
    val rankingScore: Double?,
    val coverage: Double,
    val confidence: Double,
    val recommendation: String,
    val risk: String,
    val components: List<ScoreComponent>,
    val technical: TechnicalDto?,
    val plan: TradePlanDto?,
    val noTradeReason: String?,
    val explanation: String,
    val bullCase: List<String>,
    val baseCase: String,
    val bearCase: List<String>,
    val reasonsToAvoid: List<String>,
    val catalyst: String,
    val insiderSummary: String?,
    val insiderPurchases: Int,
    val redditSummary: String?,
    val redditHype: String?,
    val excluded: Boolean,
    val exclusionReason: String?,
    val momentumRaw: Double?,
    val isBreakout: Boolean,
) {
    companion object {
        fun from(s: StockScore) = StockScoreDto(
            s.instrument.id, s.instrument.symbol, s.instrument.name, s.asOf.toString(), s.score, s.rankingScore, s.coverage, s.confidence,
            s.recommendation.name, s.risk.name, s.components, s.snapshot?.let(TechnicalDto::from), s.plan?.let(TradePlanDto::from), s.noTradeReason,
            s.explanation, s.bullCase, s.baseCase, s.bearCase, s.reasonsToAvoid, s.catalyst, s.insiderSignal?.explanation,
            s.insiderSignal?.purchases?.size ?: 0, s.redditSignal?.explanation, s.redditSignal?.hypeRisk?.label, s.excluded, s.exclusionReason, s.momentumRaw, s.isBreakout,
        )
    }
}

@Serializable
data class EtfDecisionDto(val title: String, val verdict: String, val tone: String, val reasons: List<String>) {
    companion object { fun from(d: EtfDecision) = EtfDecisionDto(d.title, d.verdict, d.tone.name, d.reasons) }
}

@Serializable
data class EtfAnalysisDto(
    val instrumentId: String,
    val asOf: String,
    val opportunityScore: Int?,
    val components: List<ScoreComponent>,
    val technical: TechnicalDto?,
    val longTerm: EtfDecisionDto,
    val tactical: EtfDecisionDto,
    val concentration: EtfDecisionDto,
) {
    companion object {
        fun from(a: EtfAnalysis) = EtfAnalysisDto(
            a.instrument.id, a.asOf.toString(), a.opportunityScore, a.components, a.snapshot?.let(TechnicalDto::from),
            EtfDecisionDto.from(a.longTerm), EtfDecisionDto.from(a.tactical), EtfDecisionDto.from(a.concentration),
        )
    }
}

@Serializable
data class RefreshSummaryDto(
    val steps: List<RefreshStepDto>,
    val updatedInstruments: Int,
    val failedInstruments: List<String>,
    val reconciledFills: Int,
    val snapshotsSaved: Int,
    val notes: List<String>,
)

@Serializable
data class RefreshStepDto(val name: String, val status: String, val detail: String, val durationMs: Long)
