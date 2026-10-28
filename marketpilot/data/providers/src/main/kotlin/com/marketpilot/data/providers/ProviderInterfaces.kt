package com.marketpilot.data.providers

import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.EarningsEvent
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.FxRate
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.ProviderDescriptor
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.model.Quote
import com.marketpilot.core.model.RedditTickerStats
import java.time.LocalDate

interface DataProvider {
    val descriptor: ProviderDescriptor
}

interface MarketDataProvider : DataProvider {
    suspend fun quote(instrument: Instrument): ProviderResult<Quote>
}

interface HistoricalDataProvider : DataProvider {
    /** Daily bars from [from] (inclusive). Implementations return only bars of completed sessions. */
    suspend fun dailyHistory(instrument: Instrument, from: LocalDate): ProviderResult<List<Candle>>
}

interface FundamentalsProvider : DataProvider {
    suspend fun fundamentals(instrument: Instrument): ProviderResult<FundamentalsSnapshot>
}

interface NewsProvider : DataProvider {
    suspend fun news(symbols: List<String>, since: LocalDate): ProviderResult<List<NewsItem>>
}

interface SocialSentimentProvider : DataProvider {
    suspend fun tickerStats(universe: Set<String>): ProviderResult<List<RedditTickerStats>>
}

interface InsiderDataProvider : DataProvider {
    suspend fun insiderTransactions(instrument: Instrument, since: LocalDate): ProviderResult<List<InsiderTransaction>>
}

interface InstitutionalDataProvider : DataProvider {
    /** Latest 13F holdings of [managerCik] with changes versus the previous filing. */
    suspend fun holdings(managerCik: String): ProviderResult<List<InstitutionalHolding>>
}

interface MacroDataProvider : DataProvider {
    suspend fun series(seriesId: String, from: LocalDate): ProviderResult<List<MacroObservation>>
}

interface FxDataProvider : DataProvider {
    suspend fun eurRates(currencies: Set<String>, from: LocalDate): ProviderResult<List<FxRate>>
}

interface EarningsCalendarProvider : DataProvider {
    suspend fun upcomingEarnings(symbols: Set<String>): ProviderResult<List<EarningsEvent>>
}

/** User configuration relevant to providers. Secrets are passed in at call time and never logged. */
data class ProviderSettings(
    val enabled: Map<String, Boolean> = emptyMap(),
    val alphaVantageKey: String? = null,
    val finnhubKey: String? = null,
    val redditClientId: String? = null,
    /** Contact e-mail for the SEC User-Agent (SEC fair-access policy asks for one). Optional. */
    val secContact: String? = null,
) {
    fun isEnabled(d: ProviderDescriptor): Boolean = enabled[d.id] ?: d.defaultEnabled
}
