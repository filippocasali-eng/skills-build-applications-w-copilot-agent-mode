package com.marketpilot.data.repositories

import androidx.room.withTransaction
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.database.CandleEntity
import com.marketpilot.core.database.EarningsEventEntity
import com.marketpilot.core.database.EtfScoreEntity
import com.marketpilot.core.database.FetchMarkerEntity
import com.marketpilot.core.database.FundamentalsEntity
import com.marketpilot.core.database.FxRateEntity
import com.marketpilot.core.database.IndicatorSnapshotEntity
import com.marketpilot.core.database.MacroObservationEntity
import com.marketpilot.core.database.MarketAssessmentEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.database.ProviderStatusEntity
import com.marketpilot.core.database.RefreshLogEntity
import com.marketpilot.core.database.SecTickerEntity
import com.marketpilot.core.database.StockScoreEntity
import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstrumentRole
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderOperationalState
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.data.providers.DataProvider
import com.marketpilot.data.providers.ProviderRegistry
import com.marketpilot.data.providers.impl.TrackedManagers
import com.marketpilot.data.repositories.di.NetworkMonitor
import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.market.MarketAssessor
import com.marketpilot.domain.market.MarketInputs
import com.marketpilot.domain.scoring.EtfAnalyzer
import com.marketpilot.domain.scoring.NewsClassifier
import com.marketpilot.domain.scoring.StockInput
import com.marketpilot.domain.scoring.StockRanker
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton

enum class RefreshTrigger { MANUAL, BACKGROUND, STARTUP }

enum class StepStatus { OK, PARTIAL, SKIPPED, FAILED }

sealed interface RefreshState {
    data object Idle : RefreshState
    data class Running(val step: Int, val totalSteps: Int, val label: String) : RefreshState
    data class Finished(val summary: RefreshSummaryDto, val status: String, val at: Instant) : RefreshState
}

sealed interface RefreshOutcome {
    data object AlreadyRunning : RefreshOutcome
    data class Done(val summary: RefreshSummaryDto, val status: String) : RefreshOutcome
}

/**
 * Orchestrates a market refresh entirely on the device:
 *  1 session · 2 connectivity · 3 provider status · 4 downloads · 5 rate limits · 6 normalization ·
 *  7 timestamp validation · 8 persistence · 9 indicators · 10 market score · 11 ETF ranking ·
 *  12 stock ranking · 13 paper-order reconciliation · 14 decision snapshots · 15 summary.
 * Failures are isolated per step/provider: valid cached data is never deleted, stale data keeps its
 * original timestamps, and concurrent refreshes are rejected.
 */
