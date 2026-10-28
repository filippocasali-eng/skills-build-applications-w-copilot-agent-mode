package com.marketpilot.data.repositories

import androidx.room.withTransaction
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.database.ClosedPositionEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.database.OpenPositionEntity
import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.Instrument
import com.marketpilot.domain.papertrading.EngineEvent
import com.marketpilot.domain.papertrading.EquityPoint
import com.marketpilot.domain.papertrading.OrderPlacement
import com.marketpilot.domain.papertrading.OrderTicket
import com.marketpilot.domain.papertrading.PaperFill
import com.marketpilot.domain.papertrading.PaperOrder
import com.marketpilot.domain.papertrading.PaperTradingEngine
import com.marketpilot.domain.papertrading.PerformanceAnalytics
import com.marketpilot.domain.papertrading.PlacementContext
import com.marketpilot.domain.papertrading.TicketPreview
import com.marketpilot.domain.papertrading.TradeStats
import com.marketpilot.domain.papertrading.ClosedTrade
import com.marketpilot.domain.portfolio.AccountSnapshot
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.portfolio.CashMovements
import com.marketpilot.domain.portfolio.CashResult
import com.marketpilot.domain.portfolio.LedgerEntry
import com.marketpilot.domain.portfolio.PortfolioCalculator
import com.marketpilot.domain.portfolio.PriceMark
import com.marketpilot.domain.scoring.EtfAllocation
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

data class Accounts(val etf: AccountSnapshot, val trading: AccountSnapshot, val marksAsOf: LocalDate?)

data class AccountAnalytics(
    val account: AccountType,
    val curve: List<EquityPoint>,
    val benchmark: List<EquityPoint>,
    val benchmarkLabel: String,
    val maxDrawdown: Double?,
    val stats: TradeStats,
    val closedTrades: List<ClosedTrade>,
    val dailyChangeEur: Double?,
)

data class ReconcileResult(val fills: List<PaperFill>, val events: List<EngineEvent>, val evaluatedAt: Instant)

