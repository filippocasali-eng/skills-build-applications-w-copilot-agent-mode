package com.marketpilot.data.providers

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.network.HostRateLimiter
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.impl.AlphaVantageParser
import com.marketpilot.data.providers.impl.CompanyFactsParser
import com.marketpilot.data.providers.impl.Form4Parser
import com.marketpilot.data.providers.impl.MacroParsers
import com.marketpilot.data.providers.impl.RedditAnalyzer
import com.marketpilot.data.providers.impl.RedditPost
import com.marketpilot.data.providers.impl.RssParser
import com.marketpilot.data.providers.impl.SecAtomParser
import com.marketpilot.data.providers.impl.ThirteenFParser
import com.marketpilot.data.providers.impl.TickerMapParser
import com.marketpilot.data.providers.impl.YahooChartParser
import com.marketpilot.data.providers.impl.YahooChartProvider
import com.marketpilot.data.providers.impl.looksLikeBotWall
import com.marketpilot.data.providers.impl.redactSecrets
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import java.time.Instant
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Parser tests against responses recorded from the live endpoints (see resources/fixtures/README.md). */
class ParsersTest {
    private fun fixture(name: String) = javaClass.getResource("/fixtures/$name")!!.readText()

    @Test fun yahooChartRecordedResponse() {
        val p = YahooChartParser.parse(fixture("yahoo_chart_aapl_1mo.json")) as YahooChartParser.Parsed.Ok
        val c = p.chart
        assertEquals("USD", c.currency)
        assertEquals("America/New_York", c.exchangeTimezone.id)
        assertEquals(22, c.bars.size)
        assertEquals(347.1, c.regularMarketPrice)
        assertEquals(LocalDate.of(2026, 10, 27), c.bars.last().date)
        assertEquals(39_949_500L, c.bars.last().volume)
        assertTrue(c.bars.zipWithNext().all { (a, b) -> a.date < b.date })
    }

    @Test fun yahooErrorPayload() {
        val p = YahooChartParser.parse("""{"chart":{"result":null,"error":{"code":"Not Found","description":"No data found, symbol may be delisted"}}}""")
        assertTrue(p is YahooChartParser.Parsed.Error && p.notFound)
    }

    @Test fun yahooProviderNormalizesAndKeepsProvenance() = runBlocking {
        MockWebServer().use { s ->
            s.enqueue(MockResponse().setBody(fixture("yahoo_chart_aapl_1mo.json")))
            val http = HttpFetcher(OkHttpClient(), HostRateLimiter(emptyMap(), 0))
            val clock = AppClock { Instant.parse("2026-10-28T12:00:00Z") }
            val provider = YahooChartProvider(http, clock, s.url("").toString().trimEnd('/'))
            val r = provider.dailyHistory(InstrumentCatalog.stock("AAPL", "Apple"), LocalDate.of(2026, 9, 1))
            assertTrue(r.isSuccess)
            assertEquals(22, r.data!!.size)
            assertEquals(Freshness.END_OF_DAY, r.freshness)
            assertEquals("yahoo", r.source.providerId)
            assertNotNull(r.observedAt)
            assertEquals(1.0, r.quality.completeness)
            // Currency mismatch is rejected rather than mixed.
            s.enqueue(MockResponse().setBody(fixture("yahoo_chart_aapl_1mo.json")))
            val wrong = provider.dailyHistory(InstrumentCatalog.byId("VWCE:XETRA")!!, LocalDate.of(2026, 9, 1))
            assertFalse(wrong.isSuccess)
            assertEquals(ProviderErrorKind.PARSE, wrong.error!!.kind)
        }
    }

    @Test fun form4RecordedFilingIsParsedAndPlanTradeFlagged() {
        val tx = Form4Parser.parse(fixture("sec_form4_aapl.xml"), "0001140361-26-040540", LocalDate.of(2026, 10, 22), "https://www.sec.gov/x").single()
        assertEquals("AAPL", tx.issuerSymbol)
        assertEquals("320193", tx.issuerCik)
        assertEquals("Newstead Jennifer", tx.insiderName)
        assertTrue(tx.isOfficer && !tx.isDirector)
        assertTrue(tx.insiderRole.contains("SVP"))
        assertEquals(InsiderTransactionType.OPEN_MARKET_SALE, tx.type)
        assertEquals(2399.0, tx.shares)
        assertEquals(339.62, tx.pricePerShare)
        assertEquals("D", tx.acquiredDisposed)
        assertEquals("D", tx.ownershipType)
        assertEquals(34795.0, tx.sharesOwnedAfter)
        assertTrue(tx.isRule10b51Plan)
        assertEquals(2L, tx.filingDelayDays)
        assertEquals(2399 * 339.62, tx.dollarValue!!, 1e-6)
    }

