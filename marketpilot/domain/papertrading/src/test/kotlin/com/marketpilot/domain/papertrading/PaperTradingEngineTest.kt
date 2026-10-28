package com.marketpilot.domain.papertrading

import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.Candle
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.portfolio.CashMovements
import com.marketpilot.domain.portfolio.CashResult
import com.marketpilot.domain.portfolio.LedgerEntry
import com.marketpilot.domain.portfolio.LedgerKind
import com.marketpilot.domain.portfolio.PortfolioCalculator
import com.marketpilot.domain.risk.FeeModel
import com.marketpilot.domain.risk.RiskParameters
import java.time.Instant
import java.time.LocalDate
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class PaperTradingEngineTest {
    private val id = "AAPL:US"
    // Mon 2026-03-02 15:00 New York: the order is created while the 03-02 session is running.
    private val created = Instant.parse("2026-03-02T20:00:00Z")
    // Wed 2026-03-11 morning: last completed session is Tue 2026-03-10.
    private val now = Instant.parse("2026-03-11T12:00:00Z")
    private val fx = FxLookup { ccy, _ -> if (ccy == "USD") 1.10 else null }
    private val noCosts = FeeModel(halfSpread = 0.0, slippage = 0.0, stopExtraSlippage = 0.0)
    private var seq = 0
    private val ids = { "id-${seq++}" }

    private fun bar(date: String, o: Double, h: Double, l: Double, c: Double, v: Long? = 1_000_000) =
        Candle(id, LocalDate.parse(date), o, h, l, c, null, v)

    private fun deposit(eur: Double, account: AccountType = AccountType.TRADING): List<LedgerEntry> =
        (CashMovements.deposit(account, eur, LocalDate.parse("2026-03-01"), created.minusSeconds(86_400)) as CashResult.Ok).entries

    private fun order(
        side: OrderSide = OrderSide.BUY, type: OrderType = OrderType.MARKET, qty: Int = 10,
        limit: Double? = null, stop: Double? = null, sl: Double? = null, tp: Double? = null,
        tif: TimeInForce = TimeInForce.GTC, reserved: Double = 0.0, expires: LocalDate? = null,
    ) = PaperOrder(
        id = "o-${seq++}", account = AccountType.TRADING, instrumentId = id, exchange = "US", currency = "USD",
        side = side, type = type, quantity = qty, limitPrice = limit, stopPrice = stop, timeInForce = tif, expiresOn = expires,
        createdAt = created, firstEligibleSession = OrderPlacement.firstEligibleSession("US", created),
        bracketStopLoss = sl, bracketTakeProfit = tp, reservedCashEur = reserved,
        role = if (side == OrderSide.BUY) OrderRole.ENTRY else OrderRole.EXIT,
    )

    private fun engine(fees: FeeModel = noCosts, policy: SameBarExitPolicy = SameBarExitPolicy.CONSERVATIVE, participation: Double? = null) =
        PaperTradingEngine(SimulationConfig(fees = fees, sameBarExitPolicy = policy, maxParticipationOfBarVolume = participation))

    private fun close(a: Double, b: Double, tol: Double = 1e-6) = assertTrue(abs(a - b) <= tol, "expected $a got $b")

    @Test fun firstEligibleSessionNeverUsesStartedBar() {
        assertEquals(LocalDate.parse("2026-03-03"), OrderPlacement.firstEligibleSession("US", created))
        // Before the open (08:00 NY) the same day is eligible.
        assertEquals(LocalDate.parse("2026-03-02"), OrderPlacement.firstEligibleSession("US", Instant.parse("2026-03-02T13:00:00Z")))
        // Saturday -> Monday
        assertEquals(LocalDate.parse("2026-03-09"), OrderPlacement.firstEligibleSession("US", Instant.parse("2026-03-07T15:00:00Z")))
    }

    @Test fun marketOrderFillsAtNextOpenWithoutLookAhead() {
        val bars = listOf(
            bar("2026-03-02", 1.0, 1.0, 1.0, 1.0), // creation day: must never be used
            bar("2026-03-03", 100.0, 105.0, 99.0, 104.0),
        )
        val r = engine(FeeModel(halfSpread = 0.001, slippage = 0.001, stopExtraSlippage = 0.0)).evaluate(listOf(order(reserved = 1000.0)), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        val fill = r.fills.single()
        assertEquals(LocalDate.parse("2026-03-03"), fill.session)
        close(100.0 * 1.002, fill.priceCcy)
        assertEquals(OrderStatus.FILLED, r.orders.single().status)
        close(10 * 100.2 / 1.10, fill.grossEur)
    }

    @Test fun limitBuyRequiresPriceThroughLimitAndGapsFillAtOpen() {
        val e = engine()
        val touchOnly = listOf(bar("2026-03-03", 102.0, 103.0, 100.0, 101.0))
        assertTrue(e.evaluate(listOf(order(type = OrderType.LIMIT, limit = 100.0)), deposit(5000.0), mapOf(id to touchOnly), fx, now, ids).fills.isEmpty())
        val through = listOf(bar("2026-03-03", 102.0, 103.0, 99.5, 101.0))
        close(100.0, e.evaluate(listOf(order(type = OrderType.LIMIT, limit = 100.0)), deposit(5000.0), mapOf(id to through), fx, now, ids).fills.single().priceCcy)
        val gapDown = listOf(bar("2026-03-03", 97.0, 98.0, 96.0, 97.5))
        close(97.0, e.evaluate(listOf(order(type = OrderType.LIMIT, limit = 100.0)), deposit(5000.0), mapOf(id to gapDown), fx, now, ids).fills.single().priceCcy)
    }

    @Test fun stopLossGapFillsAtOpenNotAtStop() {
        val ledger = deposit(5000.0) + buyEntry(10, 100.0)
        val sell = order(side = OrderSide.SELL, type = OrderType.STOP, stop = 95.0)
        val bars = listOf(bar("2026-03-03", 90.0, 92.0, 88.0, 91.0))
        val fill = engine().evaluate(listOf(sell), ledger, mapOf(id to bars), fx, now, ids).fills.single()
        close(90.0, fill.priceCcy)
        assertTrue(fill.basis.contains("Gap"))
    }

    @Test fun ocoBothCrossedUsesStopAndFlagsAmbiguity() {
        val ledger = deposit(5000.0) + buyEntry(10, 100.0)
        val group = "g1"
        val stop = order(side = OrderSide.SELL, type = OrderType.STOP, stop = 95.0).copy(role = OrderRole.STOP_LOSS, ocoGroupId = group)
        val tp = order(side = OrderSide.SELL, type = OrderType.LIMIT, limit = 110.0).copy(role = OrderRole.TAKE_PROFIT, ocoGroupId = group)
        val bars = listOf(bar("2026-03-03", 100.0, 112.0, 94.0, 105.0))
        val r = engine().evaluate(listOf(stop, tp), ledger, mapOf(id to bars), fx, now, ids)
        val fill = r.fills.single()
        assertEquals(stop.id, fill.orderId)
        assertTrue(fill.ambiguous)
        close(95.0, fill.priceCcy)
        assertEquals(OrderStatus.CANCELLED, r.orders.first { it.id == tp.id }.status)
    }

    @Test fun ocoGapAboveTargetTakesTargetAtOpen() {
        val ledger = deposit(5000.0) + buyEntry(10, 100.0)
        val stop = order(side = OrderSide.SELL, type = OrderType.STOP, stop = 95.0).copy(role = OrderRole.STOP_LOSS, ocoGroupId = "g")
        val tp = order(side = OrderSide.SELL, type = OrderType.LIMIT, limit = 110.0).copy(role = OrderRole.TAKE_PROFIT, ocoGroupId = "g")
        val bars = listOf(bar("2026-03-03", 115.0, 116.0, 94.0, 100.0))
        val fill = engine().evaluate(listOf(stop, tp), ledger, mapOf(id to bars), fx, now, ids).fills.single()
        assertEquals(tp.id, fill.orderId)
        assertFalse(fill.ambiguous)
        close(115.0, fill.priceCcy)
    }

    @Test fun bracketSameBarStopIsConservative() {
        val bars = listOf(bar("2026-03-03", 100.0, 120.0, 90.0, 110.0), bar("2026-03-04", 110.0, 111.0, 109.0, 110.0))
        val entry = order(sl = 95.0, tp = 115.0, reserved = 1000.0)
        val r = engine().evaluate(listOf(entry), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(2, r.fills.size)
        val exit = r.fills[1]
        assertEquals(OrderSide.SELL, exit.side)
        close(95.0, exit.priceCcy)
        assertTrue(exit.ambiguous)
        // The take profit was crossed too but is never credited on the entry bar.
        assertTrue(r.orders.none { it.role == OrderRole.TAKE_PROFIT && it.status == OrderStatus.FILLED })

        val next = engine(policy = SameBarExitPolicy.NEXT_SESSION).evaluate(listOf(entry.copy(id = "x")), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(1, next.fills.size)
        assertEquals(2, next.orders.count { it.status == OrderStatus.PENDING })
    }

    @Test fun rejectsWhenCashIsInsufficientAtFill() {
        val bars = listOf(bar("2026-03-03", 200.0, 201.0, 199.0, 200.0))
        val r = engine().evaluate(listOf(order(qty = 10)), deposit(1000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(OrderStatus.REJECTED, r.orders.single().status)
        assertTrue(r.fills.isEmpty())
    }

    @Test fun noShortSelling() {
        val bars = listOf(bar("2026-03-03", 100.0, 101.0, 99.0, 100.0))
        val r = engine().evaluate(listOf(order(side = OrderSide.SELL)), deposit(1000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(OrderStatus.REJECTED, r.orders.single().status)
    }

    @Test fun dayOrderExpiresAndGtcExpiryIsHonoured() {
        val bars = listOf(bar("2026-03-03", 102.0, 103.0, 101.0, 102.0), bar("2026-03-04", 99.0, 100.0, 98.0, 99.0))
        val day = engine().evaluate(listOf(order(type = OrderType.LIMIT, limit = 100.0, tif = TimeInForce.DAY)), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(OrderStatus.EXPIRED, day.orders.single().status)
        assertTrue(day.fills.isEmpty())
        val gtc = engine().evaluate(listOf(order(type = OrderType.LIMIT, limit = 100.0, expires = LocalDate.parse("2026-03-03"))), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(OrderStatus.EXPIRED, gtc.orders.single().status)
    }

    @Test fun missingBarBlocksInsteadOfSkipping() {
        // 03-03 missing: the engine must not jump to 03-04.
        val bars = listOf(bar("2026-03-04", 50.0, 51.0, 49.0, 50.0))
        val r = engine().evaluate(listOf(order()), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertTrue(r.fills.isEmpty())
        assertEquals(OrderStatus.PENDING, r.orders.single().status)
        assertTrue(r.orders.single().statusReason!!.contains("2026-03-03"))
    }

    @Test fun incompleteSessionIsNotUsed() {
        val during = Instant.parse("2026-03-03T16:00:00Z") // 11:00 NY on 03-03
        val bars = listOf(bar("2026-03-03", 100.0, 101.0, 99.0, 100.0))
        val r = engine().evaluate(listOf(order()), deposit(5000.0), mapOf(id to bars), fx, during, ids)
        assertTrue(r.fills.isEmpty())
    }

    @Test fun explicitPartialFillModel() {
        val bars = listOf(bar("2026-03-03", 10.0, 10.0, 10.0, 10.0, v = 50), bar("2026-03-04", 10.0, 10.0, 10.0, 10.0, v = 1000))
        val r = engine(participation = 0.10).evaluate(listOf(order(qty = 20, reserved = 200.0)), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        assertEquals(listOf(5, 15), r.fills.map { it.quantity })
        assertEquals(OrderStatus.FILLED, r.orders.single().status)
    }

    @Test fun feesAndFxCostsAreBookedAndCashReconciles() {
        val fees = FeeModel(fixedPerOrder = 2.0, percentPerOrder = 0.001, fxConversionCost = 0.0025, halfSpread = 0.0, slippage = 0.0, stopExtraSlippage = 0.0)
        val bars = listOf(bar("2026-03-03", 110.0, 111.0, 109.0, 110.0))
        val r = engine(fees).evaluate(listOf(order(qty = 10, reserved = 1100.0)), deposit(5000.0), mapOf(id to bars), fx, now, ids)
        val fill = r.fills.single()
        close(1000.0, fill.grossEur)
        close(3.0, fill.commissionEur)
        close(2.5, fill.fxCostEur)
        val ledger = deposit(5000.0) + r.ledger
        close(5000.0 - 1000.0 - 3.0 - 2.5, PortfolioCalculator.cash(ledger, AccountType.TRADING), 0.011)
        assertEquals(setOf(LedgerKind.BUY, LedgerKind.FEE, LedgerKind.FX_COST), r.ledger.map { it.kind }.toSet())
        val pos = PortfolioCalculator.positions(ledger, AccountType.TRADING).single()
        close(1005.5, pos.costBasisEur, 0.011)
    }

    @Test fun stopLimitTriggeredButNotFillableStaysPending() {
        val ledger = deposit(5000.0) + buyEntry(10, 100.0)
        // Sell stop-limit: stop 95, limit 96 (limit above stop: needs a rebound after the trigger).
        val o = order(side = OrderSide.SELL, type = OrderType.STOP_LIMIT, stop = 95.0, limit = 96.0)
        val bars = listOf(bar("2026-03-03", 100.0, 100.5, 94.0, 95.5), bar("2026-03-04", 95.5, 97.0, 95.0, 96.5))
        val r = engine().evaluate(listOf(o), ledger, mapOf(id to bars), fx, now, ids)
        val fill = r.fills.single()
        assertEquals(LocalDate.parse("2026-03-04"), fill.session) // not on the trigger bar
        close(96.0, fill.priceCcy)
    }

    @Test fun placementValidatesCashSharesAndAccountType() {
        val ctxLedger = deposit(1000.0)
        val snap = PortfolioCalculator.snapshot(ctxLedger, AccountType.TRADING, emptyMap())
        val ctx = PlacementContext(snap, emptyList(), lastPriceCcy = 100.0, eurToCcy = 1.10, risk = RiskParameters(), config = SimulationConfig(fees = noCosts), now = created)
        fun ticket(qty: Int, side: OrderSide = OrderSide.BUY, account: AccountType = AccountType.TRADING, cls: AssetClass = AssetClass.STOCK) =
            OrderTicket(account, id, "US", "USD", cls, false, side, OrderType.MARKET, qty)
        // 1 share * 100 * 1.03 / 1.10 = 93.6 EUR -> exposure 9.4% < 15%
        assertTrue(OrderPlacement.preview(ticket(1), ctx).isValid)
        assertTrue(OrderPlacement.preview(ticket(20), ctx).errors.any { it.contains("Liquidità") })
        assertTrue(OrderPlacement.preview(ticket(5, OrderSide.SELL), ctx).errors.any { it.contains("scoperto") })
        assertTrue(OrderPlacement.preview(ticket(1, account = AccountType.ETF), ctx).errors.any { it.contains("solo ETF") })
        val rejected = OrderPlacement.place(ticket(20), ctx, "r1").order
        assertEquals(OrderStatus.REJECTED, rejected.status)
        assertEquals(0.0, rejected.reservedCashEur)
    }

    @Test fun reservedCashIsNotDoubleCounted() {
        val ledger = deposit(1000.0)
        val pending = order(reserved = 600.0)
        val snap = PortfolioCalculator.snapshot(ledger, AccountType.TRADING, emptyMap(), OrderPlacement.reservedCash(listOf(pending), AccountType.TRADING))
        close(400.0, snap.availableCashEur)
        close(1000.0, snap.cashEur)
        val res = CashMovements.transfer(AccountType.TRADING, AccountType.ETF, 500.0, snap.availableCashEur, LocalDate.parse("2026-03-02"), created)
        assertTrue(res is CashResult.Rejected)
    }

    @Test fun cancellingEntryCancelsChildren() {
        val entry = order().copy(status = OrderStatus.PENDING)
        val child = order(side = OrderSide.SELL, type = OrderType.STOP, stop = 90.0).copy(parentId = entry.id, role = OrderRole.STOP_LOSS, status = OrderStatus.PENDING)
        val cancelled = OrderPlacement.cancel(entry, listOf(entry, child))
        assertEquals(2, cancelled.size)
        assertTrue(cancelled.all { it.status == OrderStatus.CANCELLED })
        assertTrue(OrderPlacement.cancel(entry.copy(status = OrderStatus.FILLED), emptyList()).isEmpty())
    }

    private fun buyEntry(qty: Int, priceUsd: Double): List<LedgerEntry> = listOf(
        LedgerEntry("b-${seq++}", AccountType.TRADING, LedgerKind.BUY, -qty * priceUsd / 1.10, LocalDate.parse("2026-02-27"), created.minusSeconds(400_000), id, qty.toDouble(), priceUsd, "USD", 1.10, "f0"),
    )
}
