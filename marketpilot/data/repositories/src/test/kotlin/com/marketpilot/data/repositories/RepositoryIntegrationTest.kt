package com.marketpilot.data.repositories

import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.database.DecisionSnapshotEntity
import com.marketpilot.core.database.LedgerEntryEntity
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.ProviderOperationalState
import com.marketpilot.domain.papertrading.OrderSide
import com.marketpilot.domain.papertrading.OrderStatus
import com.marketpilot.domain.papertrading.OrderType
import com.marketpilot.domain.portfolio.AccountType
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Instant
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
class RepositoryIntegrationTest {

    @Test fun offlineRefreshAnalyzesCachedDataWithoutNetwork() = runBlocking {
        val env = TestEnv(online = false)
        env.seedMarket()
        val before = env.db.candleDao().count()
        val r = env.engine.refresh(RefreshTrigger.MANUAL) as RefreshOutcome.Done
        assertEquals("PARTIAL", r.status) // offline is never reported as a complete refresh
        assertEquals(0, env.requests)
        assertEquals(before, env.db.candleDao().count())
        val a = env.db.analysisDao().latestAssessment()!!.toView()
        assertEquals(LocalDate.of(2026, 10, 27), a.asOf)
        assertTrue(a.regime != MarketRegime.INSUFFICIENT_DATA, "regime ${a.regime} coverage ${a.coverage}")
        val scores = env.db.analysisDao().observeLatestStockScores().first()
        assertTrue(scores.isNotEmpty())
        assertTrue(env.db.decisionDao().snapshots().isNotEmpty())
        assertTrue(r.summary.steps.any { it.name == "Connettività" && it.status == "SKIPPED" })
    }

    @Test fun concurrentRefreshIsRejected() = runBlocking {
        val env = TestEnv(online = false)
        env.seedMarket()
        val first = async(start = CoroutineStart.UNDISPATCHED) { env.engine.refresh(RefreshTrigger.MANUAL) }
        val second = env.engine.refresh(RefreshTrigger.MANUAL)
        assertEquals(RefreshOutcome.AlreadyRunning, second)
        assertTrue(first.await() is RefreshOutcome.Done)
    }

    @Test fun providerFailureKeepsCachedDataAndIsReported() = runBlocking {
        val env = TestEnv(online = true, failAllRequests = true)
        env.seedMarket()
        val before = env.db.candleDao().series(InstrumentCatalog.SPY).map { it.close }
        val r = env.engine.refresh(RefreshTrigger.MANUAL) as RefreshOutcome.Done
        assertEquals("PARTIAL", r.status)
        assertTrue(env.requests > 0)
        assertTrue(r.summary.failedInstruments.isNotEmpty())
        assertEquals(before, env.db.candleDao().series(InstrumentCatalog.SPY).map { it.close })
        val yahoo = env.db.providerStatusDao().byId("yahoo")!!
        assertEquals(ProviderOperationalState.DEGRADED.name, yahoo.state)
        assertTrue(yahoo.lastError!!.contains("503"))
        // Analyses still run on the cached bars and keep their original session date.
        assertEquals(LocalDate.of(2026, 10, 27), env.db.analysisDao().latestAssessment()!!.toView().asOf)
    }

    @Test fun paperOrderLifecycleThroughRepositories() = runBlocking {
        val env = TestEnv(online = false)
        env.seedMarket()
        assertEquals(null, env.portfolio.deposit(AccountType.TRADING, 10_000.0))
        val aapl = env.market.instrument(InstrumentCatalog.stockId("AAPL"))!!
        val last = env.market.candles(aapl.id).last().close
        // 08:00 New York on Wed 28 Oct: first eligible session is today's (not yet completed).
        val ticket = env.portfolio.ticketFor(aapl, AccountType.TRADING).copy(type = OrderType.LIMIT, quantity = 5, limitPrice = last * 1.05, stopLoss = last * 0.95, takeProfit = last * 1.15)
        val p = env.portfolio.place(ticket)
        assertEquals(OrderStatus.NEW, p.order.status, p.preview.errors.joinToString())
        assertTrue(env.portfolio.snapshot(AccountType.TRADING).reservedEur > 0)
        env.portfolio.reconcile()
        assertTrue(env.portfolio.orders().first { it.id == p.order.id }.status.isActive) // no completed session yet: nothing to evaluate
        // A new completed session arrives: the order fills at that open, never on an earlier bar.
        val d = LocalDate.of(2026, 10, 28)
        env.db.candleDao().upsert(listOf(com.marketpilot.core.database.CandleEntity(aapl.id, d.toEpochDay(), last, last * 1.01, last * 0.995, last * 1.005, null, 5_000_000, "test", 0)))
        env.clock.instant = Instant.parse("2026-10-29T12:00:00Z")
        val rec = env.portfolio.reconcile()
        assertEquals(1, rec.fills.size)
        assertEquals(d, rec.fills.single().session)
        val snap = env.portfolio.snapshot(AccountType.TRADING)
        assertEquals(5.0, snap.positions.single().position.quantity)
        assertEquals(0.0, snap.reservedEur)
        // Bracket children were created; cancelling the stop leaves the OCO target active.
        val children = env.portfolio.orders().filter { it.parentId == p.order.id }
        assertEquals(2, children.size)
        assertTrue(env.portfolio.cancel(children.first().id))
        assertEquals(OrderStatus.CANCELLED, env.portfolio.orders().first { it.id == children.first().id }.status)
        // A second order that cannot be funded is recorded as REJECTED (auditable), not silently dropped.
        val big = env.portfolio.place(ticket.copy(quantity = 10_000))
        assertEquals(OrderStatus.REJECTED, big.order.status)
        val pending = env.portfolio.place(ticket.copy(quantity = 1))
        assertTrue(env.portfolio.cancel(pending.order.id))
        assertEquals(env.portfolio.snapshot(AccountType.TRADING).cashEur, env.portfolio.snapshot(AccountType.TRADING).availableCashEur)
        // Closed/open position tables are materialized from the ledger.
        assertEquals(1, env.db.paperTradingDao().observeOpenPositions().first().size)
    }

