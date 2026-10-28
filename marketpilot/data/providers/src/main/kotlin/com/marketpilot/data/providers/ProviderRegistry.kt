package com.marketpilot.data.providers

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.network.HttpClients
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.impl.AlphaVantageProvider
import com.marketpilot.data.providers.impl.CboeVixProvider
import com.marketpilot.data.providers.impl.EcbFxProvider
import com.marketpilot.data.providers.impl.FinnhubProvider
import com.marketpilot.data.providers.impl.FredProvider
import com.marketpilot.data.providers.impl.RedditProvider
import com.marketpilot.data.providers.impl.RssNewsProvider
import com.marketpilot.data.providers.impl.SecEdgarProvider
import com.marketpilot.data.providers.impl.StooqProvider
import com.marketpilot.data.providers.impl.TickerMapParser
import com.marketpilot.data.providers.impl.YahooChartProvider

/**
 * Provider registry running entirely on the device. Settings and secrets are read lazily at call time,
 * so changes in the settings screen apply to the next request without rebuilding the registry.
 */
class ProviderRegistry(
    private val settings: () -> ProviderSettings,
    deviceId: () -> String,
    tickerEntries: suspend () -> List<TickerMapParser.Entry>,
    clock: AppClock = AppClock.SYSTEM,
    http: HttpFetcher = HttpFetcher(HttpClients.create("MarketPilotAI/1.0 (Android; personal use)")),
) {
    val yahoo = YahooChartProvider(http, clock)
    val stooq = StooqProvider(http, clock)
    val alphaVantage = AlphaVantageProvider(http, { settings().alphaVantageKey }, clock)
    val finnhub = FinnhubProvider(http, { settings().finnhubKey }, clock)
    val sec = SecEdgarProvider(http, { settings().secContact }, clock, tickerEntries)
    val fred = FredProvider(http, clock)
    val cboe = CboeVixProvider(http, clock)
    val ecb = EcbFxProvider(http, clock)
    val fedNews = RssNewsProvider.federalReserve(http, clock)
    val secNews = RssNewsProvider.secPress(http, clock)
    val yahooNews = RssNewsProvider.yahooHeadlines(http, clock)
    val reddit = RedditProvider(http, { settings().redditClientId }, deviceId, clock)

    val all: List<DataProvider> = listOf(yahoo, alphaVantage, finnhub, sec, cboe, fred, ecb, fedNews, secNews, yahooNews, reddit, stooq)

    fun isEnabled(p: DataProvider): Boolean = settings().isEnabled(p.descriptor)

    private fun keyed(p: DataProvider): Boolean = when (p) {
        alphaVantage -> !settings().alphaVantageKey.isNullOrBlank()
        finnhub -> !settings().finnhubKey.isNullOrBlank()
        reddit -> !settings().redditClientId.isNullOrBlank()
        else -> true
    }

    /** Ordered fallback chains per capability: only enabled (and configured) providers are returned. */
    fun historyChain(): List<HistoricalDataProvider> = listOf<HistoricalDataProvider>(yahoo, alphaVantage, stooq).filter { isEnabled(it) && keyed(it) }
    fun quoteChain(): List<MarketDataProvider> = listOf<MarketDataProvider>(yahoo, alphaVantage).filter { isEnabled(it) && keyed(it) }
    fun newsProviders(): List<NewsProvider> = listOf<NewsProvider>(fedNews, secNews, yahooNews, finnhub).filter { isEnabled(it) && keyed(it) }
    fun earningsChain(): List<EarningsCalendarProvider> = listOf<EarningsCalendarProvider>(finnhub, alphaVantage).filter { isEnabled(it) && keyed(it) }
    fun vixChain(): List<MacroDataProvider> = listOf<MacroDataProvider>(cboe, fred).filter { isEnabled(it) }
    fun redditOrNull(): SocialSentimentProvider? = reddit.takeIf { isEnabled(it) && keyed(it) }
    fun redditNeedsConfiguration(): Boolean = isEnabled(reddit) && !keyed(reddit)
}
