package com.marketpilot.data.repositories

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.database.CandleEntity
import com.marketpilot.core.database.FxRateEntity
import com.marketpilot.core.database.MacroObservationEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.datastore.SettingsStore
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.core.security.SecretStore
import com.marketpilot.core.network.HostRateLimiter
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.ProviderRegistry
import com.marketpilot.data.repositories.di.NetworkMonitor
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

class FakeSecrets : SecretStore {
    private val m = mutableMapOf<SecretKeyName, String>()
    override fun get(name: SecretKeyName) = m[name]
    override fun put(name: SecretKeyName, value: String?) { if (value.isNullOrBlank()) m.remove(name) else m[name] = value }
}

class RecordingNotifier : AlertNotifier {
    val messages = mutableListOf<String>()
    override fun notify(id: Int, title: String, text: String) { messages += "$title: $text" }
}

class MutableClock(var instant: Instant) : AppClock { override fun now(): Instant = instant }

/** Wires the real repositories against an in-memory database; network is fully simulated (never real). */
class TestEnv(online: Boolean = false, failAllRequests: Boolean = true, start: Instant = Instant.parse("2026-10-28T12:00:00Z")) {
    val context: Context = ApplicationProvider.getApplicationContext()
    val db: MarketPilotDatabase = Room.inMemoryDatabaseBuilder(context, MarketPilotDatabase::class.java).allowMainThreadQueries().build()
    val clock = MutableClock(start)
    val store = SettingsStore(PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob())) {
        File(context.filesDir, "settings-${UUID.randomUUID()}.preferences_pb")
    })
    val secrets = FakeSecrets()
    val settings = SettingsRepository(store, secrets)
    val market = MarketDataRepository(db, clock)
    val portfolio = PortfolioRepository(db, market, settings, clock)
    val decisions = DecisionTrackerRepository(db, market, settings)
    val notifier = RecordingNotifier()
    val alerts = AlertRepository(db, market, settings, notifier, clock)
    var requests = 0
    private val client = OkHttpClient.Builder().addInterceptor { chain ->
        requests++
        if (failAllRequests) Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(503).message("Service Unavailable")
            .body("".toResponseBody()).build()
        else chain.proceed(chain.request())
    }.build()
    val registry = ProviderRegistry({ settings.providerSettings() }, { "test-device" }, { emptyList() }, clock, HttpFetcher(client, HostRateLimiter(emptyMap(), 0), maxAttempts = 1))
    var isOnline = online
    val engine = RefreshEngine(db, registry, market, settings, portfolio, decisions, alerts, NetworkMonitor { isOnline }, clock)
    val onDemand = OnDemandRepository(db, registry, market, settings, NetworkMonitor { isOnline }, clock)
    val export = ExportRepository(db, settings, portfolio, clock)

    /**
     * Deterministic synthetic bars for tests ONLY (never used by the app). Sessions follow the
     * real exchange calendar and end at [end].
     */
    fun seedSeries(id: String, exchange: String, sessions: Int, end: LocalDate, drift: Double, base: Double = 100.0): List<CandleEntity> {
        val cal = Calendars.forExchange(exchange)
        val dates = ArrayDeque<LocalDate>()
        var d = end
        while (dates.size < sessions) { if (cal.isTradingDay(d)) dates.addFirst(d); d = d.minusDays(1) }
        return dates.mapIndexed { i, date ->
            val p = base * Math.pow(1 + drift, i.toDouble()) * (1 + 0.01 * kotlin.math.sin(i / 5.0))
            CandleEntity(id, date.toEpochDay(), p * 0.997, p * 1.01, p * 0.99, p, null, 3_000_000, "test", 0)
        }
    }

    suspend fun seedMarket(end: LocalDate = LocalDate.of(2026, 10, 27)) {
        market.ensureCatalog()
        val rows = mutableListOf<CandleEntity>()
        rows += seedSeries(InstrumentCatalog.SPY, "NYSEARCA", 320, end, 0.0006, 500.0)
        rows += seedSeries(InstrumentCatalog.QQQ, "NASDAQ", 320, end, 0.0008, 400.0)
        InstrumentCatalog.sectorEtfs.forEach { rows += seedSeries(it.id, it.exchange, 320, end, 0.0005) }
        InstrumentCatalog.stockUniverse.take(30).forEachIndexed { i, s -> rows += seedSeries(s.id, s.exchange, 320, end, 0.0002 * (i % 7), 50.0 + i) }
        InstrumentCatalog.ucitsEtfs.forEach { rows += seedSeries(it.id, it.exchange, 320, end, 0.0004) }
        db.candleDao().upsert(rows)
        db.macroDao().upsertMacro((0 until 40).map { MacroObservationEntity("VIX", end.minusDays(39L - it).toEpochDay(), 15.0, "test") })
        db.macroDao().upsertFx((0 until 400).map { FxRateEntity("USD", end.minusDays(399L - it).toEpochDay(), 1.10, "test") })
    }
}
