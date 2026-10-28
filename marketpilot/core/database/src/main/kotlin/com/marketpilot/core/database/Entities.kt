package com.marketpilot.core.database

import androidx.room.Entity
import androidx.room.Index

// Storage conventions: instants are UTC epoch milliseconds, session dates are epoch days in the
// exchange calendar, enums are stored by name. JSON columns hold small, bounded explanation payloads.

@Entity(tableName = "instruments")
data class InstrumentEntity(
    @androidx.room.PrimaryKey val id: String,
    val symbol: String,
    val name: String,
    val assetClass: String,
    val exchange: String,
    val currency: String,
    val isin: String?,
    val trackedIndex: String?,
    val isUcits: Boolean,
    val domicile: String,
    val distribution: String,
    val terPercent: Double?,
    val providerSymbolsJson: String,
    val rolesCsv: String,
    val sector: String?,
    val cik: String?,
    val exposureFamily: String?,
    val userAdded: Boolean,
)

@Entity(tableName = "candles", primaryKeys = ["instrumentId", "epochDay"], indices = [Index("instrumentId")])
data class CandleEntity(
    val instrumentId: String,
    val epochDay: Long,
    val open: Double,
    val high: Double,
    val low: Double,
    val close: Double,
    val adjClose: Double?,
    val volume: Long?,
    val providerId: String,
    val retrievedAtMs: Long,
)

@Entity(tableName = "quotes")
data class QuoteEntity(
    @androidx.room.PrimaryKey val instrumentId: String,
    val price: Double,
    val currency: String,
    val observedAtMs: Long,
    val previousClose: Double?,
    val changePercent: Double?,
    val dayHigh: Double?,
    val dayLow: Double?,
    val volume: Long?,
    val high52: Double?,
    val low52: Double?,
    val providerId: String,
    val sourceUrl: String,
    val retrievedAtMs: Long,
    val freshness: String,
)

@Entity(tableName = "provider_status")
data class ProviderStatusEntity(
    @androidx.room.PrimaryKey val providerId: String,
    val state: String,
    val lastSuccessAtMs: Long?,
    val lastAttemptAtMs: Long?,
    val lastError: String?,
    val successCount: Int,
    val failureCount: Int,
)

/** Computed technical indicators for the last bar of an instrument (one row per session). */
@Entity(tableName = "indicator_snapshots", primaryKeys = ["instrumentId", "epochDay"])
data class IndicatorSnapshotEntity(
    val instrumentId: String,
    val epochDay: Long,
    val json: String,
    val computedAtMs: Long,
)

@Entity(tableName = "market_assessments")
data class MarketAssessmentEntity(
    @androidx.room.PrimaryKey val epochDay: Long,
    val regime: String,
    val marketScore: Int?,
    val etfScore: Int?,
    val swingScore: Int?,
    val coverage: Double,
    val componentsJson: String,
    val etfComponentsJson: String,
    val risksJson: String,
    val summary: String,
    val modelVersion: String,
    val createdAtMs: Long,
)

@Entity(tableName = "etf_scores", primaryKeys = ["instrumentId", "epochDay"])
data class EtfScoreEntity(
    val instrumentId: String,
    val epochDay: Long,
    val score: Int?,
    val json: String,
    val createdAtMs: Long,
)

@Entity(tableName = "stock_scores", primaryKeys = ["instrumentId", "epochDay"], indices = [Index("epochDay")])
data class StockScoreEntity(
    val instrumentId: String,
    val epochDay: Long,
    val score: Double?,
    val rankingScore: Double?,
    val coverage: Double,
    val confidence: Double,
    val recommendation: String,
    val risk: String,
    val json: String,
    val createdAtMs: Long,
)

@Entity(tableName = "news", indices = [Index("publishedAtMs")])
data class NewsEntity(
    @androidx.room.PrimaryKey val id: String,
    val headline: String,
    val publisher: String,
    val publishedAtMs: Long,
    val url: String,
    val relatedCsv: String,
    val category: String,
    val description: String?,
    val providerId: String,
    val relevance: Double,
    val retrievedAtMs: Long,
)

