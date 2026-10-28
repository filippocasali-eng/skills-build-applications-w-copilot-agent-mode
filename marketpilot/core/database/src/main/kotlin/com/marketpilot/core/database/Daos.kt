package com.marketpilot.core.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface InstrumentDao {
    @Query("SELECT * FROM instruments ORDER BY symbol")
    fun observeAll(): Flow<List<InstrumentEntity>>

    @Query("SELECT * FROM instruments")
    suspend fun all(): List<InstrumentEntity>

    @Query("SELECT * FROM instruments WHERE id = :id")
    suspend fun byId(id: String): InstrumentEntity?

    @Upsert
    suspend fun upsert(items: List<InstrumentEntity>)

    @Query("DELETE FROM instruments WHERE id = :id AND userAdded = 1")
    suspend fun deleteUserAdded(id: String)
}

@Dao
interface CandleDao {
    @Query("SELECT * FROM candles WHERE instrumentId = :id ORDER BY epochDay")
    suspend fun series(id: String): List<CandleEntity>

    @Query("SELECT * FROM candles WHERE instrumentId = :id AND epochDay >= :fromDay ORDER BY epochDay")
    suspend fun seriesFrom(id: String, fromDay: Long): List<CandleEntity>

    @Query("SELECT * FROM candles WHERE instrumentId = :id ORDER BY epochDay")
    fun observeSeries(id: String): Flow<List<CandleEntity>>

    @Query("SELECT MAX(epochDay) FROM candles WHERE instrumentId = :id")
    suspend fun lastDay(id: String): Long?

    @Upsert
    suspend fun upsert(items: List<CandleEntity>)

    /** Bounded storage: keeps at most the last [keepDays] days of bars per instrument. */
    @Query("DELETE FROM candles WHERE epochDay < :minDay")
    suspend fun pruneOlderThan(minDay: Long)

    @Query("SELECT COUNT(*) FROM candles")
    suspend fun count(): Int
}

@Dao
interface QuoteDao {
    @Query("SELECT * FROM quotes")
    fun observeAll(): Flow<List<QuoteEntity>>

    @Query("SELECT * FROM quotes WHERE instrumentId = :id")
    suspend fun byId(id: String): QuoteEntity?

    @Upsert
    suspend fun upsert(item: QuoteEntity)
}

@Dao
interface ProviderStatusDao {
    @Query("SELECT * FROM provider_status")
    fun observeAll(): Flow<List<ProviderStatusEntity>>

    @Query("SELECT * FROM provider_status WHERE providerId = :id")
    suspend fun byId(id: String): ProviderStatusEntity?

    @Upsert
    suspend fun upsert(item: ProviderStatusEntity)
}

@Dao
interface AnalysisDao {
    @Upsert suspend fun upsertIndicator(item: IndicatorSnapshotEntity)
    @Query("SELECT * FROM indicator_snapshots WHERE instrumentId = :id ORDER BY epochDay DESC LIMIT 1")
    suspend fun latestIndicator(id: String): IndicatorSnapshotEntity?

    @Upsert suspend fun upsertAssessment(item: MarketAssessmentEntity)
    @Query("SELECT * FROM market_assessments ORDER BY epochDay DESC LIMIT 1")
    fun observeLatestAssessment(): Flow<MarketAssessmentEntity?>
    @Query("SELECT * FROM market_assessments ORDER BY epochDay DESC LIMIT 1")
    suspend fun latestAssessment(): MarketAssessmentEntity?

    @Upsert suspend fun upsertEtfScores(items: List<EtfScoreEntity>)
    @Query("SELECT * FROM etf_scores WHERE epochDay = (SELECT MAX(epochDay) FROM etf_scores)")
    fun observeLatestEtfScores(): Flow<List<EtfScoreEntity>>

    @Upsert suspend fun upsertStockScores(items: List<StockScoreEntity>)
    @Query("SELECT * FROM stock_scores WHERE epochDay = (SELECT MAX(epochDay) FROM stock_scores) ORDER BY rankingScore DESC")
    fun observeLatestStockScores(): Flow<List<StockScoreEntity>>
    @Query("SELECT * FROM stock_scores WHERE instrumentId = :id ORDER BY epochDay DESC LIMIT 1")
    suspend fun latestStockScore(id: String): StockScoreEntity?
}

@Dao
interface NewsDao {
    @Query("SELECT * FROM news ORDER BY publishedAtMs DESC LIMIT :limit")
    fun observeLatest(limit: Int): Flow<List<NewsEntity>>

    @Query("SELECT * FROM news WHERE publishedAtMs >= :sinceMs ORDER BY publishedAtMs DESC")
    suspend fun since(sinceMs: Long): List<NewsEntity>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertIgnore(items: List<NewsEntity>)

