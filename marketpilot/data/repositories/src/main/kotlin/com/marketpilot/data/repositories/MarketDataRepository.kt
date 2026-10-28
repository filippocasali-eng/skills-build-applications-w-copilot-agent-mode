package com.marketpilot.data.repositories

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.database.WatchlistEntity
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstrumentRole
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.domain.papertrading.FxLookup
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/** Local source of truth for instruments, prices, FX and macro series (Room). */
@Singleton
class MarketDataRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val clock: AppClock,
) {
    private val seedLock = Mutex()
    @Volatile private var seeded = false

    /** Seeds/updates the canonical catalog (identity data only, no prices). User-added instruments are kept. */
    suspend fun ensureCatalog() = seedLock.withLock {
        if (seeded) return@withLock
        db.instrumentDao().upsert(InstrumentCatalog.all.map { it.toEntity() })
        seeded = true
    }

    fun observeInstruments(): Flow<List<Instrument>> = db.instrumentDao().observeAll().map { l -> l.map { it.toModel() } }

    suspend fun instruments(): List<Instrument> { ensureCatalog(); return db.instrumentDao().all().map { it.toModel() } }

    suspend fun instrument(id: String): Instrument? { ensureCatalog(); return db.instrumentDao().byId(id)?.toModel() }

    suspend fun instrumentsWithRole(role: InstrumentRole) = instruments().filter { role in it.roles }

    /** Adds a US stock by ticker (identity only); data is fetched on the next refresh or on demand. */
    suspend fun addUserStock(symbol: String, name: String?): Instrument {
        val inst = InstrumentCatalog.stock(symbol, name ?: symbol.uppercase())
        db.instrumentDao().upsert(listOf(inst.toEntity(userAdded = true)))
        return inst
    }

    suspend fun candles(id: String): List<Candle> = db.candleDao().series(id).map { it.toModel() }

    suspend fun candlesFrom(id: String, from: LocalDate): List<Candle> = db.candleDao().seriesFrom(id, from.toEpochDay()).map { it.toModel() }

    fun observeCandles(id: String): Flow<List<Candle>> = db.candleDao().observeSeries(id).map { l -> l.map { it.toModel() } }

    suspend fun lastCandleDate(id: String): LocalDate? = db.candleDao().lastDay(id)?.let(LocalDate::ofEpochDay)

    fun observeQuotes(): Flow<Map<String, StoredQuote>> = db.quoteDao().observeAll().map { l -> l.associate { it.instrumentId to it.toModel() } }

    suspend fun quote(id: String): StoredQuote? = db.quoteDao().byId(id)?.toModel()

    suspend fun macro(seriesId: String): List<MacroObservation> =
        db.macroDao().macroSeries(seriesId).map { MacroObservation(it.seriesId, LocalDate.ofEpochDay(it.epochDay), it.value) }

    /** FX lookup backed by stored ECB reference rates (latest rate on or before the date). */
    suspend fun fxLookup(): FxLookup {
        val usd = db.macroDao().fxSeries("USD").map { it.epochDay to it.rate }
        val gbp = db.macroDao().fxSeries("GBP").map { it.epochDay to it.rate }
        val series = mapOf("USD" to usd, "GBP" to gbp)
        return FxLookup { ccy, date ->
            val s = series[ccy] ?: return@FxLookup null
            val d = date.toEpochDay()
            var lo = 0
            var hi = s.size - 1
            var ans: Double? = null
            while (lo <= hi) {
                val mid = (lo + hi) / 2
                if (s[mid].first <= d) { ans = s[mid].second; lo = mid + 1 } else hi = mid - 1
            }
            ans
        }
    }

    suspend fun latestEurUsd(): Pair<LocalDate, Double>? =
        db.macroDao().fxOnOrBefore("USD", clock.now().atZone(AppClock.DISPLAY_ZONE).toLocalDate().toEpochDay())?.let { LocalDate.ofEpochDay(it.epochDay) to it.rate }

    fun observeProviderStatus(): Flow<List<com.marketpilot.core.model.ProviderStatus>> = db.providerStatusDao().observeAll().map { l ->
        l.map {
            com.marketpilot.core.model.ProviderStatus(
                it.providerId, runCatching { com.marketpilot.core.model.ProviderOperationalState.valueOf(it.state) }.getOrDefault(com.marketpilot.core.model.ProviderOperationalState.UNTESTED),
                it.lastSuccessAtMs?.let(java.time.Instant::ofEpochMilli), it.lastAttemptAtMs?.let(java.time.Instant::ofEpochMilli), it.lastError, it.successCount, it.failureCount,
            )
        }
    }

    data class RefreshInfo(val finishedAt: java.time.Instant?, val status: String, val summary: RefreshSummaryDto?)

    fun observeLastRefresh(): Flow<RefreshInfo?> = db.refreshLogDao().observeLatest().map { e ->
        e?.let { RefreshInfo(it.finishedAtMs?.let(java.time.Instant::ofEpochMilli), it.status, runCatching { dbJson.decodeFromString(RefreshSummaryDto.serializer(), it.summaryJson) }.getOrNull()) }
    }

    fun observeLastSuccessfulRefresh(): Flow<java.time.Instant?> = db.refreshLogDao().observeLastSuccessful().map { it?.finishedAtMs?.let(java.time.Instant::ofEpochMilli) }

    // Watchlist ------------------------------------------------------------------------------------
    fun observeWatchlist(): Flow<List<String>> = db.watchlistDao().observe().map { l -> l.map { it.instrumentId } }
    suspend fun watchlist(): List<String> = db.watchlistDao().all().map { it.instrumentId }
    suspend fun addToWatchlist(id: String, note: String? = null) = db.watchlistDao().upsert(WatchlistEntity(id, clock.now().toEpochMilli(), note))
    suspend fun removeFromWatchlist(id: String) = db.watchlistDao().remove(id)
}