    @Test fun transfersAreAuditableAndCannotOverdraw() = runBlocking {
        val env = TestEnv()
        env.portfolio.deposit(AccountType.ETF, 1_000.0)
        assertNotNull(env.portfolio.transfer(AccountType.ETF, AccountType.TRADING, 5_000.0))
        assertEquals(null, env.portfolio.transfer(AccountType.ETF, AccountType.TRADING, 400.0))
        val ledger = env.portfolio.ledger()
        assertEquals(2, ledger.count { it.transferId != null })
        assertEquals(600.0, env.portfolio.snapshot(AccountType.ETF).cashEur)
        assertEquals(400.0, env.portfolio.snapshot(AccountType.TRADING).cashEur)
    }

    @Test fun ledgerIsAppendOnlyAndSnapshotsImmutable() = runBlocking {
        val env = TestEnv()
        val e = LedgerEntryEntity("x", "ETF", "DEPOSIT", 10.0, 1, 1, null, null, null, "EUR", null, null, null, null)
        env.db.ledgerDao().append(listOf(e))
        assertFailsWith<Exception> { env.db.ledgerDao().append(listOf(e.copy(amountEur = 999.0))) }
        assertEquals(10.0, env.db.ledgerDao().all().single().amountEur)
        val s = DecisionSnapshotEntity("s1", 1, 1, "A", "STOCK", "WATCH", 60.0, "[]", 1.0, 1.0, "{}", 1.0, null, null, null, "NEUTRAL", "m", "s")
        env.db.decisionDao().insertSnapshots(listOf(s))
        val ids = env.db.decisionDao().insertSnapshots(listOf(s.copy(score = 99.0)))
        assertEquals(listOf(-1L), ids)
        assertEquals(60.0, env.db.decisionDao().snapshots().single().score)
    }

    @Test fun encryptedExportImportRoundTrip() = runBlocking {
        val a = TestEnv()
        a.portfolio.deposit(AccountType.TRADING, 2_500.0)
        a.market.addToWatchlist(InstrumentCatalog.VWCE)
        a.settings.update { it.copy(monthlyEtfContribution = 250.0) }
        val bytes = a.export.export("password-123".toCharArray())
        assertTrue(a.export.isEncrypted(bytes))
        val b = TestEnv()
        assertFailsWith<Exception> { b.export.import(bytes, "wrong-password".toCharArray()) }
        val report = b.export.import(bytes, "password-123".toCharArray())
        assertEquals(1, report.ledger)
        assertEquals(2_500.0, b.portfolio.snapshot(AccountType.TRADING).cashEur)
        assertEquals(250.0, b.settings.current().monthlyEtfContribution)
        assertEquals(listOf(InstrumentCatalog.VWCE), b.market.watchlist())
    }

    @Test fun alertsFireOncePerThreshold() = runBlocking {
        val env = TestEnv()
        env.seedMarket()
        env.settings.update { it.copy(notifications = it.notifications.copy(alertsEnabled = true)) }
        val spyClose = env.market.candles(InstrumentCatalog.SPY).last().close
        env.alerts.add(AlertType.PRICE_ABOVE, InstrumentCatalog.SPY, spyClose * 0.9)
        assertEquals(1, env.alerts.evaluate(0))
        assertEquals(0, env.alerts.evaluate(0))
        assertTrue(env.notifier.messages.single().contains("SPY"))
    }

    @Test fun decisionTrackerEvaluatesWithSessionsAndBenchmarks() = runBlocking {
        val env = TestEnv(online = false, start = Instant.parse("2026-09-01T23:00:00Z"))
        env.seedMarket(end = LocalDate.of(2026, 9, 1))
        env.engine.refresh(RefreshTrigger.MANUAL)
        val snaps = env.db.decisionDao().snapshots()
        assertTrue(snaps.isNotEmpty())
        // 40 more sessions of data arrive later.
        env.seedMarket(end = LocalDate.of(2026, 10, 27))
        env.clock.instant = Instant.parse("2026-10-28T12:00:00Z")
        assertTrue(env.decisions.evaluatePending() > 0)
        val ev = env.db.decisionDao().evaluations()
        assertTrue(ev.any { it.horizonSessions == 20 })
        assertTrue(ev.none { it.horizonSessions == 60 }) // not enough sessions yet: never guessed
    }
}