@Singleton
class PortfolioRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val market: MarketDataRepository,
    private val settings: SettingsRepository,
    private val clock: AppClock,
) {
    private val engineLock = Mutex()

    fun observeLedger(): Flow<List<LedgerEntry>> = db.ledgerDao().observeAll().map { l -> l.map { it.toModel() } }
    fun observeOrders(): Flow<List<PaperOrder>> = db.paperTradingDao().observeOrders().map { l -> l.map { it.toModel() } }
    fun observeFills(): Flow<List<PaperFill>> = db.paperTradingDao().observeFills().map { l -> l.map { it.toModel() } }

    suspend fun ledger(): List<LedgerEntry> = db.ledgerDao().all().map { it.toModel() }
    suspend fun orders(): List<PaperOrder> = db.paperTradingDao().orders().map { it.toModel() }

    private fun today(): LocalDate = clock.now().atZone(AppClock.DISPLAY_ZONE).toLocalDate()

    /** Price marks from the latest completed daily bar (falls back to the stored quote). */
    suspend fun marks(instrumentIds: Collection<String>): Map<String, PriceMark> {
        val fx = market.fxLookup()
        return instrumentIds.mapNotNull { id ->
            val inst = market.instrument(id) ?: return@mapNotNull null
            val last = db.candleDao().series(id).lastOrNull()
            val q = market.quote(id)
            val (price, date) = when {
                last != null -> last.close to LocalDate.ofEpochDay(last.epochDay)
                q != null -> q.quote.price to q.quote.observedAt.atZone(AppClock.DISPLAY_ZONE).toLocalDate()
                else -> return@mapNotNull null
            }
            val rate = if (inst.currency == "EUR") 1.0 else fx.eurTo(inst.currency, date) ?: return@mapNotNull null
            id to PriceMark(price, inst.currency, rate, date)
        }.toMap()
    }

    fun observeAccounts(): Flow<Accounts> = combine(db.ledgerDao().observeAll(), db.paperTradingDao().observeOrders(), db.quoteDao().observeAll()) { l, o, _ ->
        val ledger = l.map { it.toModel() }
        val orders = o.map { it.toModel() }
        val ids = PortfolioCalculator.positions(ledger, AccountType.ETF).map { it.instrumentId } + PortfolioCalculator.positions(ledger, AccountType.TRADING).map { it.instrumentId }
        val marks = marks(ids.toSet())
        Accounts(
            PortfolioCalculator.snapshot(ledger, AccountType.ETF, marks, OrderPlacement.reservedCash(orders, AccountType.ETF)),
            PortfolioCalculator.snapshot(ledger, AccountType.TRADING, marks, OrderPlacement.reservedCash(orders, AccountType.TRADING)),
            marks.values.maxOfOrNull { it.date },
        )
    }

    suspend fun snapshot(account: AccountType): AccountSnapshot {
        val ledger = ledger()
        val ids = PortfolioCalculator.positions(ledger, account).map { it.instrumentId }
        return PortfolioCalculator.snapshot(ledger, account, marks(ids), OrderPlacement.reservedCash(orders(), account))
    }

    private suspend fun append(result: CashResult): String? = when (result) {
        is CashResult.Rejected -> result.reason
        is CashResult.Ok -> { db.ledgerDao().append(result.entries.map { it.toEntity() }); null }
    }

    /** Returns null on success, otherwise the rejection reason. */
    suspend fun deposit(account: AccountType, amount: Double, note: String? = null): String? = append(CashMovements.deposit(account, amount, today(), clock.now(), note))
    suspend fun withdraw(account: AccountType, amount: Double): String? = append(CashMovements.withdraw(account, amount, snapshot(account).availableCashEur, today(), clock.now()))
    suspend fun transfer(from: AccountType, to: AccountType, amount: Double, note: String? = null): String? =
        append(CashMovements.transfer(from, to, amount, snapshot(from).availableCashEur, today(), clock.now(), note))
    suspend fun dividend(account: AccountType, instrumentId: String, amount: Double): String? = append(CashMovements.dividend(account, instrumentId, amount, today(), clock.now()))

    // Paper orders ---------------------------------------------------------------------------------
    private suspend fun placementContext(t: OrderTicket): PlacementContext {
        val s = settings.current()
        val inst = market.instrument(t.instrumentId)
        val last = db.candleDao().series(t.instrumentId).lastOrNull()?.close ?: market.quote(t.instrumentId)?.quote?.price
        val rate = if (t.currency == "EUR") 1.0 else market.fxLookup().eurTo(t.currency, today())
        return PlacementContext(
            snapshot(t.account), orders().filter { it.status.isActive }, last, rate,
            SettingsRepository.risk(s), SettingsRepository.simulation(s), clock.now(),
        ).also { require(inst != null) { "Strumento sconosciuto" } }
    }

    fun ticketFor(inst: Instrument, account: AccountType) = OrderTicket(
        account, inst.id, inst.exchange, inst.currency, inst.assetClass, inst.isUcits,
        com.marketpilot.domain.papertrading.OrderSide.BUY, com.marketpilot.domain.papertrading.OrderType.LIMIT, 0,
    )

    suspend fun preview(t: OrderTicket): TicketPreview = OrderPlacement.preview(t, placementContext(t))

    suspend fun place(t: OrderTicket): OrderPlacement.Placement {
        val p = OrderPlacement.place(t, placementContext(t))
        db.paperTradingDao().upsertOrders(listOf(p.order.toEntity(clock.now())))
        return p
    }

    suspend fun cancel(orderId: String): Boolean {
        val all = orders()
        val o = all.firstOrNull { it.id == orderId } ?: return false
        val changed = OrderPlacement.cancel(o, all)
        if (changed.isEmpty()) return false
        db.paperTradingDao().upsertOrders(changed.map { it.toEntity(clock.now()) })
        return true
    }

    /**
     * Evaluates pending orders against stored daily bars (no look-ahead, only completed sessions) and
     * persists fills + ledger rows atomically. Safe to call repeatedly (e.g. at app start and after refresh).
     */
    suspend fun reconcile(): ReconcileResult = engineLock.withLock {
        val now = clock.now()
        val s = settings.current()
        val orders = orders()
        val active = orders.filter { it.status.isActive }
        if (active.isEmpty()) {
            rebuildPositions()
            settings.update { it.copy(lastPaperEvaluationMs = now.toEpochMilli()) }
            return@withLock ReconcileResult(emptyList(), emptyList(), now)
        }
        val candles = active.map { it.instrumentId }.distinct().associateWith { market.candles(it) }
        val engine = PaperTradingEngine(SettingsRepository.simulation(s))
        val result = engine.evaluate(orders, ledger(), candles, market.fxLookup(), now)
        db.withTransaction {
            db.paperTradingDao().upsertOrders(result.orders.map { it.toEntity(now) })
            if (result.fills.isNotEmpty()) db.paperTradingDao().insertFills(result.fills.map { it.toEntity() })
            if (result.ledger.isNotEmpty()) db.ledgerDao().append(result.ledger.map { it.toEntity() })
        }
        rebuildPositions()
        settings.update { it.copy(lastPaperEvaluationMs = now.toEpochMilli()) }
        ReconcileResult(result.fills, result.events, now)
    }

    /** Materializes open/closed position tables from the ledger (the ledger stays the source of truth). */
    suspend fun rebuildPositions() {
        val ledger = ledger()
        val now = clock.now().toEpochMilli()
        val open = AccountType.entries.flatMap { a ->
            PortfolioCalculator.positions(ledger, a).filter { it.quantity > 0 }.map {
                OpenPositionEntity(a.name, it.instrumentId, it.quantity, it.currency, it.avgCostEur, it.avgPriceCcy, it.costBasisEur, it.openedOn?.toEpochDay(), now)
            }
        }
        val closed = AccountType.entries.flatMap { a ->
            PerformanceAnalytics.closedTrades(ledger, a).map {
                ClosedPositionEntity(account = a.name, instrumentId = it.instrumentId, entryEpochDay = it.entryDate?.toEpochDay(), exitEpochDay = it.exitDate.toEpochDay(),
                    quantity = it.quantity, costEur = it.costEur, proceedsEur = it.proceedsEur)
            }
        }
        db.withTransaction {
            db.paperTradingDao().clearOpen(); db.paperTradingDao().clearClosed()
            db.paperTradingDao().insertOpen(open); db.paperTradingDao().insertClosed(closed)
        }
    }

    suspend fun analytics(account: AccountType): AccountAnalytics {
        val ledger = ledger()
        val acct = ledger.filter { it.account == account }
        val trades = PerformanceAnalytics.closedTrades(ledger, account)
        val stats = PerformanceAnalytics.stats(trades)
        val benchId = if (account == AccountType.ETF) InstrumentCatalog.VWCE else InstrumentCatalog.SPY
        val benchLabel = if (account == AccountType.ETF) "VWCE (stessi versamenti)" else "SPY (stessi versamenti)"
        if (acct.isEmpty()) return AccountAnalytics(account, emptyList(), emptyList(), benchLabel, null, stats, trades, null)
        val ids = acct.mapNotNull { it.instrumentId }.distinct()
        val candles = ids.associateWith { market.candles(it) }
        val currencies = ids.associateWith { market.instrument(it)?.currency ?: "EUR" }
        val fx = market.fxLookup()
        val from = acct.minOf { it.sessionDate }
        val curve = PerformanceAnalytics.equityCurve(ledger, account, candles, currencies, fx, from, today(), Calendars.NYSE)
        val bench = market.instrument(benchId)?.let { b -> PerformanceAnalytics.benchmarkCurve(curve, market.candles(benchId), b.currency, fx) } ?: emptyList()
        val daily = if (curve.size >= 2) curve.last().equityEur - curve[curve.size - 2].equityEur - (curve.last().contributionsEur - curve[curve.size - 2].contributionsEur) else null
        return AccountAnalytics(account, curve, bench, benchLabel, PerformanceAnalytics.maxDrawdown(curve), stats, trades, daily)
    }

    suspend fun etfAllocation(): EtfAllocation? {
        val snap = snapshot(AccountType.ETF)
        if (snap.positions.isEmpty()) return null
        val byInstrument = snap.positions.associate { it.position.instrumentId to (it.marketValueEur ?: it.position.costBasisEur) }
        val byFamily = mutableMapOf<String, Double>()
        for ((id, v) in byInstrument) {
            val fam = market.instrument(id)?.exposureFamily ?: "ALTRO"
            byFamily[fam] = (byFamily[fam] ?: 0.0) + v
        }
        return EtfAllocation(byInstrument.values.sum(), byFamily, byInstrument)
    }

    fun isTradable(inst: Instrument): Boolean = inst.assetClass == AssetClass.ETF || inst.assetClass == AssetClass.STOCK
}
