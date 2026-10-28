package com.marketpilot.domain.portfolio

import java.time.Instant
import java.time.LocalDate
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PortfolioTest {
    private val d = LocalDate.parse("2026-01-05")
    private val t = Instant.parse("2026-01-05T10:00:00Z")
    private fun ok(r: CashResult) = (r as CashResult.Ok).entries
    private fun close(a: Double, b: Double) = assertTrue(abs(a - b) < 0.011, "expected $a got $b")

    @Test fun accountsAreIndependentAndTransfersArePairedAndAuditable() {
        val l = ok(CashMovements.deposit(AccountType.ETF, 10_000.0, d, t)) + ok(CashMovements.deposit(AccountType.TRADING, 2_000.0, d, t))
        val tr = ok(CashMovements.transfer(AccountType.ETF, AccountType.TRADING, 1_500.0, PortfolioCalculator.cash(l, AccountType.ETF), d, t))
        assertEquals(2, tr.size)
        assertEquals(tr[0].transferId, tr[1].transferId)
        val all = l + tr
        close(8_500.0, PortfolioCalculator.cash(all, AccountType.ETF))
        close(3_500.0, PortfolioCalculator.cash(all, AccountType.TRADING))
        close(12_000.0, PortfolioCalculator.cash(all, AccountType.ETF) + PortfolioCalculator.cash(all, AccountType.TRADING))
        assertTrue(CashMovements.transfer(AccountType.ETF, AccountType.ETF, 1.0, 100.0, d, t) is CashResult.Rejected)
        assertTrue(CashMovements.withdraw(AccountType.TRADING, 5_000.0, 3_500.0, d, t) is CashResult.Rejected)
        assertTrue(CashMovements.deposit(AccountType.ETF, -5.0, d, t) is CashResult.Rejected)
    }

    @Test fun defaultCapitalIsZero() {
        val snap = PortfolioCalculator.snapshot(emptyList(), AccountType.TRADING, emptyMap())
        assertEquals(0.0, snap.equityEur)
        assertEquals(null, snap.totalReturnPct)
    }

    @Test fun averageCostRealizedAndUnrealizedPnl() {
        val l = ok(CashMovements.deposit(AccountType.TRADING, 10_000.0, d, t)) + listOf(
            LedgerEntry("1", AccountType.TRADING, LedgerKind.BUY, -1_000.0, d, t, "X", 10.0, 100.0, "EUR", 1.0, "f1"),
            LedgerEntry("2", AccountType.TRADING, LedgerKind.FEE, -2.0, d, t, "X", referenceId = "f1"),
            LedgerEntry("3", AccountType.TRADING, LedgerKind.BUY, -1_200.0, d.plusDays(1), t, "X", 10.0, 120.0, "EUR", 1.0, "f2"),
            LedgerEntry("4", AccountType.TRADING, LedgerKind.SELL, 1_300.0, d.plusDays(2), t, "X", -10.0, 130.0, "EUR", 1.0, "f3"),
            LedgerEntry("5", AccountType.TRADING, LedgerKind.FEE, -2.0, d.plusDays(2), t, "X", referenceId = "f3"),
        )
        val pos = PortfolioCalculator.positions(l, AccountType.TRADING).single()
        close(10.0, pos.quantity)
        close(110.1, pos.avgCostEur) // (1000+2+1200)/20
        close(1_300.0 - 2.0 - 1_101.0, pos.realizedPnlEur)
        val snap = PortfolioCalculator.snapshot(l, AccountType.TRADING, mapOf("X" to PriceMark(140.0, "EUR", 1.0, d.plusDays(2))))
        close(10_000.0 - 1_000.0 - 2.0 - 1_200.0 + 1_300.0 - 2.0, snap.cashEur)
        close(1_400.0 - 1_101.0, snap.unrealizedPnlEur)
        close(4.0, snap.feesEur)
        close(snap.cashEur + 1_400.0, snap.equityEur)
    }

    @Test fun usdPositionValuedInEur() {
        val l = ok(CashMovements.deposit(AccountType.TRADING, 1_000.0, d, t)) +
            LedgerEntry("1", AccountType.TRADING, LedgerKind.BUY, -500.0, d, t, "AAPL:US", 5.0, 110.0, "USD", 1.1, "f")
        val snap = PortfolioCalculator.snapshot(l, AccountType.TRADING, mapOf("AAPL:US" to PriceMark(121.0, "USD", 1.1, d)))
        close(550.0, snap.investedValueEur)
        close(50.0, snap.unrealizedPnlEur)
        val missing = PortfolioCalculator.snapshot(l, AccountType.TRADING, emptyMap())
        assertEquals(listOf("AAPL:US"), missing.unpricedInstruments)
    }
}
