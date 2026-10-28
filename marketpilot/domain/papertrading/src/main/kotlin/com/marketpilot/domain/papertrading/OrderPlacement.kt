package com.marketpilot.domain.papertrading

import com.marketpilot.core.common.Calendars
import com.marketpilot.core.model.AssetClass
import com.marketpilot.domain.portfolio.AccountSnapshot
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.risk.RiskParameters
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class OrderTicket(
    val account: AccountType,
    val instrumentId: String,
    val exchange: String,
    val currency: String,
    val assetClass: AssetClass,
    val isUcits: Boolean,
    val side: OrderSide,
    val type: OrderType,
    val quantity: Int,
    val limitPrice: Double? = null,
    val stopPrice: Double? = null,
    val timeInForce: TimeInForce = TimeInForce.GTC,
    val expiresOn: LocalDate? = null,
    val stopLoss: Double? = null,
    val takeProfit: Double? = null,
    val note: String? = null,
)

data class TicketPreview(
    val referencePriceCcy: Double?,
    val exposureEur: Double,
    val reservationEur: Double,
    val estimatedFeesEur: Double,
    val buyingPowerEur: Double,
    val riskBudgetEur: Double,
    val potentialLossEur: Double?,
    val potentialGainEur: Double?,
    val riskReward: Double?,
    val riskOfEquity: Double?,
    val concentrationAfter: Double?,
    val firstEligibleSession: LocalDate,
    val warnings: List<String>,
    val errors: List<String>,
) {
    val isValid: Boolean get() = errors.isEmpty()
}

data class PlacementContext(
    val snapshot: AccountSnapshot,
    val activeOrders: List<PaperOrder>,
    /** Last known price in instrument currency (null if no data). */
    val lastPriceCcy: Double?,
    /** 1 EUR = eurToCcy units of the instrument currency. */
    val eurToCcy: Double?,
    val risk: RiskParameters,
    val config: SimulationConfig,
    val now: Instant,
)

object OrderPlacement {

    /** First session whose open happens after [createdAt]: a bar that had already started is never used. */
    fun firstEligibleSession(exchange: String, createdAt: Instant): LocalDate {
        val cal = Calendars.forExchange(exchange)
        val local = createdAt.atZone(cal.zone)
        val date = local.toLocalDate()
        return if (cal.isTradingDay(date) && local.toLocalTime().isBefore(cal.regularOpen)) date else cal.nextTradingDay(date)
    }

    fun referencePrice(t: OrderTicket, last: Double?, config: SimulationConfig): Double? {
        val f = config.fees
        return when (t.type) {
            OrderType.MARKET -> last?.let { if (t.side == OrderSide.BUY) it * (1 + config.marketOrderGapBuffer) else it }
            OrderType.LIMIT -> t.limitPrice
            OrderType.STOP -> t.stopPrice?.let { if (t.side == OrderSide.BUY) it * (1 + f.stopExtraSlippage + config.marketOrderGapBuffer) else it }
            OrderType.STOP_LIMIT -> t.limitPrice
        }
    }

