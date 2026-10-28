package com.marketpilot.domain.papertrading

import com.marketpilot.core.common.TradingCalendar
import com.marketpilot.core.model.Candle
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.portfolio.LedgerEntry
import com.marketpilot.domain.portfolio.LedgerKind
import com.marketpilot.domain.portfolio.PortfolioCalculator
import java.time.LocalDate

data class ClosedTrade(
    val instrumentId: String,
    val account: AccountType,
    val entryDate: LocalDate?,
    val exitDate: LocalDate,
    val quantity: Double,
    val costEur: Double,
    val proceedsEur: Double,
) {
    val pnlEur: Double get() = proceedsEur - costEur
    val returnPct: Double get() = if (costEur > 0) pnlEur / costEur else 0.0
}

data class TradeStats(
    val trades: Int,
    val winRate: Double?,
    val profitFactor: Double?,
    val expectancyEur: Double?,
    val averageWinEur: Double?,
    val averageLossEur: Double?,
    val grossProfitEur: Double,
    val grossLossEur: Double,
)

data class EquityPoint(val date: LocalDate, val equityEur: Double, val cashEur: Double, val investedEur: Double, val contributionsEur: Double)

object PerformanceAnalytics {

    /** Every sell is a closed trade (partial exits are separate records), valued at average cost incl. costs. */
    fun closedTrades(ledger: List<LedgerEntry>, account: AccountType): List<ClosedTrade> {
        val acct = ledger.filter { it.account == account }.sortedWith(compareBy({ it.sessionDate }, { it.createdAt }))
        val costs = acct.filter { it.kind == LedgerKind.FEE || it.kind == LedgerKind.FX_COST }.groupBy { it.referenceId }
            .mapValues { e -> -e.value.sumOf { it.amountEur } }
        data class Acc(var qty: Double = 0.0, var cost: Double = 0.0, var opened: LocalDate? = null)
        val book = mutableMapOf<String, Acc>()
        val out = mutableListOf<ClosedTrade>()
        for (e in acct) {
            val id = e.instrumentId ?: continue
            val q = e.quantity ?: continue
            val a = book.getOrPut(id) { Acc() }
            val extra = costs[e.referenceId] ?: 0.0
            if (e.kind == LedgerKind.BUY) {
                if (a.qty <= 1e-9) a.opened = e.sessionDate
                a.qty += q; a.cost += -e.amountEur + extra
            } else if (e.kind == LedgerKind.SELL && a.qty > 0) {
                val sold = minOf(-q, a.qty)
                val avg = a.cost / a.qty
                out += ClosedTrade(id, account, a.opened, e.sessionDate, sold, avg * sold, e.amountEur - extra)
                a.cost -= avg * sold; a.qty -= sold
                if (a.qty <= 1e-9) { a.qty = 0.0; a.cost = 0.0 }
            }
        }
        return out
    }

    fun stats(trades: List<ClosedTrade>): TradeStats {
        val wins = trades.filter { it.pnlEur > 0 }
        val losses = trades.filter { it.pnlEur <= 0 }
        val gp = wins.sumOf { it.pnlEur }
        val gl = -losses.sumOf { it.pnlEur }
        return TradeStats(
            trades = trades.size,
            winRate = if (trades.isEmpty()) null else wins.size.toDouble() / trades.size,
            profitFactor = if (gl > 0) gp / gl else null,
            expectancyEur = if (trades.isEmpty()) null else trades.sumOf { it.pnlEur } / trades.size,
            averageWinEur = wins.takeIf { it.isNotEmpty() }?.map { it.pnlEur }?.average(),
            averageLossEur = losses.takeIf { it.isNotEmpty() }?.map { it.pnlEur }?.average(),
            grossProfitEur = gp,
            grossLossEur = gl,
        )
    }

    private fun closeOnOrBefore(series: List<Candle>, date: LocalDate): Double? {
        var lo = 0
        var hi = series.size - 1
        var ans: Double? = null
        while (lo <= hi) {
            val mid = (lo + hi) / 2
            if (!series[mid].date.isAfter(date)) { ans = series[mid].close; lo = mid + 1 } else hi = mid - 1
        }
        return ans
    }

    /** Daily equity curve over trading sessions; positions are valued at the session close (latest available). */
    fun equityCurve(
        ledger: List<LedgerEntry>,
        account: AccountType,
        candles: Map<String, List<Candle>>,
        currencies: Map<String, String>,
        fx: FxLookup,
        from: LocalDate,
        to: LocalDate,
        calendar: TradingCalendar,
    ): List<EquityPoint> {
        val acct = ledger.filter { it.account == account }
        if (acct.isEmpty() || from.isAfter(to)) return emptyList()
        val sorted = candles.mapValues { it.value.sortedBy { c -> c.date } }
        val out = mutableListOf<EquityPoint>()
        var d = from
        while (!d.isAfter(to)) {
            if (calendar.isTradingDay(d)) {
                val upTo = acct.filter { !it.sessionDate.isAfter(d) }
                val cash = PortfolioCalculator.cash(upTo, account)
                val invested = PortfolioCalculator.positions(upTo, account).filter { it.quantity > 0 }.sumOf { p ->
                    val ccy = currencies[p.instrumentId] ?: p.currency
                    val close = sorted[p.instrumentId]?.let { closeOnOrBefore(it, d) }
                    val rate = if (ccy == "EUR") 1.0 else fx.eurTo(ccy, d)
                    if (close != null && rate != null) p.quantity * close / rate else p.costBasisEur
                }
                out += EquityPoint(d, cash + invested, cash, invested, PortfolioCalculator.netContributions(upTo, account))
            }
            d = d.plusDays(1)
        }
        return out
    }

    /** Same external cash flows invested in a benchmark at each flow date's close (money-weighted comparison). */
    fun benchmarkCurve(
        curve: List<EquityPoint>,
        benchmark: List<Candle>,
        benchmarkCurrency: String,
        fx: FxLookup,
    ): List<EquityPoint> {
        val series = benchmark.sortedBy { it.date }
        var units = 0.0
        var lastContrib = 0.0
        return curve.mapNotNull { p ->
            val close = closeOnOrBefore(series, p.date) ?: return@mapNotNull null
            val rate = if (benchmarkCurrency == "EUR") 1.0 else fx.eurTo(benchmarkCurrency, p.date) ?: return@mapNotNull null
            val priceEur = close / rate
            val flow = p.contributionsEur - lastContrib
            if (flow != 0.0) units += flow / priceEur
            lastContrib = p.contributionsEur
            EquityPoint(p.date, units * priceEur, 0.0, units * priceEur, p.contributionsEur)
        }
    }

    /** Maximum drawdown of a curve, as a negative fraction; flows are not removed (use with care on small accounts). */
    fun maxDrawdown(curve: List<EquityPoint>): Double? {
        if (curve.size < 2) return null
        var peak = curve.first().equityEur
        var dd = 0.0
        for (p in curve) {
            if (p.equityEur > peak) peak = p.equityEur
            if (peak > 0) dd = minOf(dd, p.equityEur / peak - 1)
        }
        return dd
    }
}
