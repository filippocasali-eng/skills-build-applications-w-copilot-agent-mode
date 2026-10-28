package com.marketpilot.data.repositories

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.database.FetchMarkerEntity
import com.marketpilot.core.database.FundamentalsEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.data.providers.ProviderRegistry
import com.marketpilot.data.repositories.di.NetworkMonitor
import com.marketpilot.domain.backtesting.EntryComparison
import com.marketpilot.domain.backtesting.EntryStrategyBacktest
import com.marketpilot.domain.scoring.StockInput
import com.marketpilot.domain.scoring.StockScorer
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Duration
import javax.inject.Inject
import javax.inject.Singleton

data class OnDemandResult(val updatedPrices: Boolean, val messages: List<String>)

/** Fetches data for a single instrument when the user opens its detail (only if online and data is stale). */
@Singleton
class OnDemandRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val registry: ProviderRegistry,
    private val market: MarketDataRepository,
    private val settings: SettingsRepository,
    private val network: NetworkMonitor,
    private val clock: AppClock,
) {
    fun search(query: String, all: List<Instrument>): List<Instrument> {
        val q = query.trim().uppercase()
        if (q.isEmpty()) return emptyList()
        return all.filter { it.symbol.uppercase().startsWith(q) || it.name.uppercase().contains(q) || it.isin == q }
            .sortedBy { if (it.symbol.uppercase() == q) 0 else 1 }.take(20)
    }

    /** Resolves a ticker typed by the user: catalog first, then the SEC ticker list (US issuers). */
    suspend fun resolveTicker(symbol: String): Instrument? {
        val s = symbol.trim().uppercase().takeIf { it.matches(Regex("[A-Z][A-Z.\\-]{0,9}")) } ?: return null
        market.instruments().firstOrNull { it.symbol == s }?.let { return it }
        val sec = db.alternativeDataDao().tickers().firstOrNull { it.ticker == s.replace('.', '-') || it.ticker == s }
        return market.addUserStock(s, sec?.title ?: s)
    }

    suspend fun ensureStockData(id: String): OnDemandResult {
        val inst = market.instrument(id) ?: return OnDemandResult(false, listOf("Strumento sconosciuto"))
        val msgs = mutableListOf<String>()
        if (!network.isOnline()) return OnDemandResult(false, listOf("Offline: mostrati i dati salvati"))
        val now = clock.now()
        val last = market.lastCandleDate(id)
        val lastCompleted = MarketSessions.lastCompletedSession(Calendars.forExchange(inst.exchange), now)
        var updated = false
        if (last == null || last.isBefore(lastCompleted)) {
            val from = last?.minusDays(10) ?: now.atZone(AppClock.DISPLAY_ZONE).toLocalDate().minusYears(settings.current().cache.historyYears.toLong())
            for (p in registry.historyChain()) {
                val r = withTimeoutOrNull(45_000) { p.dailyHistory(inst, from) } ?: continue
                val c = r.data ?: run { msgs += "${p.descriptor.displayName}: ${r.error?.message}"; null } ?: continue
                db.candleDao().upsert(c.map { it.toEntity(p.descriptor.id, now) })
                updated = true
                break
            }
            for (qp in registry.quoteChain()) {
                val q = withTimeoutOrNull(30_000) { qp.quote(inst) } ?: continue
                val quote = q.data ?: continue
                db.quoteDao().upsert(quote.toEntity(qp.descriptor.id, q.source.sourceUrl, now, q.freshness))
                break
            }
        }
        if (inst.assetClass == AssetClass.STOCK && registry.isEnabled(registry.sec)) {
            if (db.alternativeDataDao().tickerCount() == 0) {
                registry.sec.tickerMap().data?.let { e -> db.alternativeDataDao().upsertTickers(e.map { com.marketpilot.core.database.SecTickerEntity(it.ticker, it.cik, it.title) }) }
            }
            val fundMarker = db.cacheDao().marker("fund:$id")
            if (fundMarker == null || Duration.between(java.time.Instant.ofEpochMilli(fundMarker.lastFetchMs), now) > Duration.ofDays(7)) {
                val f = withTimeoutOrNull(60_000) { registry.sec.fundamentals(inst) }
                f?.data?.let {
                    db.cacheDao().upsertFundamentals(FundamentalsEntity(id, dbJson.encodeToString(FundamentalsSnapshot.serializer(), it), it.fiscalPeriodEnd?.toEpochDay(), it.sourceUrl, now.toEpochMilli()))
                    db.cacheDao().mark(FetchMarkerEntity("fund:$id", now.toEpochMilli()))
                } ?: f?.error?.let { msgs += "Fondamentali: ${it.message}" }
            }
            val insMarker = db.cacheDao().marker("form4:${inst.symbol}")
            if (insMarker == null || Duration.between(java.time.Instant.ofEpochMilli(insMarker.lastFetchMs), now) > Duration.ofHours(20)) {
                val r = withTimeoutOrNull(60_000) {
                    registry.sec.insiderTransactions(inst, now.atZone(AppClock.DISPLAY_ZONE).toLocalDate().minusDays(120), db.alternativeDataDao().knownAccessions().toSet(), 10)
                }
                r?.data?.let { tx ->
                    db.alternativeDataDao().upsertInsiders(tx.mapIndexed { i, t -> t.toEntity(i, now) })
                    db.cacheDao().mark(FetchMarkerEntity("form4:${inst.symbol}", now.toEpochMilli()))
                } ?: r?.error?.let { msgs += "Insider: ${it.message}" }
            }
            if (registry.isEnabled(registry.yahooNews)) {
                val n = withTimeoutOrNull(30_000) { registry.yahooNews.news(listOf(inst.symbol), now.atZone(AppClock.DISPLAY_ZONE).toLocalDate().minusDays(14)) }
                n?.data?.let { items -> db.newsDao().insertIgnore(items.map { it.toEntity(now) }) }
            }
        }
        return OnDemandResult(updated, msgs)
    }

    /** Scores a single stock with whatever data is stored (used for tickers outside the default universe). */
    suspend fun scoreStock(id: String): StockScoreDto? {
        val inst = market.instrument(id) ?: return null
        if (inst.assetClass != AssetClass.STOCK) return null
        val s = settings.current()
        val now = clock.now()
        val asOf = MarketSessions.lastCompletedSession(Calendars.NYSE, now)
        val regime = db.analysisDao().latestAssessment()?.toView()?.regime ?: MarketRegime.INSUFFICIENT_DATA
        val insidersFetched = db.cacheDao().marker("form4:${inst.symbol}") != null
        val input = StockInput(
            inst, market.candles(id), market.candles(InstrumentCatalog.SPY),
            fundamentals = db.cacheDao().fundamentals(id)?.let { runCatching { dbJson.decodeFromString(FundamentalsSnapshot.serializer(), it.json) }.getOrNull() },
            insiderTransactions = if (insidersFetched) db.alternativeDataDao().insidersFor(inst.symbol).map { it.toModel() } else null,
            institutional = if (db.alternativeDataDao().managersLoaded() > 0) db.alternativeDataDao().holdingsFor(inst.symbol).map { it.toModel() } else null,
            reddit = db.alternativeDataDao().latestRedditFor(inst.symbol)?.toModel(),
            redditAvailable = db.alternativeDataDao().latestRedditWindow() != null,
            news = db.newsDao().since(now.minus(Duration.ofDays(10)).toEpochMilli()).map { it.toModel() }.filter { inst.symbol in it.relatedSymbols },
            nextEarnings = db.alternativeDataDao().nextEarnings(inst.symbol, asOf.toEpochDay())?.let { com.marketpilot.core.model.EarningsEvent(it.symbol, java.time.LocalDate.ofEpochDay(it.epochDay), it.providerId) },
        )
        return StockScoreDto.from(StockScorer.score(input, asOf, regime, SettingsRepository.weights(s), SettingsRepository.risk(s)))
    }

    suspend fun entryComparison(id: String, amount: Double, horizonSessions: Int = 252): EntryComparison? =
        EntryStrategyBacktest.compare(market.candles(id), amount, horizonSessions)
}
