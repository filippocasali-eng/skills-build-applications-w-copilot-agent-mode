package com.marketpilot.domain.papertrading

import com.marketpilot.domain.portfolio.AccountType
import java.time.Instant
import java.time.LocalDate

enum class OrderSide(val label: String) { BUY("Acquisto"), SELL("Vendita") }

enum class OrderType(val label: String) { MARKET("Mercato"), LIMIT("Limite"), STOP("Stop"), STOP_LIMIT("Stop-limite") }

enum class OrderStatus(val label: String) {
    NEW("Nuovo"),
    PENDING("In attesa"),
    PARTIALLY_FILLED("Parzialmente eseguito"),
    FILLED("Eseguito"),
    CANCELLED("Annullato"),
    EXPIRED("Scaduto"),
    REJECTED("Rifiutato"),
    ;

    val isActive: Boolean get() = this == NEW || this == PENDING || this == PARTIALLY_FILLED
}

enum class TimeInForce(val label: String) { DAY("Giornaliero"), GTC("Valido fino a revoca") }

enum class OrderRole(val label: String) { ENTRY("Ingresso"), EXIT("Uscita"), STOP_LOSS("Stop loss"), TAKE_PROFIT("Take profit") }

data class PaperOrder(
    val id: String,
    val account: AccountType,
    val instrumentId: String,
    val exchange: String,
    val currency: String,
    val side: OrderSide,
    val type: OrderType,
    val quantity: Int,
    val filledQuantity: Int = 0,
    val limitPrice: Double? = null,
    val stopPrice: Double? = null,
    val timeInForce: TimeInForce = TimeInForce.GTC,
    /** Optional last session on which a GTC order may fill. */
    val expiresOn: LocalDate? = null,
    val createdAt: Instant,
    /** First session whose opening auction happens after [createdAt]. Bars before it are never used. */
    val firstEligibleSession: LocalDate,
    val status: OrderStatus = OrderStatus.NEW,
    val role: OrderRole = OrderRole.ENTRY,
    val parentId: String? = null,
    val ocoGroupId: String? = null,
    val bracketStopLoss: Double? = null,
    val bracketTakeProfit: Double? = null,
    /** Stop-limit: the stop has been triggered and the order now behaves as a limit order. */
    val triggered: Boolean = false,
    val lastEvaluatedSession: LocalDate? = null,
    val statusReason: String? = null,
    /** Cash reserved in EUR for the unfilled part of a buy order. */
    val reservedCashEur: Double = 0.0,
    val note: String? = null,
) {
    val remainingQuantity: Int get() = quantity - filledQuantity
}

data class PaperFill(
    val id: String,
    val orderId: String,
    val account: AccountType,
    val instrumentId: String,
    val side: OrderSide,
    val session: LocalDate,
    val quantity: Int,
    val priceCcy: Double,
    val currency: String,
    val eurToCcy: Double,
    val grossEur: Double,
    val commissionEur: Double,
    val fxCostEur: Double,
    /** Human-readable explanation of how the price was derived from the daily bar. */
    val basis: String,
    /** True when the daily bar cannot tell the real intraday sequence; the conservative outcome was used. */
    val ambiguous: Boolean,
)

enum class SameBarExitPolicy(val label: String) {
    /** After an entry fill, a stop touched in the same bar is assumed hit; a target in the same bar is not credited. */
    CONSERVATIVE("Prudente: stop nello stesso giorno considerato colpito, target no"),
    /** Exit orders become active from the next session only. */
    NEXT_SESSION("Uscite attive dalla seduta successiva"),
}

data class SimulationConfig(
    val fees: com.marketpilot.domain.risk.FeeModel = com.marketpilot.domain.risk.FeeModel(),
    val sameBarExitPolicy: SameBarExitPolicy = SameBarExitPolicy.CONSERVATIVE,
    /** A limit fills intraday only if the low trades strictly below a buy limit (above a sell limit). */
    val limitRequiresPenetration: Boolean = true,
    /** Explicit partial-fill model: max share of a bar's volume a simulated order can take. Null disables it. */
    val maxParticipationOfBarVolume: Double? = 0.10,
    /** Extra buffer reserved for market buy orders against overnight gaps. */
    val marketOrderGapBuffer: Double = 0.03,
)