    @Query("UPDATE news SET relevance = :relevance WHERE id = :id")
    suspend fun setRelevance(id: String, relevance: Double)

    @Query("DELETE FROM news WHERE publishedAtMs < :beforeMs")
    suspend fun prune(beforeMs: Long)
}

@Dao
interface AlternativeDataDao {
    @Upsert suspend fun upsertInsiders(items: List<InsiderTransactionEntity>)
    @Query("SELECT * FROM insider_transactions WHERE issuerSymbol = :symbol ORDER BY transactionEpochDay DESC")
    suspend fun insidersFor(symbol: String): List<InsiderTransactionEntity>
    @Query("SELECT * FROM insider_transactions WHERE transactionEpochDay >= :fromDay ORDER BY filingEpochDay DESC, transactionEpochDay DESC")
    fun observeInsidersSince(fromDay: Long): Flow<List<InsiderTransactionEntity>>
    @Query("SELECT DISTINCT accessionNumber FROM insider_transactions")
    suspend fun knownAccessions(): List<String>
    @Query("SELECT COUNT(*) FROM insider_transactions WHERE issuerSymbol = :symbol")
    suspend fun insiderCount(symbol: String): Int

    @Upsert suspend fun upsertHoldings(items: List<InstitutionalHoldingEntity>)
    @Query("DELETE FROM institutional_holdings WHERE managerCik = :cik")
    suspend fun clearManager(cik: String)
    @Query("SELECT * FROM institutional_holdings ORDER BY managerName, valueUsd DESC")
    fun observeHoldings(): Flow<List<InstitutionalHoldingEntity>>
    @Query("SELECT * FROM institutional_holdings WHERE symbol = :symbol")
    suspend fun holdingsFor(symbol: String): List<InstitutionalHoldingEntity>
    @Query("SELECT COUNT(DISTINCT managerCik) FROM institutional_holdings")
    suspend fun managersLoaded(): Int

    @Upsert suspend fun upsertReddit(items: List<RedditObservationEntity>)
    @Query("SELECT * FROM reddit_observations WHERE windowEndMs = (SELECT MAX(windowEndMs) FROM reddit_observations) ORDER BY mentions DESC")
    fun observeLatestReddit(): Flow<List<RedditObservationEntity>>
    @Query("SELECT * FROM reddit_observations WHERE symbol = :symbol ORDER BY windowEndMs DESC LIMIT 1")
    suspend fun latestRedditFor(symbol: String): RedditObservationEntity?
    @Query("SELECT MAX(windowEndMs) FROM reddit_observations")
    suspend fun latestRedditWindow(): Long?

    @Upsert suspend fun upsertEarnings(items: List<EarningsEventEntity>)
    @Query("SELECT * FROM earnings_events WHERE symbol = :symbol AND epochDay >= :fromDay ORDER BY epochDay LIMIT 1")
    suspend fun nextEarnings(symbol: String, fromDay: Long): EarningsEventEntity?

    @Upsert suspend fun upsertTickers(items: List<SecTickerEntity>)
    @Query("SELECT * FROM sec_tickers")
    suspend fun tickers(): List<SecTickerEntity>
    @Query("SELECT COUNT(*) FROM sec_tickers")
    suspend fun tickerCount(): Int
}

@Dao
interface MacroDao {
    @Upsert suspend fun upsertFx(items: List<FxRateEntity>)
    @Query("SELECT * FROM fx_rates WHERE quote = :quote ORDER BY epochDay")
    suspend fun fxSeries(quote: String): List<FxRateEntity>
    @Query("SELECT * FROM fx_rates WHERE quote = :quote AND epochDay <= :day ORDER BY epochDay DESC LIMIT 1")
    suspend fun fxOnOrBefore(quote: String, day: Long): FxRateEntity?
    @Query("SELECT * FROM fx_rates WHERE quote = :quote ORDER BY epochDay DESC LIMIT 1")
    fun observeLatestFx(quote: String): Flow<FxRateEntity?>

    @Upsert suspend fun upsertMacro(items: List<MacroObservationEntity>)
    @Query("SELECT * FROM macro_observations WHERE seriesId = :id ORDER BY epochDay")
    suspend fun macroSeries(id: String): List<MacroObservationEntity>
}

@Dao
interface WatchlistDao {
    @Query("SELECT * FROM watchlist ORDER BY addedAtMs DESC")
    fun observe(): Flow<List<WatchlistEntity>>
    @Query("SELECT * FROM watchlist")
    suspend fun all(): List<WatchlistEntity>
    @Upsert suspend fun upsert(item: WatchlistEntity)
    @Query("DELETE FROM watchlist WHERE instrumentId = :id")
    suspend fun remove(id: String)
}

