package com.marketpilot.domain.scoring

import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.RedditTickerStats
import java.time.Instant
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ScoringTest {
    private val asOf = LocalDate.of(2026, 10, 27)

    /** Deterministic synthetic test series (unit-test fixture only, never shown in the app). */
    private fun series(id: String, n: Int, drift: Double, end: LocalDate = asOf): List<Candle> {
        val cal = com.marketpilot.core.common.Calendars.NYSE
        val dates = ArrayDeque<LocalDate>()
        var d = end
        while (dates.size < n) { if (cal.isTradingDay(d)) dates.addFirst(d); d = d.minusDays(1) }
        return dates.mapIndexed { i, date ->
            val p = 100.0 * Math.pow(1 + drift, i.toDouble()) * (1 + 0.01 * kotlin.math.sin(i / 4.0))
            Candle(id, date, p * 0.998, p * 1.01, p * 0.99, p, null, 5_000_000)
        }
    }

    private fun insider(code: String, plan: Boolean = false, name: String = "Doe John", value: Double = 100.0) = InsiderTransaction(
        "0001", "1", "X", name, "Director", true, false, false, asOf.minusDays(5), asOf.minusDays(7), code,
        InsiderTransactionType.fromCode(code), 1000.0, value, if (code == "S") "D" else "A", "D", null, plan, "https://www.sec.gov/",
    )

    @Test fun insiderConvictionCountsOnlyOpenMarketPurchases() {
        val grantsOnly = InsiderConviction.score(listOf(insider("A"), insider("M"), insider("F"), insider("P", plan = true)), asOf)
        assertEquals(0, grantsOnly.purchases.size)
        assertTrue(grantsOnly.score <= 30.0)
        assertEquals(4, grantsOnly.excludedTransactions + grantsOnly.discretionarySales + 0)
        val buys = InsiderConviction.score(listOf(insider("P", name = "A"), insider("P", name = "B"), insider("P", name = "C")), asOf)
        assertEquals(3, buys.distinctBuyers)
        assertTrue(buys.score > 70)
    }

    @Test fun redditHypeIsCapped() {
        val hype = RedditTickerStats("X", Instant.EPOCH, Instant.EPOCH, mentions = 200, previousMentions = 10, uniqueAuthors = 20,
            totalScore = 0, totalComments = 0, sentiment = 0.9, previousSentiment = 0.1, topAuthorShare = 0.4, subreddits = emptyList(), samplePermalinks = emptyList())
        val s = RedditSignalScorer.score(hype)
        assertEquals(HypeRisk.HIGH, s.hypeRisk)
        assertTrue(s.score <= 55.0)
    }

    @Test fun newsDeduplicationAndCategories() {
        val t = Instant.parse("2026-10-27T12:00:00Z")
        val a = NewsItem("1", "Apple beats quarterly earnings estimates", "P1", t, "u1", providerId = "x")
        val b = NewsItem("2", "Apple beats quarterly earnings estimates!", "P2", t.plusSeconds(60), "u2", providerId = "x")
        val c = NewsItem("3", "Fed holds interest rate steady, Powell says", "P3", t, "u3", providerId = "x")
        assertEquals(2, NewsClassifier.deduplicate(listOf(a, b, c)).size)
        assertEquals(com.marketpilot.core.model.NewsCategory.FED, NewsClassifier.categorize(c.headline))
        assertEquals(com.marketpilot.core.model.NewsCategory.EARNINGS, NewsClassifier.categorize(a.headline))
        assertTrue(NewsClassifier.tone(a.headline) > 0)
    }

    @Test fun missingDataReducesCoverageAndConfidenceNotNeutral() {
        val inst = InstrumentCatalog.stock("X", "X Corp")
        val bench = series("SPY", 300, 0.0003)
        val priceOnly = StockScorer.score(StockInput(inst, series("X", 300, 0.002), bench), asOf, MarketRegime.FAVORABLE)
        val withData = StockScorer.score(
            StockInput(
                inst, series("X", 300, 0.002), bench,
                fundamentals = FundamentalsSnapshot("X", "1", "USD", null, 120.0, 100.0, 20.0, 25.0, 30.0, 5.0, 10.0, 50.0, 10.0, 2.0, null, "u"),
                insiderTransactions = emptyList(), institutional = emptyList(), redditAvailable = true, news = emptyList(),
            ),
            asOf, MarketRegime.FAVORABLE,
        )
        assertTrue(priceOnly.coverage < withData.coverage)
        assertTrue(priceOnly.confidence < withData.confidence)
        assertNull(priceOnly.components.first { it.key == "insider" }.score) // not silently 50
        assertTrue(abs(priceOnly.coverage - 0.5) < 1e-9) // momentum + technical + liquidity
    }

    private fun abs(x: Double) = kotlin.math.abs(x)

    @Test fun shortHistoryIsExcluded() {
        val s = StockScorer.score(StockInput(InstrumentCatalog.stock("Y", "Y"), series("Y", 120, 0.002), series("SPY", 300, 0.0)), asOf, MarketRegime.FAVORABLE)
        assertTrue(s.excluded)
        assertEquals(Recommendation.INSUFFICIENT_DATA, s.recommendation)
    }

    @Test fun staleDataIsExcluded() {
        val s = StockScorer.score(
            StockInput(InstrumentCatalog.stock("Z", "Z"), series("Z", 300, 0.002, asOf.minusDays(14)), series("SPY", 300, 0.0)),
            asOf, MarketRegime.FAVORABLE,
        )
        assertTrue(s.excluded)
    }

    @Test fun highRiskRegimeProducesNoTrade() {
        val inputs = (1..8).map { i -> StockInput(InstrumentCatalog.stock("S$i", "S$i"), series("S$i", 300, 0.001 * i), series("SPY", 300, 0.0003)) }
        val r = StockRanker.rank(inputs, asOf, MarketRegime.HIGH_RISK)
        assertTrue(r.noTrade)
        assertTrue(r.top5.isEmpty())
        assertTrue(r.all.none { it.recommendation == Recommendation.BUY_CANDIDATE })
        assertTrue(r.noTradeReason!!.isNotBlank())
    }

    @Test fun weightsNormalize() {
        val w = ScoringWeights(momentum = 2.0, technical = 2.0, fundamental = 0.0, insider = 0.0, institutional = 0.0, reddit = 0.0, news = 0.0, liquidity = 0.0).normalized()
        assertEquals(0.5, w.momentum)
        assertTrue(kotlin.math.abs(ScoringWeights().total - 1.0) < 1e-9)
    }

    @Test fun etfAnalysisHasThreeDecisionsAndFlagsNonUcits() {
        val vwce = InstrumentCatalog.byId(InstrumentCatalog.VWCE)!!
        val a = EtfAnalyzer.analyze(vwce, series("V", 300, 0.0005), asOf, MarketRegime.NEUTRAL, null)
        assertEquals("ADATTO AL PAC", a.longTerm.verdict)
        assertTrue(a.opportunityScore != null)
        val spy = InstrumentCatalog.byId(InstrumentCatalog.SPY)!!
        assertEquals("SOLO BENCHMARK", EtfAnalyzer.analyze(spy, series("SPY", 300, 0.0005), asOf, MarketRegime.NEUTRAL, null).longTerm.verdict)
        val conc = EtfAnalyzer.analyze(
            InstrumentCatalog.byId("SXR8:XETRA")!!, series("S", 300, 0.0005), asOf, MarketRegime.NEUTRAL,
            EtfAllocation(10_000.0, mapOf("US_LARGE_CAP" to 9_000.0), mapOf("SXR8:XETRA" to 9_000.0)), 1_000.0,
        )
        assertEquals("CONCENTRAZIONE ELEVATA", conc.concentration.verdict)
        val short = EtfAnalyzer.analyze(vwce, series("V", 30, 0.0005), asOf, MarketRegime.NEUTRAL, null)
        assertEquals("DATI INSUFFICIENTI", short.longTerm.verdict)
    }
}
