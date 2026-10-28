package com.marketpilot.domain.scoring

import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.NewsCategory
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.RedditTickerStats
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.log10
import kotlin.math.roundToInt

data class InsiderSignal(
    val score: Double,
    val purchases: List<InsiderTransaction>,
    val distinctBuyers: Int,
    val totalPurchaseUsd: Double,
    val discretionarySales: Int,
    val excludedTransactions: Int,
    val explanation: String,
)

/**
 * Insider Conviction Score. Only open-market purchases (code P) not flagged as Rule 10b5-1 count
 * as conviction. Grants, option exercises, tax withholding, gifts and plan trades are excluded.
 */
object InsiderConviction {
    fun score(transactions: List<InsiderTransaction>, asOf: LocalDate, windowDays: Long = 90): InsiderSignal {
        val recent = transactions.filter { !it.transactionDate.isAfter(asOf) && ChronoUnit.DAYS.between(it.transactionDate, asOf) <= windowDays }
        val purchases = recent.filter { it.type == InsiderTransactionType.OPEN_MARKET_PURCHASE && !it.isRule10b51Plan && it.acquiredDisposed == "A" }
        val sales = recent.filter { it.type == InsiderTransactionType.OPEN_MARKET_SALE && !it.isRule10b51Plan }
        val excluded = recent.size - purchases.size - sales.size
        val buyers = purchases.map { it.insiderName }.distinct()
        val total = purchases.sumOf { it.dollarValue ?: 0.0 }
        if (purchases.isEmpty()) {
            val s = (30.0 - minOf(15.0, sales.size * 3.0)).coerceAtLeast(10.0)
            return InsiderSignal(
                s, emptyList(), 0, 0.0, sales.size, excluded,
                "Nessun acquisto sul mercato negli ultimi $windowDays giorni" +
                    (if (sales.isNotEmpty()) "; ${sales.size} vendite discrezionali." else ".") +
                    (if (excluded > 0) " $excluded operazioni escluse (assegnazioni, esercizi di opzioni, piani 10b5-1, ecc.)." else ""),
            )
        }
        val roleBonus = purchases.maxOf {
            val role = it.insiderRole.uppercase()
            when {
                "CEO" in role || "CHIEF EXECUTIVE" in role || "CFO" in role || "CHIEF FINANCIAL" in role -> 5.0
                it.isOfficer -> 3.0
                it.isDirector -> 2.0
                else -> 1.0
            }
        }
        val valuePts = if (total > 0) (log10(total / 10_000.0).coerceAtLeast(0.0) * 8).coerceAtMost(20.0) else 0.0
        val cluster = purchases.groupBy { it.transactionDate.withDayOfMonth(1) }.any { g -> g.value.map { it.insiderName }.distinct().size >= 3 }
        var score = 50 + minOf(25.0, buyers.size * 8.0) + valuePts + roleBonus - minOf(15.0, sales.size * 3.0)
        if (cluster) score += 5
        return InsiderSignal(
            score.coerceIn(0.0, 100.0), purchases, buyers.size, total, sales.size, excluded,
            "${purchases.size} ${if (purchases.size == 1) "acquisto" else "acquisti"} sul mercato da ${buyers.size} insider " +
                "per circa ${String.format(java.util.Locale.ITALY, "%,.0f", total)} USD negli ultimi $windowDays giorni" +
                (if (cluster) " (acquisti concentrati: più insider nello stesso mese)" else "") + ".",
        )
    }
}

enum class HypeRisk(val label: String) { LOW("Basso"), MODERATE("Moderato"), HIGH("Alto") }

data class RedditSignal(val score: Double, val hypeRisk: HypeRisk, val explanation: String)

/** Reddit attention scoring with explicit hype controls: hype can never produce a strong signal. */
object RedditSignalScorer {
    const val MIN_MENTIONS = 5

    fun score(stats: RedditTickerStats): RedditSignal {
        if (stats.mentions < MIN_MENTIONS) {
            return RedditSignal(45.0, HypeRisk.LOW, "Attenzione trascurabile (${stats.mentions} menzioni nella finestra).")
        }
        val growth = stats.mentionGrowth
        val authorRatio = stats.uniqueAuthors.toDouble() / stats.mentions
        val hype = when {
            stats.topAuthorShare > 0.3 || authorRatio < 0.3 -> HypeRisk.HIGH
            (growth ?: 0.0) > 3.0 -> HypeRisk.HIGH
            (growth ?: 0.0) > 1.0 -> HypeRisk.MODERATE
            else -> HypeRisk.LOW
        }
        var s = 50 + stats.sentiment * 20 + minOf(15.0, (growth ?: 0.0).coerceAtLeast(0.0) * 7.5) + minOf(10.0, stats.uniqueAuthors / 5.0)
        stats.sentimentAcceleration?.let { s += (it * 10).coerceIn(-5.0, 5.0) }
        val cap = when (hype) { HypeRisk.HIGH -> 55.0; HypeRisk.MODERATE -> 70.0; HypeRisk.LOW -> 100.0 }
        s = s.coerceIn(0.0, cap)
        val growthTxt = growth?.let { " (${if (it >= 0) "+" else ""}${(it * 100).roundToInt()}% vs periodo precedente)" } ?: ""
        return RedditSignal(
            s, hype,
            "${stats.mentions} menzioni$growthTxt da ${stats.uniqueAuthors} autori; sentiment ${"%.2f".format(stats.sentiment)} (interpretazione automatica). " +
                "Rischio hype: ${hype.label.lowercase()}" + if (hype != HypeRisk.LOW) ", punteggio limitato a ${cap.roundToInt()}." else ".",
        )
    }
}

