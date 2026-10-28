package com.marketpilot.domain.portfolio

import java.time.Instant
import java.time.LocalDate
import java.util.UUID

sealed interface CashResult {
    data class Ok(val entries: List<LedgerEntry>) : CashResult
    data class Rejected(val reason: String) : CashResult
}

/** Creates auditable cash movements. Transfers between accounts are explicit and paired. */
object CashMovements {
    fun deposit(account: AccountType, amountEur: Double, date: LocalDate, now: Instant, note: String? = null): CashResult {
        if (amountEur <= 0 || amountEur.isNaN()) return CashResult.Rejected("L'importo deve essere positivo.")
        return CashResult.Ok(listOf(LedgerEntry(UUID.randomUUID().toString(), account, LedgerKind.DEPOSIT, PortfolioCalculator.round2(amountEur), date, now, note = note)))
    }

    fun withdraw(account: AccountType, amountEur: Double, availableEur: Double, date: LocalDate, now: Instant, note: String? = null): CashResult {
        if (amountEur <= 0 || amountEur.isNaN()) return CashResult.Rejected("L'importo deve essere positivo.")
        if (amountEur > availableEur + 1e-9) return CashResult.Rejected("Liquidità disponibile insufficiente (${"%.2f".format(availableEur)} €).")
        return CashResult.Ok(listOf(LedgerEntry(UUID.randomUUID().toString(), account, LedgerKind.WITHDRAWAL, -PortfolioCalculator.round2(amountEur), date, now, note = note)))
    }

    /** [availableFromEur] must already exclude cash reserved by pending orders. */
    fun transfer(from: AccountType, to: AccountType, amountEur: Double, availableFromEur: Double, date: LocalDate, now: Instant, note: String? = null): CashResult {
        if (from == to) return CashResult.Rejected("Conto di origine e destinazione coincidono.")
        if (amountEur <= 0 || amountEur.isNaN()) return CashResult.Rejected("L'importo deve essere positivo.")
        if (amountEur > availableFromEur + 1e-9) return CashResult.Rejected("Liquidità disponibile insufficiente su ${from.label} (${"%.2f".format(availableFromEur)} €).")
        val tid = UUID.randomUUID().toString()
        val amt = PortfolioCalculator.round2(amountEur)
        return CashResult.Ok(
            listOf(
                LedgerEntry(UUID.randomUUID().toString(), from, LedgerKind.TRANSFER_OUT, -amt, date, now, transferId = tid, note = note ?: "Verso ${to.label}"),
                LedgerEntry(UUID.randomUUID().toString(), to, LedgerKind.TRANSFER_IN, amt, date, now, transferId = tid, note = note ?: "Da ${from.label}"),
            ),
        )
    }

    fun dividend(account: AccountType, instrumentId: String, amountEur: Double, date: LocalDate, now: Instant): CashResult {
        if (amountEur <= 0) return CashResult.Rejected("Il dividendo deve essere positivo.")
        return CashResult.Ok(listOf(LedgerEntry(UUID.randomUUID().toString(), account, LedgerKind.DIVIDEND, PortfolioCalculator.round2(amountEur), date, now, instrumentId = instrumentId)))
    }
}
