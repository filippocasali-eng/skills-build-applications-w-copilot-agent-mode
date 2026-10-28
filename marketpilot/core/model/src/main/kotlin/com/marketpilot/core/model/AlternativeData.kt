package com.marketpilot.core.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate

@Serializable
enum class NewsCategory { EARNINGS, GUIDANCE, FED, INFLATION, EMPLOYMENT, ACQUISITIONS, REGULATION, SECTOR, MARKET, OTHER }

/** A news headline exactly as reported by the publisher (no generated summary). */
@Serializable
data class NewsItem(
    val id: String,
    val headline: String,
    val publisher: String,
    @Serializable(with = InstantSerializer::class) val publishedAt: Instant,
    val url: String,
    val relatedSymbols: List<String> = emptyList(),
    val category: NewsCategory = NewsCategory.OTHER,
    /** Publisher-provided description, verbatim (may be empty). */
    val description: String? = null,
    val providerId: String,
    /** 0..1 relevance computed by the app (automated interpretation, labelled in the UI). */
    val relevance: Double = 0.0,
)

/** SEC Form 4 transaction codes (subset relevant for analysis). */
@Serializable
enum class InsiderTransactionType {
    OPEN_MARKET_PURCHASE, // P
    OPEN_MARKET_SALE, // S
    GRANT_OR_AWARD, // A
    OPTION_EXERCISE, // M, X
    TAX_WITHHOLDING, // F
    GIFT, // G
    OTHER,
    ;

    companion object {
        fun fromCode(code: String): InsiderTransactionType = when (code.trim().uppercase()) {
            "P" -> OPEN_MARKET_PURCHASE
            "S" -> OPEN_MARKET_SALE
            "A" -> GRANT_OR_AWARD
            "M", "X", "C" -> OPTION_EXERCISE
            "F" -> TAX_WITHHOLDING
            "G" -> GIFT
            else -> OTHER
        }
    }
}

@Serializable
data class InsiderTransaction(
    val accessionNumber: String,
    val issuerCik: String,
    val issuerSymbol: String,
    val insiderName: String,
    val insiderRole: String,
    val isDirector: Boolean,
    val isOfficer: Boolean,
    val isTenPercentOwner: Boolean,
    @Serializable(with = LocalDateSerializer::class) val filingDate: LocalDate,
    @Serializable(with = LocalDateSerializer::class) val transactionDate: LocalDate,
    val transactionCode: String,
    val type: InsiderTransactionType,
    val shares: Double,
    val pricePerShare: Double?,
    /** "A" acquired / "D" disposed. */
    val acquiredDisposed: String,
    /** "D" direct / "I" indirect. */
    val ownershipType: String,
    val sharesOwnedAfter: Double?,
    /** True when the filing marks the trade as made under a Rule 10b5-1 plan (automatic). */
    val isRule10b51Plan: Boolean,
    val filingUrl: String,
) {
    val dollarValue: Double? get() = pricePerShare?.let { it * shares }
    val filingDelayDays: Long get() = java.time.temporal.ChronoUnit.DAYS.between(transactionDate, filingDate)
}

/** One line of a 13F-HR information table, with the change versus the previous filing. */
@Serializable
data class InstitutionalHolding(
    val managerCik: String,
    val managerName: String,
    val accessionNumber: String,
    @Serializable(with = LocalDateSerializer::class) val periodOfReport: LocalDate,
    @Serializable(with = LocalDateSerializer::class) val filingDate: LocalDate,
    val issuerName: String,
    val cusip: String,
    val symbol: String?,
    val valueUsd: Double,
    val shares: Double,
    val previousShares: Double?,
    val putCall: String? = null,
    val filingUrl: String,
) {
    val change: HoldingChange
        get() = when {
            previousShares == null -> HoldingChange.UNKNOWN
            previousShares == 0.0 && shares > 0 -> HoldingChange.NEW
            shares == 0.0 -> HoldingChange.SOLD_OUT
            shares > previousShares * 1.02 -> HoldingChange.INCREASED
            shares < previousShares * 0.98 -> HoldingChange.REDUCED
            else -> HoldingChange.UNCHANGED
        }
}

@Serializable
enum class HoldingChange { NEW, INCREASED, REDUCED, SOLD_OUT, UNCHANGED, UNKNOWN }

/** Aggregated Reddit attention for a ticker over a window, from the official Reddit API. */
@Serializable
data class RedditTickerStats(
    val symbol: String,
    @Serializable(with = InstantSerializer::class) val windowStart: Instant,
    @Serializable(with = InstantSerializer::class) val windowEnd: Instant,
    val mentions: Int,
    val previousMentions: Int,
    val uniqueAuthors: Int,
    val totalScore: Int,
    val totalComments: Int,
    /** -1..1 lexicon sentiment (automated interpretation). */
    val sentiment: Double,
    val previousSentiment: Double?,
    /** Share of mentions produced by the single most active author (promotional concentration). */
    val topAuthorShare: Double,
    val subreddits: List<String>,
    val samplePermalinks: List<String>,
) {
    val mentionGrowth: Double? get() = if (previousMentions > 0) mentions.toDouble() / previousMentions - 1.0 else null
    val sentimentAcceleration: Double? get() = previousSentiment?.let { sentiment - it }
}

/** Fundamentals extracted from SEC XBRL company facts (values in the filing currency). */
@Serializable
data class FundamentalsSnapshot(
    val symbol: String,
    val cik: String,
    val currency: String,
    @Serializable(with = LocalDateSerializer::class) val fiscalPeriodEnd: LocalDate?,
    val revenue: Double?,
    val revenuePrevious: Double?,
    val netIncome: Double?,
    val operatingIncome: Double?,
    val operatingCashFlow: Double?,
    val capitalExpenditure: Double?,
    val totalDebt: Double?,
    val stockholdersEquity: Double?,
    val sharesOutstanding: Double?,
    val epsDiluted: Double?,
    val sicDescription: String?,
    val sourceUrl: String,
) {
    val revenueGrowth: Double? get() = if (revenue != null && revenuePrevious != null && revenuePrevious > 0) revenue / revenuePrevious - 1 else null
    val netMargin: Double? get() = if (revenue != null && netIncome != null && revenue > 0) netIncome / revenue else null
    val operatingMargin: Double? get() = if (revenue != null && operatingIncome != null && revenue > 0) operatingIncome / revenue else null
    val freeCashFlow: Double? get() = if (operatingCashFlow != null && capitalExpenditure != null) operatingCashFlow - capitalExpenditure else null
    val debtToEquity: Double? get() = if (totalDebt != null && stockholdersEquity != null && stockholdersEquity > 0) totalDebt / stockholdersEquity else null
}

@Serializable
data class EarningsEvent(
    val symbol: String,
    @Serializable(with = LocalDateSerializer::class) val date: LocalDate,
    val providerId: String,
)
