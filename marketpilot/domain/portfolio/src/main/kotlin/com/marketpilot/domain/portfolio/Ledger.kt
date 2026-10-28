package com.marketpilot.domain.portfolio

import java.time.Instant
import java.time.LocalDate

enum class AccountType(val label: String) { ETF("Capitale ETF"), TRADING("Capitale Trading") }

enum class LedgerKind(val label: String) {
    DEPOSIT("Versamento"),
    WITHDRAWAL("Prelievo"),
    TRANSFER_IN("Trasferimento in entrata"),
    TRANSFER_OUT("Trasferimento in uscita"),
    BUY("Acquisto"),
    SELL("Vendita"),
    FEE("Commissione"),
    FX_COST("Costo di cambio"),
    DIVIDEND("Dividendo"),
}

/**
 * Append-only cash ledger entry. [amountEur] is signed: positive increases cash.
 * Cash balances are always derived from the ledger, never stored separately.
 */
data class LedgerEntry(
    val id: String,
    val account: AccountType,
    val kind: LedgerKind,
    val amountEur: Double,
    val sessionDate: LocalDate,
    val createdAt: Instant,
    val instrumentId: String? = null,
    /** Shares bought (positive) or sold (negative) for BUY/SELL entries. */
    val quantity: Double? = null,
    val priceCcy: Double? = null,
    val currency: String = "EUR",
    /** 1 EUR = fxRate units of [currency] used for the conversion. */
    val fxRate: Double? = null,
    val referenceId: String? = null,
    val transferId: String? = null,
    val note: String? = null,
)

data class Position(
    val account: AccountType,
    val instrumentId: String,
    val quantity: Double,
    val currency: String,
    /** Average cost per share in EUR including buy commissions and FX costs. */
    val avgCostEur: Double,
    /** Average purchase price in the instrument currency (excluding costs). */
    val avgPriceCcy: Double,
    val costBasisEur: Double,
    val realizedPnlEur: Double,
    val openedOn: LocalDate?,
)

data class PriceMark(val priceCcy: Double, val currency: String, val eurToCcy: Double, val date: LocalDate) {
    val priceEur: Double get() = priceCcy / eurToCcy
}

data class ValuedPosition(val position: Position, val mark: PriceMark?) {
    val marketValueEur: Double? get() = mark?.let { position.quantity * it.priceEur }
    val unrealizedPnlEur: Double? get() = marketValueEur?.let { it - position.costBasisEur }
    val unrealizedPnlPct: Double? get() = unrealizedPnlEur?.let { if (position.costBasisEur > 0) it / position.costBasisEur else null }
}

data class AccountSnapshot(
    val account: AccountType,
    val cashEur: Double,
    val reservedEur: Double,
    val positions: List<ValuedPosition>,
    val netContributionsEur: Double,
    val realizedPnlEur: Double,
    val feesEur: Double,
    val dividendsEur: Double,
    /** Positions without a price are excluded from equity and listed here. */
    val unpricedInstruments: List<String>,
) {
    val availableCashEur: Double get() = cashEur - reservedEur
    val investedValueEur: Double get() = positions.sumOf { it.marketValueEur ?: 0.0 }
    val equityEur: Double get() = cashEur + investedValueEur
    val unrealizedPnlEur: Double get() = positions.sumOf { it.unrealizedPnlEur ?: 0.0 }
    val totalReturnEur: Double get() = equityEur - netContributionsEur
    val totalReturnPct: Double? get() = if (netContributionsEur > 0) totalReturnEur / netContributionsEur else null
}

object PortfolioCalculator {
    /** Cash balance from the ledger (rounded to cents to avoid floating drift). */
    fun cash(entries: List<LedgerEntry>, account: AccountType): Double =
        round2(entries.filter { it.account == account }.sumOf { it.amountEur })

    fun netContributions(entries: List<LedgerEntry>, account: AccountType): Double = round2(
        entries.filter {
            it.account == account && it.kind in setOf(LedgerKind.DEPOSIT, LedgerKind.WITHDRAWAL, LedgerKind.TRANSFER_IN, LedgerKind.TRANSFER_OUT)
        }.sumOf { it.amountEur },
    )

    /** Average-cost positions. Fees/FX costs linked to a buy fill increase the cost basis; on sells they reduce proceeds. */
    fun positions(entries: List<LedgerEntry>, account: AccountType): List<Position> {
        val acct = entries.filter { it.account == account }.sortedWith(compareBy({ it.sessionDate }, { it.createdAt }))
        val costsByRef = acct.filter { it.kind == LedgerKind.FEE || it.kind == LedgerKind.FX_COST }
            .groupBy { it.referenceId }.mapValues { e -> -e.value.sumOf { it.amountEur } }
        data class Acc(var qty: Double = 0.0, var cost: Double = 0.0, var priceCost: Double = 0.0, var realized: Double = 0.0, var currency: String = "EUR", var opened: LocalDate? = null)
        val map = linkedMapOf<String, Acc>()
        for (e in acct) {
            val id = e.instrumentId ?: continue
            val q = e.quantity ?: continue
            val a = map.getOrPut(id) { Acc() }
            a.currency = e.currency
            val extra = costsByRef[e.referenceId] ?: 0.0
            when (e.kind) {
                LedgerKind.BUY -> {
                    if (a.qty <= 1e-9) a.opened = e.sessionDate
                    a.qty += q
                    a.cost += -e.amountEur + extra
                    a.priceCost += q * (e.priceCcy ?: 0.0)
                }
                LedgerKind.SELL -> {
                    val sold = -q
                    val avg = if (a.qty > 0) a.cost / a.qty else 0.0
                    val avgPrice = if (a.qty > 0) a.priceCost / a.qty else 0.0
                    a.realized += e.amountEur - extra - avg * sold
                    a.cost -= avg * sold
                    a.priceCost -= avgPrice * sold
                    a.qty -= sold
                    if (a.qty <= 1e-9) { a.qty = 0.0; a.cost = 0.0; a.priceCost = 0.0 }
                }
                else -> Unit
            }
        }
        return map.map { (id, a) ->
            Position(
                account, id, a.qty, a.currency,
                avgCostEur = if (a.qty > 0) a.cost / a.qty else 0.0,
                avgPriceCcy = if (a.qty > 0) a.priceCost / a.qty else 0.0,
                costBasisEur = round2(a.cost), realizedPnlEur = round2(a.realized), openedOn = if (a.qty > 0) a.opened else null,
            )
        }
    }

    fun snapshot(
        entries: List<LedgerEntry>,
        account: AccountType,
        marks: Map<String, PriceMark>,
        reservedEur: Double = 0.0,
    ): AccountSnapshot {
        val positions = positions(entries, account)
        val open = positions.filter { it.quantity > 0 }
        val acct = entries.filter { it.account == account }
        return AccountSnapshot(
            account = account,
            cashEur = cash(entries, account),
            reservedEur = round2(reservedEur),
            positions = open.map { ValuedPosition(it, marks[it.instrumentId]) },
            netContributionsEur = netContributions(entries, account),
            realizedPnlEur = round2(positions.sumOf { it.realizedPnlEur }),
            feesEur = round2(-acct.filter { it.kind == LedgerKind.FEE || it.kind == LedgerKind.FX_COST }.sumOf { it.amountEur }),
            dividendsEur = round2(acct.filter { it.kind == LedgerKind.DIVIDEND }.sumOf { it.amountEur }),
            unpricedInstruments = open.filter { marks[it.instrumentId] == null }.map { it.instrumentId },
        )
    }

    fun round2(x: Double): Double = Math.round(x * 100.0) / 100.0
}
