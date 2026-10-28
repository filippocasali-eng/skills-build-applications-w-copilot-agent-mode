package com.marketpilot.data.providers

import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.network.HttpClients
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.impl.AlphaVantageProvider
import com.marketpilot.data.providers.impl.CboeVixProvider
import com.marketpilot.data.providers.impl.EcbFxProvider
import com.marketpilot.data.providers.impl.FredProvider
import com.marketpilot.data.providers.impl.RedditProvider
import com.marketpilot.data.providers.impl.RssNewsProvider
import com.marketpilot.data.providers.impl.SecEdgarProvider
import com.marketpilot.data.providers.impl.StooqProvider
import com.marketpilot.data.providers.impl.TickerMapParser
import com.marketpilot.data.providers.impl.YahooChartProvider
import kotlinx.coroutines.runBlocking
import org.junit.Assume.assumeTrue
import org.junit.Before
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Real network integration tests (no mocks). Run only when MP_LIVE_TESTS=1 (CI job "live-providers").
 * A provider is classified as operational only after these pass against the real endpoint.
 */
class LiveProvidersTest {
    private val http = HttpFetcher(HttpClients.create("MarketPilotAI/1.0 (CI integration test; contact marketpilot-ci@example.com)"))
    private val today = LocalDate.now()

    @Before fun gate() = assumeTrue("Live tests disabled", System.getenv("MP_LIVE_TESTS") == "1")

    private fun <T> report(name: String, r: ProviderResult<T>) {
        println("LIVE[$name] success=${r.isSuccess} freshness=${r.freshness} observed=${r.observedAt} source=${r.source.sourceUrl} error=${r.error} warnings=${r.quality.warnings}")
    }

    @Test fun yahooUsAndUcitsHistory() = runBlocking {
        val y = YahooChartProvider(http)
        for (id in listOf("SPY:NYSEARCA", "QQQ:NASDAQ", "VWCE:XETRA", "SXR8:XETRA", "CSPX:LSE", "SXRV:XETRA", "EUNL:XETRA", "XLK:NYSEARCA")) {
            val r = y.dailyHistory(InstrumentCatalog.byId(id)!!, today.minusYears(2))
            report("yahoo-history-$id", r)
            assertTrue(r.isSuccess, "$id: ${r.error}")
            assertTrue(r.data!!.size > 400, "$id bars=${r.data!!.size}")
            assertTrue(r.data!!.last().date.isAfter(today.minusDays(7)))
        }
        val q = y.quote(InstrumentCatalog.stock("AAPL", "Apple"))
        report("yahoo-quote-AAPL", q)
        assertTrue(q.isSuccess && q.data!!.price > 0)
    }

    @Test fun secEdgarInsidersInstitutionsFundamentals() = runBlocking {
        var entries: List<TickerMapParser.Entry> = emptyList()
        val sec = SecEdgarProvider(http, { "marketpilot-ci@example.com" }, tickerEntries = { entries })
        val map = sec.tickerMap()
        report("sec-tickers", map)
        assertTrue(map.isSuccess && map.data!!.any { it.ticker == "AAPL" && it.cik == "320193" })
        entries = map.data!!
        val ins = sec.insiderTransactions(InstrumentCatalog.stock("AAPL", "Apple"), today.minusDays(180), emptySet(), 8)
        report("sec-form4-AAPL", ins)
        assertTrue(ins.isSuccess)
        val feed = sec.latestForm4(5, emptySet())
        report("sec-form4-feed", feed)
        assertTrue(feed.isSuccess)
        val brk = sec.holdings("1067983")
        report("sec-13f-BRK", brk)
        assertTrue(brk.isSuccess && brk.data!!.size > 10)
        assertTrue(brk.data!!.any { it.symbol != null })
        val f = sec.fundamentals(InstrumentCatalog.stock("MSFT", "Microsoft"))
        report("sec-xbrl-MSFT", f)
        assertTrue(f.isSuccess && (f.data!!.revenue ?: 0.0) > 0)
    }

    @Test fun macroFxAndNews() = runBlocking {
        val vix = CboeVixProvider(http).series("VIX", today.minusDays(60)); report("cboe-vix", vix); assertTrue(vix.isSuccess)
        val dgs = FredProvider(http).series("DGS10", today.minusDays(60)); report("fred-dgs10", dgs); assertTrue(dgs.isSuccess)
        val curve = FredProvider(http).series("T10Y2Y", today.minusDays(60)); report("fred-t10y2y", curve); assertTrue(curve.isSuccess)
        // Fallback FX when the ECB is unreachable on a device: USD per EUR (Federal Reserve H.10).
        val eurUsd = FredProvider(http).series("DEXUSEU", today.minusDays(60)); report("fred-dexuseu", eurUsd)
        assertTrue(eurUsd.isSuccess && eurUsd.data!!.all { it.value in 0.5..2.0 })
        val fx = EcbFxProvider(http).eurRates(setOf("USD", "GBP"), today.minusDays(30)); report("ecb-90d", fx); assertTrue(fx.isSuccess)
        val fxHist = EcbFxProvider(http).eurRates(setOf("USD"), today.minusYears(2)); report("ecb-hist", fxHist)
        assertTrue(fxHist.isSuccess && fxHist.data!!.size > 400)
        val fed = RssNewsProvider.federalReserve(http).news(emptyList(), today.minusDays(60)); report("fed-rss", fed); assertTrue(fed.isSuccess)
        val secRss = RssNewsProvider.secPress(http).news(emptyList(), today.minusDays(60)); report("sec-rss", secRss); assertTrue(secRss.isSuccess)
        val yRss = RssNewsProvider.yahooHeadlines(http).news(listOf("AAPL", "MSFT"), today.minusDays(14)); report("yahoo-rss", yRss); assertTrue(yRss.isSuccess)
    }

    @Test fun alphaVantagePublicDemoKey() = runBlocking {
        val av = AlphaVantageProvider(http, { "demo" })
        val r = av.dailyHistory(InstrumentCatalog.stock("IBM", "IBM"), today.minusDays(120))
        report("alphavantage-demo-IBM", r)
        // The public "demo" key only serves the exact documentation URLs: a refusal must be classified, never crash.
        assertTrue(r.isSuccess || r.error?.kind in setOf(ProviderErrorKind.RATE_LIMITED, ProviderErrorKind.AUTH))
    }

    @Test fun unsupportedAndUnconfiguredProvidersAreReportedHonestly() = runBlocking {
        val st = StooqProvider(http).dailyHistory(InstrumentCatalog.stock("SPY", "SPY"), today.minusDays(30))
        report("stooq", st)
        // Stooq is disabled by default (bot wall); any failure must be classified, never a fake success.
        if (!st.isSuccess) assertTrue(st.error!!.kind in setOf(ProviderErrorKind.BLOCKED, ProviderErrorKind.HTTP, ProviderErrorKind.EMPTY, ProviderErrorKind.TIMEOUT, ProviderErrorKind.NETWORK))
        val rd = RedditProvider(http, { null }, { "DO_NOT_TRACK_THIS_DEVICE" }).tickerStats(setOf("AAPL"))
        report("reddit-unconfigured", rd)
        assertEquals(ProviderErrorKind.NOT_CONFIGURED, rd.error!!.kind)
    }
}