    @Test fun thirteenFAggregatesByCusip() {
        val lines = ThirteenFParser.parse(fixture("sec_13f_brk_infotable.xml"))
        assertEquals(2, lines.size)
        val ally = lines.first { it.cusip == "02005N100" }
        assertEquals(12_561_737.0 + 2_803_875.0, ally.shares)
        assertEquals(577_211_815.0 + 128_838_056.0, ally.valueUsd)
    }

    @Test fun secAtomFeed() {
        val e = SecAtomParser.parse(fixture("sec_getcurrent_form4.atom"))
        assertEquals(3, e.size)
        assertEquals(2, e.count { it.role == "Issuer" })
        assertEquals("0001193125-26-434846", e[1].accession)
        assertEquals(LocalDate.of(2026, 10, 27), e[1].filed)
    }

    @Test fun alphaVantageDemoResponse() {
        val c = AlphaVantageParser.daily(fixture("alphavantage_daily_ibm_demo.json"), "IBM:US")
        assertEquals(3, c.size)
        assertEquals(LocalDate.of(2026, 10, 23), c.first().date)
        assertEquals(250.25, c.last().close)
        assertNull(AlphaVantageParser.notice(fixture("alphavantage_daily_ibm_demo.json")))
        assertNotNull(AlphaVantageParser.notice("""{"Information":"Thank you for using Alpha Vantage! rate limit"}"""))
    }

    @Test fun macroAndFxParsers() {
        val ecb = MacroParsers.ecbXml(fixture("ecb_hist_90d_head.xml"), setOf("USD", "GBP"))
        assertEquals(1.115, ecb.first { it.quote == "USD" }.rate)
        assertEquals(LocalDate.of(2026, 10, 27), ecb.first().date)
        assertEquals(2, ecb.size)
        val fred = MacroParsers.fredCsv(fixture("fred_vixcls_head.csv") + "1990-01-09,.\n", "VIXCLS")
        assertEquals(5, fred.size)
        assertEquals(17.24, fred.first().value)
        val vix = MacroParsers.cboeVix(fixture("cboe_vix_history_head.csv"))
        assertEquals(LocalDate.of(1990, 1, 3), vix[1].date)
        val hist = MacroParsers.ecbHistCsv("Date,USD,JPY,\n2026-10-27,1.115,175.97,\n2026-10-26,1.1101,N/A,\n", setOf("USD", "JPY"), LocalDate.of(2026, 1, 1))
        assertEquals(3, hist.size)
    }

    @Test fun rssFeedWithCdataAndBotWallDetection() {
        val items = RssParser.parse(fixture("fed_press_all_head.xml"))
        assertEquals(1, items.size)
        assertEquals(Instant.parse("2026-10-16T15:00:00Z"), items.first().published)
        assertTrue(items.first().link.startsWith("https://www.federalreserve.gov/"))
        assertTrue(looksLikeBotWall(fixture("stooq_botwall.html")))
        assertFalse(looksLikeBotWall(fixture("fred_vixcls_head.csv")))
    }

    @Test fun xmlExternalEntitiesAreNotExpanded() {
        val evil = """<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><rss><channel><item><title>&x;</title><link>https://a.b</link></item></channel></rss>"""
        val r = runCatching { RssParser.parse(evil) }
        assertTrue(r.isFailure || r.getOrNull()!!.none { it.title.contains("root:") })
    }

    @Test fun redditTickerDisambiguationAndStats() {
        val universe = setOf("AAPL", "MA", "NVDA", "V")
        assertEquals(setOf("AAPL"), RedditAnalyzer.extractTickers("Bought AAPL calls, MA crossover looks good, V shaped", universe))
        assertEquals(setOf("MA", "V", "NVDA"), RedditAnalyzer.extractTickers("Long \$MA and \$V, also \$NVDA", universe))
        val now = Instant.parse("2026-10-28T12:00:00Z")
        val posts = (1..6).map { RedditPost("p$it", "stocks", "u${it % 2}", "NVDA calls to the moon", "", 10, 2, now.minusSeconds(3600L * it), "/r/x/$it") } +
            RedditPost("old", "stocks", "z", "NVDA puts", "", 1, 0, now.minusSeconds(3600L * 30), "/r/x/old")
        val st = RedditAnalyzer.stats(posts, universe, now).single { it.symbol == "NVDA" }
        assertEquals(6, st.mentions)
        assertEquals(1, st.previousMentions)
        assertEquals(2, st.uniqueAuthors)
        assertTrue(st.sentiment > 0)
        assertEquals(0.5, st.topAuthorShare)
    }

