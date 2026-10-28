package com.marketpilot.data.repositories

import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.database.MarketAssessmentEntity
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.core.model.ScoreComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

data class MarketAssessmentView(
    val asOf: LocalDate,
    val regime: MarketRegime,
    val marketScore: Int?,
    val etfScore: Int?,
    val swingScore: Int?,
    val coverage: Double,
    val components: List<ScoreComponent>,
    val etfComponents: List<ScoreComponent>,
    val risks: List<String>,
    val summary: String,
    val modelVersion: String,
    val createdAt: Instant,
)

internal fun MarketAssessmentEntity.toView() = MarketAssessmentView(
    LocalDate.ofEpochDay(epochDay), runCatching { MarketRegime.valueOf(regime) }.getOrDefault(MarketRegime.INSUFFICIENT_DATA), marketScore, etfScore, swingScore, coverage,
    runCatching { dbJson.decodeFromString(componentListSerializer, componentsJson) }.getOrDefault(emptyList()),
    runCatching { dbJson.decodeFromString(componentListSerializer, etfComponentsJson) }.getOrDefault(emptyList()),
    runCatching { dbJson.decodeFromString(stringListSerializer, risksJson) }.getOrDefault(emptyList()),
    summary, modelVersion, Instant.ofEpochMilli(createdAtMs),
)

/** Read side for computed analyses and alternative data stored by the refresh engine. */
@Singleton
class AnalysisRepository @Inject constructor(private val db: MarketPilotDatabase) {
    fun observeAssessment(): Flow<MarketAssessmentView?> = db.analysisDao().observeLatestAssessment().map { it?.toView() }

    fun observeEtfAnalyses(): Flow<List<EtfAnalysisDto>> = db.analysisDao().observeLatestEtfScores().map { l ->
        l.mapNotNull { runCatching { dbJson.decodeFromString(EtfAnalysisDto.serializer(), it.json) }.getOrNull() }
    }

    fun observeStockScores(): Flow<List<StockScoreDto>> = db.analysisDao().observeLatestStockScores().map { l ->
        l.mapNotNull { runCatching { dbJson.decodeFromString(StockScoreDto.serializer(), it.json) }.getOrNull() }
    }

    suspend fun stockScore(id: String): StockScoreDto? =
        db.analysisDao().latestStockScore(id)?.let { runCatching { dbJson.decodeFromString(StockScoreDto.serializer(), it.json) }.getOrNull() }

    suspend fun technical(id: String): TechnicalDto? =
        db.analysisDao().latestIndicator(id)?.let { runCatching { dbJson.decodeFromString(TechnicalDto.serializer(), it.json) }.getOrNull() }

    fun observeNews(limit: Int = 200): Flow<List<NewsItem>> = db.newsDao().observeLatest(limit).map { l -> l.map { it.toModel() } }

    fun observeInsiders(since: LocalDate): Flow<List<InsiderTransaction>> = db.alternativeDataDao().observeInsidersSince(since.toEpochDay()).map { l -> l.map { it.toModel() } }

    suspend fun insidersFor(symbol: String): List<InsiderTransaction> = db.alternativeDataDao().insidersFor(symbol).map { it.toModel() }

    fun observeHoldings(): Flow<List<InstitutionalHolding>> = db.alternativeDataDao().observeHoldings().map { l -> l.map { it.toModel() } }

    suspend fun holdingsFor(symbol: String): List<InstitutionalHolding> = db.alternativeDataDao().holdingsFor(symbol).map { it.toModel() }

    fun observeReddit(): Flow<List<RedditTickerStats>> = db.alternativeDataDao().observeLatestReddit().map { l -> l.map { it.toModel() } }

    suspend fun redditFor(symbol: String): RedditTickerStats? = db.alternativeDataDao().latestRedditFor(symbol)?.toModel()

    suspend fun fundamentals(id: String): Pair<FundamentalsSnapshot, Instant>? = db.cacheDao().fundamentals(id)?.let { e ->
        runCatching { dbJson.decodeFromString(FundamentalsSnapshot.serializer(), e.json) }.getOrNull()?.let { it to Instant.ofEpochMilli(e.retrievedAtMs) }
    }

    suspend fun nextEarnings(symbol: String, from: LocalDate): LocalDate? = db.alternativeDataDao().nextEarnings(symbol, from.toEpochDay())?.let { LocalDate.ofEpochDay(it.epochDay) }

    suspend fun newsFor(symbol: String, since: Instant): List<NewsItem> =
        db.newsDao().since(since.toEpochMilli()).map { it.toModel() }.filter { symbol in it.relatedSymbols }
}