@Singleton
class RefreshEngine @Inject constructor(
    private val db: MarketPilotDatabase,
    private val registry: ProviderRegistry,
    private val market: MarketDataRepository,
    private val settings: SettingsRepository,
    private val portfolio: PortfolioRepository,
    private val decisions: DecisionTrackerRepository,
    private val alerts: AlertRepository,
    private val network: NetworkMonitor,
    private val clock: AppClock,
) {
    private val mutex = Mutex()
    private val _state = MutableStateFlow<RefreshState>(RefreshState.Idle)
    val state: StateFlow<RefreshState> = _state.asStateFlow()
    @Volatile private var job: Job? = null

    fun cancel() { job?.cancel(CancellationException("Aggiornamento annullato dall'utente")) }

    val isRunning: Boolean get() = mutex.isLocked

    private class Ctx(val now: Instant) {
        val steps = mutableListOf<RefreshStepDto>()
        val failed = mutableListOf<String>()
        val notes = mutableListOf<String>()
        val updated = AtomicInteger(0)
        var fills = 0
        var snapshots = 0
    }

    suspend fun refresh(trigger: RefreshTrigger): RefreshOutcome {
        if (!mutex.tryLock()) return RefreshOutcome.AlreadyRunning
        try {
            return withContext(Dispatchers.IO) {
                job = currentCoroutineContext()[Job]
                runPipeline(trigger)
            }
        } finally {
            job = null
            mutex.unlock()
        }
    }

    private suspend fun step(ctx: Ctx, index: Int, label: String, block: suspend () -> Pair<StepStatus, String>) {
        _state.value = RefreshState.Running(index, TOTAL_STEPS, label)
        val start = System.currentTimeMillis()
        val (status, detail) = try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            StepStatus.FAILED to (e.message ?: e.javaClass.simpleName)
        }
        ctx.steps += RefreshStepDto(label, status.name, detail, System.currentTimeMillis() - start)
    }

    private suspend fun runPipeline(trigger: RefreshTrigger): RefreshOutcome {
        val now = clock.now()
        val ctx = Ctx(now)
        val logId = db.refreshLogDao().insert(RefreshLogEntity(startedAtMs = now.toEpochMilli(), finishedAtMs = null, trigger = trigger.name, status = "RUNNING", summaryJson = "{}"))
        market.ensureCatalog()
        val s = settings.current()
        var online = false
        try {
            withTimeout(Duration.ofMinutes(12).toMillis()) {
                step(ctx, 1, "Sessione di mercato") {
                    val st = MarketSessions.status(Calendars.NYSE, now)
                    StepStatus.OK to "${st.phase.label} (NYSE). Ultima seduta completata: ${st.lastCompletedSession}"
                }
                step(ctx, 2, "Connettività") {
                    online = network.isOnline()
                    if (online) StepStatus.OK to "Connessione disponibile" else StepStatus.SKIPPED to "Offline: uso dei dati salvati (non aggiornati)"
                }
                step(ctx, 3, "Stato delle fonti") {
                    val enabled = registry.all.filter { registry.isEnabled(it) }
                    val missing = buildList {
                        if (registry.redditNeedsConfiguration()) add("Reddit (client ID)")
                        if (settings.providerSettings(s).alphaVantageKey.isNullOrBlank()) add("Alpha Vantage (chiave)")
                        if (settings.providerSettings(s).finnhubKey.isNullOrBlank()) add("Finnhub (chiave)")
                    }
                    StepStatus.OK to "${enabled.size} fonti attive" + if (missing.isNotEmpty()) "; da configurare: ${missing.joinToString()}" else ""
                }
                if (online) {
                    step(ctx, 4, "Download dati (prezzi, cambi, macro)") { downloadCore(ctx, s.cache.historyYears) }
                    step(ctx, 4, "Download dati alternativi (SEC, news, Reddit)") { downloadAlternative(ctx) }
                } else {
                    ctx.steps += RefreshStepDto("Download dati", StepStatus.SKIPPED.name, "Nessuna connessione", 0)
                }
                step(ctx, 5, "Limiti di richiesta") { StepStatus.OK to "Rispettati automaticamente (spaziatura per host, backoff su HTTP 429)" }
                step(ctx, 6, "Normalizzazione") { StepStatus.OK to "Barre ordinate, deduplicate, sedute incomplete escluse" }
                step(ctx, 7, "Validazione timestamp") { validateTimestamps(now) }
                step(ctx, 8, "Salvataggio locale") {
                    db.candleDao().pruneOlderThan(LocalDate.now().minusYears(s.cache.historyYears.toLong() + 1).toEpochDay())
                    db.newsDao().prune(now.minus(Duration.ofDays(s.cache.newsRetentionDays.toLong())).toEpochMilli())
                    db.refreshLogDao().prune(now.minus(Duration.ofDays(90)).toEpochMilli())
                    StepStatus.OK to "${db.candleDao().count()} barre giornaliere in archivio locale"
                }
                val asOf = MarketSessions.lastCompletedSession(Calendars.NYSE, now)
                step(ctx, 9, "Indicatori tecnici") { computeIndicators(now) }
                step(ctx, 10, "Punteggi di mercato") { assessMarket(asOf, now) }
                step(ctx, 11, "Classifica ETF") { rankEtfs(asOf, now) }
                step(ctx, 12, "Classifica titoli") { rankStocks(asOf, now, s) }
                step(ctx, 13, "Riconciliazione ordini simulati") {
                    val r = portfolio.reconcile()
                    ctx.fills = r.fills.size
                    StepStatus.OK to "${r.fills.size} esecuzioni simulate; valutazione al ${Fmt.ts(r.evaluatedAt)}"
                }
                step(ctx, 14, "Snapshot decisioni") {
                    val n = decisions.saveSnapshots(asOf, now)
                    ctx.snapshots = n
                    val ev = decisions.evaluatePending()
                    StepStatus.OK to "$n nuovi snapshot immutabili; $ev valutazioni storiche aggiornate"
                }
                step(ctx, 15, "Avvisi e riepilogo") {
                    val fired = alerts.evaluate(ctx.fills)
                    StepStatus.OK to "$fired avvisi generati"
                }
            }
        } catch (e: CancellationException) {
            ctx.notes += "Aggiornamento interrotto: ${e.message ?: "annullato"}. I dati già salvati restano validi."
            finish(logId, ctx, "CANCELLED")
            throw e
        } catch (e: Exception) {
            ctx.notes += "Timeout o errore generale: ${e.message}"
        }
        val status = when {
            ctx.steps.any { it.status == StepStatus.FAILED.name } || ctx.failed.isNotEmpty() || !online -> "PARTIAL"
            else -> "COMPLETED"
        }
        val summary = finish(logId, ctx, status)
        return RefreshOutcome.Done(summary, status)
    }

    private suspend fun finish(logId: Long, ctx: Ctx, status: String): RefreshSummaryDto {
        val summary = RefreshSummaryDto(ctx.steps.toList(), ctx.updated.get(), ctx.failed.distinct(), ctx.fills, ctx.snapshots, ctx.notes.toList())
        withContext(kotlinx.coroutines.NonCancellable) {
            db.refreshLogDao().finish(logId, clock.now().toEpochMilli(), status, dbJson.encodeToString(RefreshSummaryDto.serializer(), summary))
        }
        _state.value = RefreshState.Finished(summary, status, clock.now())
        return summary
    }

    // ---------------------------------------------------------------------------------------------
    private suspend fun recordStatus(p: DataProvider, r: ProviderResult<*>) {
        val now = clock.now().toEpochMilli()
        val prev = db.providerStatusDao().byId(p.descriptor.id)
        val state = when {
            r.isSuccess -> ProviderOperationalState.OPERATIONAL
            r.error?.kind == ProviderErrorKind.NOT_CONFIGURED -> ProviderOperationalState.NEEDS_CONFIGURATION
            r.error?.kind == ProviderErrorKind.BLOCKED || r.error?.kind == ProviderErrorKind.UNSUPPORTED -> ProviderOperationalState.UNSUPPORTED
            else -> ProviderOperationalState.DEGRADED
        }
        db.providerStatusDao().upsert(
            ProviderStatusEntity(
                p.descriptor.id, state.name,
                if (r.isSuccess) now else prev?.lastSuccessAtMs, now,
                if (r.isSuccess) null else r.error?.message,
                (prev?.successCount ?: 0) + if (r.isSuccess) 1 else 0,
                (prev?.failureCount ?: 0) + if (r.isSuccess) 0 else 1,
            ),
        )
    }

    private suspend fun marker(key: String): Instant? = db.cacheDao().marker(key)?.let { Instant.ofEpochMilli(it.lastFetchMs) }
    private suspend fun mark(key: String) = db.cacheDao().mark(FetchMarkerEntity(key, clock.now().toEpochMilli()))
    private fun olderThan(i: Instant?, d: Duration) = i == null || Duration.between(i, clock.now()) > d

    private suspend fun priceInstruments(): List<Instrument> {
        val all = market.instruments()
        val watch = market.watchlist().toSet()
        val held = portfolio.ledger().mapNotNull { it.instrumentId }.toSet()
        val pending = portfolio.orders().filter { it.status.isActive }.map { it.instrumentId }.toSet()
        return all.filter { i ->
            i.roles.isNotEmpty() || i.id in watch || i.id in held || i.id in pending
        }.filter { it.assetClass != AssetClass.VOLATILITY_INDEX }
    }

    private suspend fun downloadCore(ctx: Ctx, historyYears: Int): Pair<StepStatus, String> = coroutineScope {
        val today = ctx.now.atZone(AppClock.DISPLAY_ZONE).toLocalDate()
        val defaultStart = today.minusYears(historyYears.toLong())
        val notes = mutableListOf<String>()
        // FX (ECB)
        val fxSeries = db.macroDao().fxSeries("USD")
        val lastFx = fxSeries.lastOrNull()?.epochDay?.let(LocalDate::ofEpochDay)
        suspend fun storeFx(from: LocalDate, timeoutMs: Long): Boolean = withTimeoutOrNull(timeoutMs) {
            val r = registry.ecb.eurRates(setOf("USD", "GBP"), from)
            recordStatus(registry.ecb, r)
            r.data?.let { rates -> db.macroDao().upsertFx(rates.map { FxRateEntity(it.quote, it.date.toEpochDay(), it.rate, registry.ecb.descriptor.id) }) }
            if (!r.isSuccess) notes += "Cambi BCE non disponibili: ${r.error?.message}"
            r.isSuccess
        } ?: false.also { notes += "Timeout cambi BCE" }
        // Recent rates first (small 90-day file): orders and valuations need today's rate even if the
        // multi-year history download is slow or fails.
        val recentOk = storeFx(maxOf(lastFx?.minusDays(7) ?: today.minusDays(80), today.minusDays(80)), 60_000)
        if (recentOk) notes += "Cambi BCE aggiornati"
        val historyStart = fxSeries.firstOrNull()?.epochDay?.let(LocalDate::ofEpochDay)
        if (historyStart == null || historyStart.isAfter(defaultStart.plusDays(10))) {
            if (storeFx(defaultStart, 120_000)) notes += "Storico cambi BCE scaricato"
        }
        // Fallback: Federal Reserve H.10 rates via FRED (DEXUSEU = USD per EUR, DEXUSUK = USD per GBP)
        // when the ECB is unreachable (e.g. its certificate chain is not trusted by the device).
        val usdAfter = db.macroDao().fxSeries("USD").lastOrNull()?.epochDay?.let(LocalDate::ofEpochDay)
        if ((usdAfter == null || usdAfter.isBefore(today.minusDays(10))) && registry.isEnabled(registry.fred)) {
            val from = usdAfter?.minusDays(10) ?: defaultStart
            val eurUsd = withTimeoutOrNull(60_000) { registry.fred.series("DEXUSEU", from) }
            val gbpUsd = withTimeoutOrNull(60_000) { registry.fred.series("DEXUSUK", from) }
            val usdByDate = eurUsd?.data.orEmpty().associate { it.date to it.value }
            if (usdByDate.isNotEmpty()) {
                val rows = usdByDate.map { (d, v) -> FxRateEntity("USD", d.toEpochDay(), v, registry.fred.descriptor.id) } +
                    gbpUsd?.data.orEmpty().mapNotNull { g -> usdByDate[g.date]?.let { u -> FxRateEntity("GBP", g.date.toEpochDay(), u / g.value, registry.fred.descriptor.id) } }
                db.macroDao().upsertFx(rows)
                notes += "Cambi da Federal Reserve (FRED) come riserva della BCE"
            } else {
                notes += "Cambi non disponibili né da BCE né da FRED"
            }
        }
        // VIX + macro
        suspend fun macro(seriesId: String, store: String, chain: List<com.marketpilot.data.providers.MacroDataProvider>) {
            val last = market.macro(store).lastOrNull()?.date
            for (p in chain) {
                val r = withTimeoutOrNull(60_000) { p.series(seriesId, last?.minusDays(10) ?: defaultStart) } ?: continue
                recordStatus(p, r)
                val data = r.data ?: continue
                db.macroDao().upsertMacro(data.map { MacroObservationEntity(store, it.date.toEpochDay(), it.value, p.descriptor.id) })
                return
            }
            notes += "Serie $store non aggiornata"
        }
        macro("VIX", "VIX", registry.vixChain())
        if (registry.isEnabled(registry.fred)) {
            macro("DGS10", "DGS10", listOf(registry.fred))
            macro("T10Y2Y", "T10Y2Y", listOf(registry.fred))
        }
        // Prices: history (+ quote from the same Yahoo response when available)
        val instruments = priceInstruments()
        val chain = registry.historyChain()
        if (chain.isEmpty()) return@coroutineScope StepStatus.FAILED to "Nessuna fonte prezzi attiva: abilita Yahoo o configura Alpha Vantage nelle Fonti dati"
        val sem = Semaphore(3)
        instruments.map { inst ->
            async {
                sem.withPermit {
                    val last = market.lastCandleDate(inst.id)
                    val from = last?.minusDays(10) ?: defaultStart
                    var ok = false
                    for (p in chain) {
                        val r = withTimeoutOrNull(45_000) { p.dailyHistory(inst, from) } ?: continue
                        recordStatus(p, r)
                        val candles = r.data
                        if (candles != null && candles.isNotEmpty()) {
                            db.candleDao().upsert(candles.map { it.toEntity(p.descriptor.id, ctx.now) })
                            ok = true
                            break
                        }
                    }
                    if (ok) {
                        ctx.updated.incrementAndGet()
                        if (inst.roles.contains(InstrumentRole.ETF_RADAR) || inst.roles.contains(InstrumentRole.MARKET_BENCHMARK) || inst.id in market.watchlist()) {
                            for (qp in registry.quoteChain()) {
                                val q = withTimeoutOrNull(30_000) { qp.quote(inst) } ?: continue
                                recordStatus(qp, q)
                                val quote = q.data ?: continue
                                db.quoteDao().upsert(quote.toEntity(qp.descriptor.id, q.source.sourceUrl, ctx.now, q.freshness))
                                break
                            }
                        }
                    } else {
                        ctx.failed += inst.symbol
                    }
                }
            }
        }.awaitAll()
        val failed = ctx.failed.size
        val status = if (failed == 0) StepStatus.OK else if (failed < instruments.size) StepStatus.PARTIAL else StepStatus.FAILED
        status to "${instruments.size - failed}/${instruments.size} strumenti aggiornati. " + notes.joinToString(". ") +
            if (failed > 0) ". Non aggiornati (restano i dati salvati): ${ctx.failed.take(10).joinToString()}" else ""
    }

    private suspend fun downloadAlternative(ctx: Ctx): Pair<StepStatus, String> {
        val notes = mutableListOf<String>()
        var problems = 0
        val today = ctx.now.atZone(AppClock.DISPLAY_ZONE).toLocalDate()
        val universe = market.instrumentsWithRole(InstrumentRole.STOCK_UNIVERSE) +
            market.watchlist().mapNotNull { market.instrument(it) }.filter { it.assetClass == AssetClass.STOCK }
        val symbols = universe.map { it.symbol }.toSet()
        // SEC ticker map (weekly)
        if (registry.isEnabled(registry.sec)) {
            if (db.alternativeDataDao().tickerCount() == 0 || olderThan(marker("sec_tickers"), Duration.ofDays(7))) {
                val r = withTimeoutOrNull(60_000) { registry.sec.tickerMap() }
                if (r != null) {
                    recordStatus(registry.sec, r)
                    r.data?.let { e -> db.alternativeDataDao().upsertTickers(e.map { SecTickerEntity(it.ticker, it.cik, it.title) }); mark("sec_tickers") }
                }
            }
            // Insider radar: latest Form 4 feed (market-wide)
            val known = db.alternativeDataDao().knownAccessions().toSet()
            withTimeoutOrNull(120_000) {
                val r = registry.sec.latestForm4(maxFilings = 25, knownAccessions = known)
                recordStatus(registry.sec, r)
                r.data?.let { tx -> db.alternativeDataDao().upsertInsiders(tx.mapIndexed { i, t -> t.toEntity(i, ctx.now) }); notes += "${tx.size} transazioni dal feed Form 4" }
                if (!r.isSuccess) problems++
            }
            // Per-stock Form 4 (budgeted rotation: least recently fetched first)
            val budget = 8
            val form4Markers = db.cacheDao().markers("form4:").associate { it.key to it.lastFetchMs }
            val stale = universe.distinctBy { it.id }.sortedBy { form4Markers["form4:${it.symbol}"] ?: 0L }.take(budget)
            for (inst in stale) {
                if (!olderThan(marker("form4:${inst.symbol}"), Duration.ofHours(20))) continue
                val r = withTimeoutOrNull(60_000) { registry.sec.insiderTransactions(inst, today.minusDays(120), db.alternativeDataDao().knownAccessions().toSet(), 10) } ?: continue
                recordStatus(registry.sec, r)
                r.data?.let { tx -> db.alternativeDataDao().upsertInsiders(tx.mapIndexed { i, t -> t.toEntity(i, ctx.now) }); mark("form4:${inst.symbol}") }
            }
            // 13F (weekly per manager)
            val managers = settings.current().providers.trackedManagers.ifEmpty { TrackedManagers.DEFAULT.keys.toList() }
            for (cik in managers) {
                if (!olderThan(marker("13f:$cik"), Duration.ofDays(7))) continue
                val r = withTimeoutOrNull(90_000) { registry.sec.holdings(cik) } ?: continue
                recordStatus(registry.sec, r)
                r.data?.let { h ->
                    db.withTransaction {
                        db.alternativeDataDao().clearManager(cik)
                        db.alternativeDataDao().upsertHoldings(h.map { it.toEntity(ctx.now) })
                    }
                    mark("13f:$cik")
                }
            }
            // Fundamentals (weekly, budgeted)
            val fundMarkers = db.cacheDao().markers("fund:").associate { it.key to it.lastFetchMs }
            val fundStale = universe.distinctBy { it.id }.sortedBy { fundMarkers["fund:${it.id}"] ?: 0L }.take(6)
            for (inst in fundStale) {
                if (!olderThan(marker("fund:${inst.id}"), Duration.ofDays(7))) continue
                val r = withTimeoutOrNull(60_000) { registry.sec.fundamentals(inst) } ?: continue
                recordStatus(registry.sec, r)
                r.data?.let { f ->
                    db.cacheDao().upsertFundamentals(FundamentalsEntity(inst.id, dbJson.encodeToString(FundamentalsSnapshot.serializer(), f), f.fiscalPeriodEnd?.toEpochDay(), f.sourceUrl, ctx.now.toEpochMilli()))
                    mark("fund:${inst.id}")
                }
            }
        }
        // News
        val watched = market.watchlist().mapNotNull { market.instrument(it)?.symbol }.toMutableList()
        watched += topRankedSymbols()
        var newsCount = 0
        for (p in registry.newsProviders()) {
            val syms = if (p === registry.fedNews || p === registry.secNews) emptyList() else watched.distinct().take(12)
            if (syms.isEmpty() && !(p === registry.fedNews || p === registry.secNews)) continue
            val r = withTimeoutOrNull(90_000) { p.news(syms, today.minusDays(14)) } ?: continue
            recordStatus(p, r)
            r.data?.let { items ->
                val dedup = NewsClassifier.deduplicate(items + db.newsDao().since(ctx.now.minus(Duration.ofDays(14)).toEpochMilli()).map { it.toModel() })
                val newOnes = dedup.filter { d -> items.any { it.id == d.id } }
                    .map { it.copy(relevance = NewsClassifier.relevance(it, watched.toSet(), ctx.now)) }
                db.newsDao().insertIgnore(newOnes.map { it.toEntity(ctx.now) })
                newsCount += newOnes.size
            }
            if (!r.isSuccess) problems++
        }
        notes += "$newsCount notizie nuove"
        // Reddit
        registry.redditOrNull()?.let { rp ->
            val r = withTimeoutOrNull(120_000) { rp.tickerStats(symbols) }
            if (r != null) {
                recordStatus(rp, r)
                r.data?.let { st -> db.alternativeDataDao().upsertReddit(st.map { it.toEntity(ctx.now) }); notes += "Reddit: ${st.size} ticker menzionati" }
                if (!r.isSuccess) { problems++; notes += "Reddit: ${r.error?.message}" }
            }
        } ?: notes.add("Reddit non configurato")
        // Earnings calendar (daily)
        if (olderThan(marker("earnings"), Duration.ofHours(20))) {
            for (p in registry.earningsChain()) {
                val r = withTimeoutOrNull(60_000) { p.upcomingEarnings(symbols) } ?: continue
                recordStatus(p, r)
                val ev = r.data ?: continue
                db.alternativeDataDao().upsertEarnings(ev.map { EarningsEventEntity(it.symbol, it.date.toEpochDay(), it.providerId, ctx.now.toEpochMilli()) })
                mark("earnings")
                notes += "${ev.size} date trimestrali"
                break
            }
        }
        return (if (problems == 0) StepStatus.OK else StepStatus.PARTIAL) to notes.joinToString(". ")
    }

    private suspend fun topRankedSymbols(): List<String> =
        (db.analysisDao().observeLatestStockScores().firstOrNull() ?: emptyList()).take(8).mapNotNull { e ->
            runCatching { dbJson.decodeFromString(StockScoreDto.serializer(), e.json).symbol }.getOrNull()
        }

    private suspend fun validateTimestamps(now: Instant): Pair<StepStatus, String> {
        val quotes = db.quoteDao().observeAll().firstOrNull() ?: emptyList()
        val future = quotes.filter { it.observedAtMs > now.plusSeconds(300).toEpochMilli() }
        // Future-dated observations are impossible: they are flagged as unreliable (freshness UNKNOWN).
        future.forEach { q -> db.quoteDao().upsert(q.copy(freshness = com.marketpilot.core.model.Freshness.UNKNOWN.name)) }
        return if (future.isEmpty()) StepStatus.OK to "${quotes.size} quotazioni con timestamp coerenti"
        else StepStatus.PARTIAL to "${future.size} quotazioni con timestamp nel futuro marcate come non affidabili"
    }

    private suspend fun computeIndicators(now: Instant): Pair<StepStatus, String> {
        var n = 0
        for (inst in market.instruments()) {
            val c = market.candles(inst.id)
            val snap = TechnicalSnapshot.from(c) ?: continue
            db.analysisDao().upsertIndicator(IndicatorSnapshotEntity(inst.id, snap.lastDate.toEpochDay(), dbJson.encodeToString(TechnicalDto.serializer(), TechnicalDto.from(snap)), now.toEpochMilli()))
            n++
        }
        return (if (n > 0) StepStatus.OK else StepStatus.FAILED) to "Indicatori calcolati per $n strumenti"
    }

    private suspend fun assessMarket(asOf: LocalDate, now: Instant): Pair<StepStatus, String> {
        val sectors = InstrumentCatalog.sectorEtfs.associate { it.symbol to market.candles(it.id) }.filterValues { it.isNotEmpty() }
        val universe = market.instrumentsWithRole(InstrumentRole.STOCK_UNIVERSE).associate { it.symbol to market.candles(it.id) }.filterValues { it.isNotEmpty() }
        val fomc = db.newsDao().since(now.minus(Duration.ofDays(10)).toEpochMilli())
            .filter { it.providerId == "fed_rss" && it.headline.contains("FOMC", ignoreCase = true) }
            .map { Instant.ofEpochMilli(it.publishedAtMs).atZone(Calendars.NYSE.zone).toLocalDate() }
        val a = MarketAssessor.assess(
            MarketInputs(
                asOf, market.candles(InstrumentCatalog.SPY), market.candles(InstrumentCatalog.QQQ), market.macro("VIX"),
                market.macro("DGS10"), market.macro("T10Y2Y"), sectors, universe, fomc,
            ),
        )
        db.analysisDao().upsertAssessment(
            MarketAssessmentEntity(
                a.asOf.toEpochDay(), a.regime.name, a.marketScore, a.etfOpportunityScore, a.swingOpportunityScore, a.coverage,
                dbJson.encodeToString(componentListSerializer, a.components), dbJson.encodeToString(componentListSerializer, a.etfComponents),
                dbJson.encodeToString(stringListSerializer, a.risks), a.summary, a.modelVersion, now.toEpochMilli(),
            ),
        )
        return StepStatus.OK to "Regime ${a.regime.label}, punteggio ${a.marketScore ?: "n/d"}, copertura ${(a.coverage * 100).toInt()}%"
    }

    private suspend fun rankEtfs(asOf: LocalDate, now: Instant): Pair<StepStatus, String> {
        val regime = db.analysisDao().latestAssessment()?.toView()?.regime ?: com.marketpilot.core.model.MarketRegime.INSUFFICIENT_DATA
        val alloc = portfolio.etfAllocation()
        val etfs = market.instruments().filter { it.assetClass == AssetClass.ETF && (InstrumentRole.ETF_RADAR in it.roles || InstrumentRole.MARKET_BENCHMARK in it.roles) }
        val rows = etfs.map { inst ->
            val a = EtfAnalyzer.analyze(inst, market.candles(inst.id), MarketSessions.lastCompletedSession(Calendars.forExchange(inst.exchange), now), regime, alloc)
            EtfScoreEntity(inst.id, asOf.toEpochDay(), a.opportunityScore, dbJson.encodeToString(EtfAnalysisDto.serializer(), EtfAnalysisDto.from(a)), now.toEpochMilli())
        }
        db.analysisDao().upsertEtfScores(rows)
        return StepStatus.OK to "${rows.count { it.score != null }}/${rows.size} ETF con punteggio"
    }

    private suspend fun rankStocks(asOf: LocalDate, now: Instant, s: com.marketpilot.core.datastore.AppSettings): Pair<StepStatus, String> {
        val regime = db.analysisDao().latestAssessment()?.toView()?.regime ?: com.marketpilot.core.model.MarketRegime.INSUFFICIENT_DATA
        val spy = market.candles(InstrumentCatalog.SPY)
        val stocks = (market.instrumentsWithRole(InstrumentRole.STOCK_UNIVERSE) +
            market.watchlist().mapNotNull { market.instrument(it) }.filter { it.assetClass == AssetClass.STOCK }).distinctBy { it.id }
        val secLoaded = db.alternativeDataDao().tickerCount() > 0
        val managersLoaded = db.alternativeDataDao().managersLoaded() > 0
        val redditWindow = db.alternativeDataDao().latestRedditWindow()
        val redditFresh = redditWindow != null && Duration.between(Instant.ofEpochMilli(redditWindow), now) < Duration.ofDays(2)
        val newsAvailable = registry.newsProviders().any { it === registry.yahooNews || it === registry.finnhub }
        val inputs = stocks.map { inst ->
            val insiderFetched = marker("form4:${inst.symbol}") != null
            StockInput(
                instrument = inst,
                candles = market.candles(inst.id),
                benchmark = spy,
                fundamentals = db.cacheDao().fundamentals(inst.id)?.let { runCatching { dbJson.decodeFromString(FundamentalsSnapshot.serializer(), it.json) }.getOrNull() },
                insiderTransactions = if (secLoaded && insiderFetched) db.alternativeDataDao().insidersFor(inst.symbol).map { it.toModel() } else null,
                institutional = if (managersLoaded) db.alternativeDataDao().holdingsFor(inst.symbol).map { it.toModel() } else null,
                reddit = if (redditFresh) db.alternativeDataDao().latestRedditFor(inst.symbol)?.toModel() else null,
                redditAvailable = redditFresh,
                news = if (newsAvailable) db.newsDao().since(now.minus(Duration.ofDays(10)).toEpochMilli()).map { it.toModel() }.filter { inst.symbol in it.relatedSymbols } else null,
                nextEarnings = db.alternativeDataDao().nextEarnings(inst.symbol, asOf.toEpochDay())?.let { com.marketpilot.core.model.EarningsEvent(it.symbol, LocalDate.ofEpochDay(it.epochDay), it.providerId) },
            )
        }
        val ranking = StockRanker.rank(inputs, asOf, regime, SettingsRepository.weights(s), SettingsRepository.risk(s))
        db.analysisDao().upsertStockScores(ranking.all.map { sc ->
            StockScoreEntity(
                sc.instrument.id, asOf.toEpochDay(), sc.score, sc.rankingScore, sc.coverage, sc.confidence, sc.recommendation.name, sc.risk.name,
                dbJson.encodeToString(StockScoreDto.serializer(), StockScoreDto.from(sc)), now.toEpochMilli(),
            )
        })
        return StepStatus.OK to "${ranking.all.count { !it.excluded }}/${ranking.all.size} titoli classificati; candidati: ${ranking.top5.size}" +
            (ranking.noTradeReason?.let { ". NESSUN TRADE: $it" } ?: "")
    }

    companion object {
        const val TOTAL_STEPS = 15
    }
}

internal object Fmt {
    fun ts(i: Instant): String = java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm").format(i.atZone(AppClock.DISPLAY_ZONE))
}