@Entity(tableName = "insider_transactions", indices = [Index("issuerSymbol"), Index("transactionEpochDay")])
data class InsiderTransactionEntity(
    @androidx.room.PrimaryKey val key: String,
    val accessionNumber: String,
    val issuerCik: String,
    val issuerSymbol: String,
    val insiderName: String,
    val insiderRole: String,
    val isDirector: Boolean,
    val isOfficer: Boolean,
    val isTenPercentOwner: Boolean,
    val filingEpochDay: Long,
    val transactionEpochDay: Long,
    val transactionCode: String,
    val type: String,
    val shares: Double,
    val pricePerShare: Double?,
    val acquiredDisposed: String,
    val ownershipType: String,
    val sharesOwnedAfter: Double?,
    val isRule10b51Plan: Boolean,
    val filingUrl: String,
    val retrievedAtMs: Long,
)

@Entity(tableName = "institutional_holdings", primaryKeys = ["managerCik", "accessionNumber", "cusip", "putCall"], indices = [Index("symbol")])
data class InstitutionalHoldingEntity(
    val managerCik: String,
    val managerName: String,
    val accessionNumber: String,
    val periodEpochDay: Long,
    val filingEpochDay: Long,
    val issuerName: String,
    val cusip: String,
    val symbol: String?,
    val valueUsd: Double,
    val shares: Double,
    val previousShares: Double?,
    /** Empty string for plain share positions (primary keys cannot be null). */
    val putCall: String,
    val filingUrl: String,
    val retrievedAtMs: Long,
)

@Entity(tableName = "reddit_observations", primaryKeys = ["symbol", "windowEndMs"])
data class RedditObservationEntity(
    val symbol: String,
    val windowStartMs: Long,
    val windowEndMs: Long,
    val mentions: Int,
    val previousMentions: Int,
    val uniqueAuthors: Int,
    val totalScore: Int,
    val totalComments: Int,
    val sentiment: Double,
    val previousSentiment: Double?,
    val topAuthorShare: Double,
    val subredditsCsv: String,
    val permalinksCsv: String,
    val retrievedAtMs: Long,
)

@Entity(tableName = "watchlist")
data class WatchlistEntity(
    @androidx.room.PrimaryKey val instrumentId: String,
    val addedAtMs: Long,
    val note: String?,
)

/**
 * Append-only cash ledger for BOTH virtual accounts (account = ETF | TRADING). ETF and Trading
 * portfolio transactions are the rows of the respective account; balances are always derived.
 */
@Entity(tableName = "ledger_entries", indices = [Index("account"), Index("instrumentId"), Index("referenceId")])
data class LedgerEntryEntity(
    @androidx.room.PrimaryKey val id: String,
    val account: String,
    val kind: String,
    val amountEur: Double,
    val sessionEpochDay: Long,
    val createdAtMs: Long,
    val instrumentId: String?,
    val quantity: Double?,
    val priceCcy: Double?,
    val currency: String,
    val fxRate: Double?,
    val referenceId: String?,
    val transferId: String?,
    val note: String?,
)

@Entity(tableName = "paper_orders", indices = [Index("status"), Index("instrumentId")])
data class PaperOrderEntity(
    @androidx.room.PrimaryKey val id: String,
    val account: String,
    val instrumentId: String,
    val exchange: String,
    val currency: String,
    val side: String,
    val type: String,
    val quantity: Int,
    val filledQuantity: Int,
    val limitPrice: Double?,
    val stopPrice: Double?,
    val timeInForce: String,
    val expiresOnEpochDay: Long?,
    val createdAtMs: Long,
    val firstEligibleEpochDay: Long,
    val status: String,
    val role: String,
    val parentId: String?,
    val ocoGroupId: String?,
    val bracketStopLoss: Double?,
    val bracketTakeProfit: Double?,
    val triggered: Boolean,
    val lastEvaluatedEpochDay: Long?,
    val statusReason: String?,
    val reservedCashEur: Double,
    val note: String?,
    val updatedAtMs: Long,
)

@Entity(tableName = "paper_fills", indices = [Index("orderId")])
data class PaperFillEntity(
    @androidx.room.PrimaryKey val id: String,
    val orderId: String,
    val account: String,
    val instrumentId: String,
    val side: String,
    val sessionEpochDay: Long,
    val quantity: Int,
    val priceCcy: Double,
    val currency: String,
    val eurToCcy: Double,
    val grossEur: Double,
    val commissionEur: Double,
    val fxCostEur: Double,
    val basis: String,
    val ambiguous: Boolean,
)