    fun preview(t: OrderTicket, ctx: PlacementContext): TicketPreview {
        val errors = mutableListOf<String>()
        val warnings = mutableListOf<String>()
        val f = ctx.config.fees
        val eligible = firstEligibleSession(t.exchange, ctx.now)

        if (t.quantity <= 0) errors += "La quantità deve essere maggiore di zero."
        when (t.type) {
            OrderType.LIMIT -> if ((t.limitPrice ?: 0.0) <= 0) errors += "Prezzo limite obbligatorio."
            OrderType.STOP -> if ((t.stopPrice ?: 0.0) <= 0) errors += "Prezzo stop obbligatorio."
            OrderType.STOP_LIMIT -> if ((t.stopPrice ?: 0.0) <= 0 || (t.limitPrice ?: 0.0) <= 0) errors += "Prezzi stop e limite obbligatori."
            OrderType.MARKET -> if (ctx.lastPriceCcy == null) errors += "Nessun prezzo disponibile: aggiorna i dati prima di un ordine a mercato."
        }
        if (t.account == AccountType.ETF && t.assetClass != AssetClass.ETF) errors += "Il conto ETF accetta solo ETF. Usa il conto Trading."
        if (t.assetClass == AssetClass.INDEX) errors += "Gli indici non sono negoziabili."
        if (t.assetClass == AssetClass.ETF && !t.isUcits) warnings += "ETF non UCITS: in genere non acquistabile da investitori retail UE (simulazione a solo scopo di confronto)."
        val rate = if (t.currency == "EUR") 1.0 else ctx.eurToCcy
        if (rate == null) errors += "Tasso di cambio EUR/${t.currency} non disponibile: aggiorna i dati."

        val ref = referencePrice(t, ctx.lastPriceCcy, ctx.config)
        val entryRef = when (t.type) {
            OrderType.MARKET -> ctx.lastPriceCcy
            OrderType.LIMIT -> t.limitPrice
            OrderType.STOP -> t.stopPrice
            OrderType.STOP_LIMIT -> t.limitPrice
        }
        if (t.side == OrderSide.BUY) {
            t.stopLoss?.let { sl -> if (entryRef != null && sl >= entryRef) errors += "Lo stop loss deve essere sotto il prezzo di ingresso." }
            t.takeProfit?.let { tp -> if (entryRef != null && tp <= entryRef) errors += "Il take profit deve essere sopra il prezzo di ingresso." }
            if (t.account == AccountType.TRADING && t.stopLoss == null) warnings += "Nessuno stop loss: perdita potenziale non limitata dal piano."
        } else if (t.stopLoss != null || t.takeProfit != null) {
            errors += "Stop loss / take profit si applicano agli ordini di acquisto (bracket)."
        }

        val notionalEur = if (ref != null && rate != null && t.quantity > 0) t.quantity * ref * (1 + f.halfSpread + f.slippage) / rate else 0.0
        val fees = f.commission(notionalEur) + f.fxCost(notionalEur, t.currency)
        val reservation = if (t.side == OrderSide.BUY) notionalEur + fees else 0.0
        val buyingPower = ctx.snapshot.availableCashEur

        if (t.side == OrderSide.BUY && errors.isEmpty() && reservation > buyingPower + 1e-6) {
            errors += "Liquidità disponibile insufficiente: servono ${"%.2f".format(reservation)} €, disponibili ${"%.2f".format(buyingPower)} € (al netto degli ordini in attesa)."
        }
        if (t.side == OrderSide.SELL) {
            val held = ctx.snapshot.positions.firstOrNull { it.position.instrumentId == t.instrumentId }?.position?.quantity ?: 0.0
            val pendingSells = ctx.activeOrders.filter { it.side == OrderSide.SELL && it.instrumentId == t.instrumentId && it.account == t.account }
                .groupBy { it.ocoGroupId ?: it.id }.values.sumOf { g -> g.maxOf { it.remainingQuantity } }
            if (t.quantity > held - pendingSells + 1e-9) {
                errors += "Quantità vendibile insufficiente (${(held - pendingSells).toInt()} disponibili): vendite allo scoperto disabilitate."
            }
        }

        val equity = ctx.snapshot.equityEur
        val riskBudget = equity * ctx.risk.riskPerTrade
        val potentialLoss = if (t.side == OrderSide.BUY && t.stopLoss != null && entryRef != null && rate != null) {
            t.quantity * (entryRef - t.stopLoss * (1 - f.slippage - f.stopExtraSlippage)) / rate + 2 * f.commission(notionalEur) + 2 * f.fxCost(notionalEur, t.currency)
        } else null
        val potentialGain = if (t.side == OrderSide.BUY && t.takeProfit != null && entryRef != null && rate != null) {
            t.quantity * (t.takeProfit - entryRef) / rate - 2 * f.commission(notionalEur) - 2 * f.fxCost(notionalEur, t.currency)
        } else null
        val rr = if (entryRef != null && t.stopLoss != null && t.takeProfit != null && entryRef > t.stopLoss) (t.takeProfit - entryRef) / (entryRef - t.stopLoss) else null
        val riskOfEquity = potentialLoss?.let { if (equity > 0) it / equity else null }

        val existing = ctx.snapshot.positions.firstOrNull { it.position.instrumentId == t.instrumentId }?.marketValueEur ?: 0.0
        val concentration = if (t.side == OrderSide.BUY && equity > 0) (existing + notionalEur) / equity else null

        if (t.account == AccountType.TRADING && t.side == OrderSide.BUY) {
            val openInstruments = ctx.snapshot.positions.map { it.position.instrumentId }.toSet() +
                ctx.activeOrders.filter { it.side == OrderSide.BUY && it.role == OrderRole.ENTRY && it.account == AccountType.TRADING }.map { it.instrumentId }
            if (t.instrumentId !in openInstruments && openInstruments.size >= ctx.risk.maxOpenPositions) {
                errors += "Limite di ${ctx.risk.maxOpenPositions} posizioni simultanee raggiunto (inclusi ordini in attesa)."
            }
            if (concentration != null && concentration > ctx.risk.maxPositionExposure + 1e-9) {
                errors += "Esposizione ${"%.1f".format(concentration * 100)}% oltre il massimo del ${"%.1f".format(ctx.risk.maxPositionExposure * 100)}% del capitale."
            }
            if (riskOfEquity != null && riskOfEquity > ctx.risk.riskPerTrade * 1.05) {
                warnings += "Perdita potenziale allo stop pari al ${"%.2f".format(riskOfEquity * 100)}% del capitale: oltre il rischio per trade (${"%.2f".format(ctx.risk.riskPerTrade * 100)}%)."
            }
            if (rr != null && rr < ctx.risk.minRiskReward) warnings += "Rapporto rendimento/rischio ${"%.2f".format(rr)} inferiore al minimo ${ctx.risk.minRiskReward}."
        }
        if (equity <= 0) warnings += "Capitale del conto non configurato."
        warnings += "Esecuzione simulata su dati giornalieri dalla seduta del $eligible: nessun ordine reale viene inviato."

        return TicketPreview(
            referencePriceCcy = ref, exposureEur = notionalEur, reservationEur = reservation, estimatedFeesEur = fees,
            buyingPowerEur = buyingPower, riskBudgetEur = riskBudget, potentialLossEur = potentialLoss, potentialGainEur = potentialGain,
            riskReward = rr, riskOfEquity = riskOfEquity, concentrationAfter = concentration, firstEligibleSession = eligible,
            warnings = warnings, errors = errors,
        )
    }