@Dao
interface LedgerDao {
    @Query("SELECT * FROM ledger_entries ORDER BY sessionEpochDay, createdAtMs")
    fun observeAll(): Flow<List<LedgerEntryEntity>>
    @Query("SELECT * FROM ledger_entries ORDER BY sessionEpochDay, createdAtMs")
    suspend fun all(): List<LedgerEntryEntity>
    /** Append-only: conflicting ids abort instead of silently replacing an existing entry. */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun append(items: List<LedgerEntryEntity>)
}

@Dao
interface PaperTradingDao {
    @Query("SELECT * FROM paper_orders ORDER BY createdAtMs DESC")
    fun observeOrders(): Flow<List<PaperOrderEntity>>
    @Query("SELECT * FROM paper_orders")
    suspend fun orders(): List<PaperOrderEntity>
    @Upsert suspend fun upsertOrders(items: List<PaperOrderEntity>)

    @Query("SELECT * FROM paper_fills ORDER BY sessionEpochDay DESC")
    fun observeFills(): Flow<List<PaperFillEntity>>
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertFills(items: List<PaperFillEntity>)

    @Query("SELECT * FROM open_positions")
    fun observeOpenPositions(): Flow<List<OpenPositionEntity>>
    @Query("SELECT * FROM closed_positions ORDER BY exitEpochDay DESC")
    fun observeClosedPositions(): Flow<List<ClosedPositionEntity>>
    @Query("DELETE FROM open_positions") suspend fun clearOpen()
    @Query("DELETE FROM closed_positions") suspend fun clearClosed()
    @Insert suspend fun insertOpen(items: List<OpenPositionEntity>)
    @Insert suspend fun insertClosed(items: List<ClosedPositionEntity>)

}

@Dao
interface AlertDao {
    @Query("SELECT * FROM alerts ORDER BY createdAtMs DESC")
    fun observe(): Flow<List<AlertEntity>>
    @Query("SELECT * FROM alerts WHERE enabled = 1")
    suspend fun enabled(): List<AlertEntity>
    @Upsert suspend fun upsert(item: AlertEntity): Long
    @Query("DELETE FROM alerts WHERE id = :id")
    suspend fun delete(id: Long)
}

@Dao
interface JournalDao {
    @Query("SELECT * FROM journal_entries ORDER BY createdAtMs DESC")
    fun observe(): Flow<List<JournalEntryEntity>>
    @Query("SELECT * FROM journal_entries ORDER BY createdAtMs DESC")
    suspend fun all(): List<JournalEntryEntity>
    @Upsert suspend fun upsert(item: JournalEntryEntity): Long
    @Query("DELETE FROM journal_entries WHERE id = :id")
    suspend fun delete(id: Long)
}

/** Decision Tracker: insert-only snapshots (no update or delete methods by design). */
@Dao
interface DecisionDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertSnapshots(items: List<DecisionSnapshotEntity>): List<Long>
    @Query("SELECT * FROM decision_snapshots ORDER BY assessmentEpochDay DESC")
    fun observeSnapshots(): Flow<List<DecisionSnapshotEntity>>
    @Query("SELECT * FROM decision_snapshots")
    suspend fun snapshots(): List<DecisionSnapshotEntity>
    @Upsert suspend fun upsertEvaluations(items: List<EvaluationResultEntity>)
    @Query("SELECT * FROM evaluation_results")
    fun observeEvaluations(): Flow<List<EvaluationResultEntity>>
    @Query("SELECT * FROM evaluation_results")
    suspend fun evaluations(): List<EvaluationResultEntity>
}

@Dao
interface RefreshLogDao {
    @Insert suspend fun insert(item: RefreshLogEntity): Long
    @Query("UPDATE refresh_log SET finishedAtMs = :finishedAtMs, status = :status, summaryJson = :summary WHERE id = :id")
    suspend fun finish(id: Long, finishedAtMs: Long, status: String, summary: String)
    @Query("SELECT * FROM refresh_log ORDER BY startedAtMs DESC LIMIT 1")
    fun observeLatest(): Flow<RefreshLogEntity?>
    @Query("SELECT * FROM refresh_log WHERE status IN ('COMPLETED','PARTIAL') ORDER BY finishedAtMs DESC LIMIT 1")
    fun observeLastSuccessful(): Flow<RefreshLogEntity?>
    @Query("DELETE FROM refresh_log WHERE startedAtMs < :beforeMs")
    suspend fun prune(beforeMs: Long)
}