/** Materialized open positions (rebuilt from the ledger after every reconciliation). */
@Entity(tableName = "open_positions", primaryKeys = ["account", "instrumentId"])
data class OpenPositionEntity(
    val account: String,
    val instrumentId: String,
    val quantity: Double,
    val currency: String,
    val avgCostEur: Double,
    val avgPriceCcy: Double,
    val costBasisEur: Double,
    val openedOnEpochDay: Long?,
    val updatedAtMs: Long,
)

/** Materialized closed positions (each sell is one record), rebuilt from the ledger. */
@Entity(tableName = "closed_positions", indices = [Index("account")])
data class ClosedPositionEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val rowId: Long = 0,
    val account: String,
    val instrumentId: String,
    val entryEpochDay: Long?,
    val exitEpochDay: Long,
    val quantity: Double,
    val costEur: Double,
    val proceedsEur: Double,
)

@Entity(tableName = "alerts")
data class AlertEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: String,
    val instrumentId: String?,
    val threshold: Double?,
    val direction: String?,
    val enabled: Boolean,
    val createdAtMs: Long,
    val lastTriggeredAtMs: Long?,
    val lastMessage: String?,
)

@Entity(tableName = "journal_entries")
data class JournalEntryEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val createdAtMs: Long,
    val updatedAtMs: Long,
    val account: String?,
    val instrumentId: String?,
    val orderId: String?,
    val title: String,
    val body: String,
    val setup: String?,
    val emotion: String?,
    val lessons: String?,
    val tagsCsv: String,
)

/** Immutable daily recommendation snapshot. The DAO exposes no update/delete for this table. */
@Entity(
    tableName = "decision_snapshots",
    indices = [Index(value = ["assessmentEpochDay", "instrumentId", "kind"], unique = true), Index("instrumentId")],
)
data class DecisionSnapshotEntity(
    @androidx.room.PrimaryKey val id: String,
    val assessmentEpochDay: Long,
    val createdAtMs: Long,
    val instrumentId: String,
    val kind: String,
    val recommendation: String,
    val score: Double?,
    val componentsJson: String,
    val coverage: Double,
    val confidence: Double,
    val dataTimestampsJson: String,
    val price: Double?,
    val suggestedEntry: Double?,
    val stop: Double?,
    val target: Double?,
    val regime: String,
    val modelVersion: String,
    val strategyVersion: String,
)

@Entity(tableName = "evaluation_results", primaryKeys = ["snapshotId", "horizonSessions"])
data class EvaluationResultEntity(
    val snapshotId: String,
    val horizonSessions: Int,
    val entryEpochDay: Long,
    val exitEpochDay: Long,
    val entryPrice: Double,
    val exitPrice: Double,
    val grossReturn: Double,
    val netReturn: Double,
    val benchmarksJson: String,
    val mae: Double,
    val mfe: Double,
    val stopHit: Boolean?,
    val targetHit: Boolean?,
    val ambiguous: Boolean,
    val evaluatedAtMs: Long,
)

@Entity(tableName = "fx_rates", primaryKeys = ["quote", "epochDay"])
data class FxRateEntity(val quote: String, val epochDay: Long, val rate: Double, val providerId: String)

@Entity(tableName = "macro_observations", primaryKeys = ["seriesId", "epochDay"])
data class MacroObservationEntity(val seriesId: String, val epochDay: Long, val value: Double, val providerId: String)

@Entity(tableName = "earnings_events", primaryKeys = ["symbol", "epochDay"])
data class EarningsEventEntity(val symbol: String, val epochDay: Long, val providerId: String, val retrievedAtMs: Long)

@Entity(tableName = "sec_tickers", indices = [Index("cik")])
data class SecTickerEntity(@androidx.room.PrimaryKey val ticker: String, val cik: String, val title: String)

@Entity(tableName = "refresh_log")
data class RefreshLogEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val startedAtMs: Long,
    val finishedAtMs: Long?,
    val trigger: String,
    val status: String,
    val summaryJson: String,
)