/** Keyword-based categorisation and catalyst tone. Results are automated interpretation, labelled as such. */
object NewsClassifier {
    private val categoryRules: List<Pair<NewsCategory, List<String>>> = listOf(
        NewsCategory.FED to listOf("federal reserve", "fomc", "powell", "fed ", "interest rate", "rate cut", "rate hike", "monetary policy"),
        NewsCategory.INFLATION to listOf("inflation", "cpi", "pce", "consumer price", "producer price"),
        NewsCategory.EMPLOYMENT to listOf("payroll", "jobs report", "unemployment", "jobless", "labor market"),
        NewsCategory.GUIDANCE to listOf("guidance", "outlook", "forecast", "raises full-year", "cuts full-year"),
        NewsCategory.EARNINGS to listOf("earnings", "quarterly results", "eps", "revenue", "profit", "q1 ", "q2 ", "q3 ", "q4 ", "results"),
        NewsCategory.ACQUISITIONS to listOf("acquire", "acquisition", "merger", "buyout", "takeover", "to buy "),
        NewsCategory.REGULATION to listOf("sec ", "regulator", "antitrust", "lawsuit", "ftc", "doj", "probe", "fine", "enforcement", "rule"),
        NewsCategory.SECTOR to listOf("sector", "industry", "chipmakers", "banks", "oil prices", "semiconductor"),
    )
    private val positive = listOf("beat", "beats", "raises", "upgrade", "record", "surge", "approval", "approved", "wins", "strong", "tops")
    private val negative = listOf("miss", "misses", "cuts", "downgrade", "plunge", "lawsuit", "probe", "recall", "warning", "layoffs", "falls", "weak", "slump")

    fun categorize(headline: String, description: String? = null): NewsCategory {
        val text = " " + (headline + " " + (description ?: "")).lowercase() + " "
        return categoryRules.firstOrNull { (_, keys) -> keys.any { it in text } }?.first ?: NewsCategory.OTHER
    }

    /** -1..1 tone of a headline. */
    fun tone(headline: String): Double {
        val words = headline.lowercase().split(Regex("[^a-z]+")).toSet()
        val p = positive.count { it in words }
        val n = negative.count { it in words }
        return if (p + n == 0) 0.0 else (p - n).toDouble() / (p + n)
    }

    fun normalizedTitle(headline: String): String = headline.lowercase().replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()

    private fun tokens(h: String) = normalizedTitle(h).split(' ').filter { it.length > 2 }.toSet()

    fun similarity(a: String, b: String): Double {
        val ta = tokens(a)
        val tb = tokens(b)
        if (ta.isEmpty() || tb.isEmpty()) return 0.0
        return ta.intersect(tb).size.toDouble() / ta.union(tb).size
    }

    /** Removes duplicate stories (same URL, identical normalized title, or >=80% token overlap); keeps the earliest. */
    fun deduplicate(items: List<NewsItem>): List<NewsItem> {
        val kept = mutableListOf<NewsItem>()
        for (item in items.sortedBy { it.publishedAt }) {
            val dup = kept.any { k ->
                k.url == item.url || normalizedTitle(k.headline) == normalizedTitle(item.headline) || similarity(k.headline, item.headline) >= 0.8
            }
            if (!dup) kept += item
        }
        return kept.sortedByDescending { it.publishedAt }
    }

    /** Relevance 0..1: symbol match, category weight and recency. */
    fun relevance(item: NewsItem, watchedSymbols: Set<String>, now: Instant): Double {
        val ageHours = ChronoUnit.HOURS.between(item.publishedAt, now).coerceAtLeast(0)
        val recency = when {
            ageHours < 24 -> 1.0
            ageHours < 72 -> 0.7
            ageHours < 168 -> 0.4
            else -> 0.15
        }
        val symbolMatch = if (item.relatedSymbols.any { it in watchedSymbols }) 1.0 else 0.4
        val categoryWeight = when (item.category) {
            NewsCategory.EARNINGS, NewsCategory.GUIDANCE, NewsCategory.FED -> 1.0
            NewsCategory.INFLATION, NewsCategory.EMPLOYMENT, NewsCategory.ACQUISITIONS -> 0.8
            NewsCategory.REGULATION -> 0.7
            else -> 0.5
        }
        return (0.4 * recency + 0.35 * symbolMatch + 0.25 * categoryWeight).coerceIn(0.0, 1.0)
    }
}