    data class Placement(val order: PaperOrder, val preview: TicketPreview)

    /** Creates the order. Invalid tickets are recorded as REJECTED (auditable) rather than dropped. */
    fun place(t: OrderTicket, ctx: PlacementContext, id: String = UUID.randomUUID().toString()): Placement {
        val p = preview(t, ctx)
        val order = PaperOrder(
            id = id, account = t.account, instrumentId = t.instrumentId, exchange = t.exchange, currency = t.currency,
            side = t.side, type = t.type, quantity = t.quantity, limitPrice = t.limitPrice, stopPrice = t.stopPrice,
            timeInForce = t.timeInForce, expiresOn = t.expiresOn, createdAt = ctx.now, firstEligibleSession = p.firstEligibleSession,
            status = if (p.isValid) OrderStatus.NEW else OrderStatus.REJECTED,
            role = if (t.side == OrderSide.BUY) OrderRole.ENTRY else OrderRole.EXIT,
            bracketStopLoss = t.stopLoss, bracketTakeProfit = t.takeProfit,
            statusReason = if (p.isValid) null else p.errors.joinToString(" "),
            reservedCashEur = if (p.isValid) p.reservationEur else 0.0,
            note = t.note,
        )
        return Placement(order, p)
    }

    /** Cancels an active order and its linked exit orders. Returns all modified orders. */
    fun cancel(order: PaperOrder, all: List<PaperOrder>, reason: String = "Annullato dall'utente"): List<PaperOrder> {
        if (!order.status.isActive) return emptyList()
        val linked = all.filter { (it.parentId == order.id || (order.ocoGroupId != null && it.ocoGroupId == order.ocoGroupId && it.id != order.id)) && it.status.isActive }
        // Cancelling one OCO exit leaves the other leg active; cancelling an entry cancels pending children.
        val toCancel = if (order.role == OrderRole.ENTRY) listOf(order) + linked else listOf(order)
        return toCancel.map { it.copy(status = OrderStatus.CANCELLED, statusReason = reason, reservedCashEur = 0.0) }
    }

    fun reservedCash(orders: List<PaperOrder>, account: AccountType): Double =
        orders.filter { it.account == account && it.status.isActive && it.side == OrderSide.BUY }.sumOf { it.reservedCashEur }
}