    @Test fun issuerNameResolution() {
        val entries = listOf(
            TickerMapParser.Entry("1652044", "GOOGL", "Alphabet Inc."), TickerMapParser.Entry("1652044", "GOOG", "Alphabet Inc."),
            TickerMapParser.Entry("40545", "GE", "GE Aerospace"), TickerMapParser.Entry("1", "ALLY", "Ally Financial Inc."),
        )
        assertEquals("GOOG", TickerMapParser.resolve("ALPHABET INC", entries))
        assertNull(TickerMapParser.resolve("UNKNOWN WIDGETS CORP", entries))
    }

    /** Structure mirrors the recorded companyfacts fields (tags, units, form/fp/start/end). */
    @Test fun companyFactsAnnualExtraction() {
        fun fy(start: String, end: String, v: Double) = """{"start":"$start","end":"$end","val":$v,"form":"10-K","fp":"FY","filed":"${end.take(4)}-10-31"}"""
        fun inst(end: String, v: Double) = """{"end":"$end","val":$v,"form":"10-K","fp":"FY","filed":"${end.take(4)}-10-31"}"""
        val json = """{"facts":{"dei":{"EntityCommonStockSharesOutstanding":{"units":{"shares":[{"end":"2026-07-17","val":14594180000,"form":"10-Q"}]}}},
          "us-gaap":{
            "RevenueFromContractWithCustomerExcludingAssessedTax":{"units":{"USD":[${fy("2023-10-01", "2024-09-28", 391035000000.0)},${fy("2024-09-29", "2025-09-27", 416161000000.0)},
               {"start":"2025-06-29","end":"2025-09-27","val":102466000000,"form":"10-K","fp":"FY"}]}},
            "NetIncomeLoss":{"units":{"USD":[${fy("2024-09-29", "2025-09-27", 112010000000.0)}]}},
            "OperatingIncomeLoss":{"units":{"USD":[${fy("2024-09-29", "2025-09-27", 133050000000.0)}]}},
            "NetCashProvidedByUsedInOperatingActivities":{"units":{"USD":[${fy("2024-09-29", "2025-09-27", 111482000000.0)}]}},
            "PaymentsToAcquirePropertyPlantAndEquipment":{"units":{"USD":[${fy("2024-09-29", "2025-09-27", 12715000000.0)}]}},
            "LongTermDebt":{"units":{"USD":[${inst("2025-09-27", 90678000000.0)}]}},
            "StockholdersEquity":{"units":{"USD":[${inst("2025-09-27", 73733000000.0)}]}},
            "EarningsPerShareDiluted":{"units":{"USD/shares":[${fy("2024-09-29", "2025-09-27", 7.46)}]}}
          }}}"""
        val f = CompanyFactsParser.parse(json, "AAPL", "320193", "Electronic Computers", "https://data.sec.gov/x")!!
        assertEquals(LocalDate.of(2025, 9, 27), f.fiscalPeriodEnd)
        assertEquals(416161000000.0, f.revenue)
        assertEquals(391035000000.0, f.revenuePrevious) // quarterly 10-K fragment ignored
        assertEquals(7.46, f.epsDiluted)
        assertEquals(111482000000.0 - 12715000000.0, f.freeCashFlow!!, 1.0)
        assertTrue(f.revenueGrowth!! > 0.06 && f.revenueGrowth!! < 0.07)
        assertEquals(14594180000.0, f.sharesOutstanding)
    }

    @Test fun secretsAreRedactedFromStoredUrls() {
        assertEquals("https://x/query?function=A&apikey=***", redactSecrets("https://x/query?function=A&apikey=ABC123"))
        assertEquals("https://x/news?symbol=A&token=***&from=1", redactSecrets("https://x/news?symbol=A&token=SECRET&from=1"))
    }
}
