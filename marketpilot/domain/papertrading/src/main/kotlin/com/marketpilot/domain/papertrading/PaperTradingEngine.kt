package com.marketpilot.domain.papertrading

import com.marketpilot.core.common.Calendars
import com.marketpilot.core.model.Candle
import com.marketpilot.domain.portfolio.LedgerEntry
import com.marketpilot.domain.portfolio.LedgerKind
import com.marketpilot.domain.portfolio.PortfolioCalculator
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlin.math.floor

/** Provides EUR->currency daily reference rates (latest available on or before a date). */
fun interface FxLookup {
    /** 1 EUR = result units of [currency]; null when unknown. */
    fun eurTo(currency: String, date: LocalDate): Double?
}

data class EngineEvent(val orderId: String, val session: LocalDate?, val message: String)

data class EvaluationResult(
    val orders: List<PaperOrder>,
    val fills: List<PaperFill>,
    val ledger: List<LedgerEntry>,
    val events: List<EngineEvent>,
    val evaluatedThrough: Map<String, LocalDate>,
)

/**
 * Daily-bar paper trading engine.
 *
 * Rules (see PAPER_TRADING_RULES.md):
 * - An order only sees bars from its first eligible session onward (never a bar that had already
 *   started when the order was created) and only bars of completed sessions.
 * - Market orders fill at the next eligible open plus spread/slippage.
 * - Gaps are modelled: a stop gapped through fills at the open, not at the stop price.
 * - Limit orders fill at the open if it is better than the limit, otherwise at the limit only when the
 *   bar's range shows the price traded through it.
 * - When a daily bar cannot reveal the intraday order of events, the less favourable outcome is used
 *   and the fill is flagged as ambiguous.
 * - Orders are processed chronologically across instruments so cash checks are consistent.
 */
class PaperTradingEngine(private val config: SimulationConfig) {

    fun evaluate(
        orders: List<PaperOrder>,
        ledger: List<LedgerEntry>,
        candles: Map<String, List<Candle>>,
        fx: FxLookup,
        now: Instant,
        idFactory: () -> String = { UUID.randomUUID().toString() },
    ): EvaluationResult {
        val work = orders.associateBy { it.id }.toMutableMap()
        val newLedger = mutableListOf<LedgerEntry>()
        val fills = mutableListOf<PaperFill>()
        val events = mutableListOf<EngineEvent>()
        val evaluatedThrough = mutableMapOf<String, LocalDate>()

        val bars: Map<String, Map<LocalDate, Candle>> = candles.mapValues { (_, list) -> list.associateBy { it.date } }
        val lastCompletedByExchange = work.values.map { it.exchange }.distinct().associateWith {
            com.marketpilot.core.common.MarketSessions.lastCompletedSession(Calendars.forExchange(it), now)
        }
        val start = work.values.filter { it.status.isActive }.minOfOrNull { it.lastEvaluatedSession?.plusDays(1) ?: it.firstEligibleSession }
            ?: return EvaluationResult(orders, emptyList(), emptyList(), emptyList(), emptyMap())
        val end = lastCompletedByExchange.values.maxOrNull() ?: return EvaluationResult(orders, emptyList(), emptyList(), emptyList(), emptyMap())

        // Instruments whose data has a gap stop being evaluated (wait for data rather than skipping a session).
        val blocked = mutableSetOf<String>()
        var day = start
        while (!day.isAfter(end)) {
            val active = work.values.filter { it.status.isActive }.sortedWith(compareBy({ rolePriority(it.role) }, { it.createdAt }))
            for (snapshot in active) {
                val order = work[snapshot.id] ?: continue
                if (!order.status.isActive) continue
                val cal = Calendars.forExchange(order.exchange)
                val lastCompleted = lastCompletedByExchange[order.exchange] ?: continue
                if (day.isAfter(lastCompleted) || day.isBefore(order.firstEligibleSession)) continue
                if (order.lastEvaluatedSession != null && !day.isAfter(order.lastEvaluatedSession)) continue
                if (!cal.isTradingDay(day)) continue
                if (order.instrumentId in blocked) continue
                if (order.timeInForce == TimeInForce.GTC && order.expiresOn != null && day.isAfter(order.expiresOn)) {
                    work[order.id] = order.copy(status = OrderStatus.EXPIRED, statusReason = "Scaduto il ${order.expiresOn}", reservedCashEur = 0.0)
                    events += EngineEvent(order.id, day, "Ordine scaduto")
                    continue
                }
                val bar = bars[order.instrumentId]?.get(day)
                if (bar == null) {
                    blocked += order.instrumentId
                    work[order.id] = order.copy(status = OrderStatus.PENDING, statusReason = "In attesa dei dati della seduta $day")
                    continue
                }
                processBar(order, bar, work, newLedger, fills, events, fx, ledger, idFactory, now)
                val after = work[order.id]!!
                val evaluated = if (after.status.isActive) after.copy(lastEvaluatedSession = day) else after.copy(lastEvaluatedSession = day)
                work[order.id] = if (evaluated.status.isActive && evaluated.timeInForce == TimeInForce.DAY) {
                    events += EngineEvent(order.id, day, "Ordine giornaliero non eseguito: scaduto")
                    evaluated.copy(status = OrderStatus.EXPIRED, statusReason = "Ordine giornaliero non eseguito nella seduta $day", reservedCashEur = 0.0)
                } else evaluated
                evaluatedThrough[order.id] = day
            }
            day = day.plusDays(1)
        }
        return EvaluationResult(work.values.sortedBy { it.createdAt }, fills, newLedger, events, evaluatedThrough)
    }

    private fun rolePriority(role: OrderRole) = when (role) {
        OrderRole.STOP_LOSS -> 0 // exits first: conservative and frees the position before new entries
        OrderRole.TAKE_PROFIT -> 1
        OrderRole.EXIT -> 2
        OrderRole.ENTRY -> 3
    }

    data class FillDecision(val price: Double, val basis: String, val ambiguous: Boolean = false, val triggeredOnly: Boolean = false)

    /** Pure price logic for one order against one completed daily bar. */
    fun decide(order: PaperOrder, bar: Candle): FillDecision? {
        val f = config.fees
        val o = bar.open
        val buy = order.side == OrderSide.BUY
        val stopCost = f.halfSpread + f.slippage + f.stopExtraSlippage
        return when (order.type) {
            OrderType.MARKET -> {
                val p = if (buy) o * (1 + f.halfSpread + f.slippage) else o * (1 - f.halfSpread - f.slippage)
                FillDecision(p, "Apertura della seduta ${bar.date} (${fmt(o)}) con spread e slippage")
            }
            OrderType.LIMIT -> limitDecision(order.limitPrice!!, buy, bar, "")
            OrderType.STOP -> {
                val s = order.stopPrice!!
                if (buy) when {
                    o >= s -> FillDecision(o * (1 + stopCost), "Gap in apertura sopra lo stop (${fmt(o)} ≥ ${fmt(s)}): eseguito all'apertura")
                    bar.high >= s -> FillDecision(minOf(s * (1 + stopCost), bar.high), "Stop ${fmt(s)} raggiunto durante la seduta ${bar.date}")
                    else -> null
                } else when {
                    o <= s -> FillDecision(o * (1 - stopCost), "Gap in apertura sotto lo stop (${fmt(o)} ≤ ${fmt(s)}): eseguito all'apertura")
                    bar.low <= s -> FillDecision(maxOf(s * (1 - stopCost), bar.low), "Stop ${fmt(s)} raggiunto durante la seduta ${bar.date}")
                    else -> null
                }
            }
            OrderType.STOP_LIMIT -> {
                val s = order.stopPrice!!
                val l = order.limitPrice!!
                if (order.triggered) return limitDecision(l, buy, bar, "stop-limit già attivato: ")
                val triggeredAtOpen = if (buy) o >= s else o <= s
                val triggeredIntraday = if (buy) bar.high >= s else bar.low <= s
                when {
                    triggeredAtOpen -> limitDecision(l, buy, bar, "stop attivato in apertura: ") ?: FillDecision(0.0, "", triggeredOnly = true)
                    triggeredIntraday -> {
                        val fillable = if (buy) s <= l else s >= l
                        if (fillable) {
                            val p = if (buy) minOf(s * (1 + f.halfSpread + f.slippage), l) else maxOf(s * (1 - f.halfSpread - f.slippage), l)
                            FillDecision(p, "Stop ${fmt(s)} attivato in seduta, eseguito entro il limite ${fmt(l)}")
                        } else {
                            // Price would have to return to the limit after the trigger: sequence unknown, no fill this bar.
                            FillDecision(0.0, "", triggeredOnly = true)
                        }
                    }
                    else -> null
                }
            }
        }
    }

    private fun limitDecision(limit: Double, buy: Boolean, bar: Candle, prefix: String): FillDecision? {
        val o = bar.open
        val hs = config.fees.halfSpread
        return if (buy) when {
            o <= limit -> FillDecision(minOf(o * (1 + hs), limit), "${prefix}apertura ${fmt(o)} sotto il limite ${fmt(limit)}")
            (if (config.limitRequiresPenetration) bar.low < limit else bar.low <= limit) ->
                FillDecision(limit, "${prefix}minimo della seduta ${fmt(bar.low)} sotto il limite: eseguito al limite")
            else -> null
        } else when {
            o >= limit -> FillDecision(maxOf(o * (1 - hs), limit), "${prefix}apertura ${fmt(o)} sopra il limite ${fmt(limit)}")
            (if (config.limitRequiresPenetration) bar.high > limit else bar.high >= limit) ->
                FillDecision(limit, "${prefix}massimo della seduta ${fmt(bar.high)} sopra il limite: eseguito al limite")
            else -> null
        }
    }

    private fun processBar(
        order: PaperOrder,
        bar: Candle,
        work: MutableMap<String, PaperOrder>,
        newLedger: MutableList<LedgerEntry>,
        fills: MutableList<PaperFill>,
        events: MutableList<EngineEvent>,
        fx: FxLookup,
        priorLedger: List<LedgerEntry>,
        idFactory: () -> String,
        now: Instant,
    ) {
        // OCO exits: resolve both legs together on the same bar.
        if (order.ocoGroupId != null && (order.role == OrderRole.STOP_LOSS || order.role == OrderRole.TAKE_PROFIT)) {
            val legs = work.values.filter { it.ocoGroupId == order.ocoGroupId && it.status.isActive }
            val stopLeg = legs.firstOrNull { it.role == OrderRole.STOP_LOSS }
            val tpLeg = legs.firstOrNull { it.role == OrderRole.TAKE_PROFIT }
            if (stopLeg != null && tpLeg != null) {
                val stopHit = decide(stopLeg, bar)
                val tpHit = decide(tpLeg, bar)
                val chosen: Pair<PaperOrder, FillDecision>? = when {
                    stopHit != null && tpHit != null -> {
                        val gapToTarget = bar.open >= tpLeg.limitPrice!!
                        val gapToStop = bar.open <= stopLeg.stopPrice!!
                        when {
                            gapToStop -> stopLeg to stopHit
                            gapToTarget -> tpLeg to tpHit
                            else -> stopLeg to stopHit.copy(
                                ambiguous = true,
                                basis = stopHit.basis + ". Stop e target entrambi toccati nella seduta: sequenza sconosciuta, ipotesi prudente (stop prima).",
                            )
                        }
                    }
                    stopHit != null -> stopLeg to stopHit
                    tpHit != null -> tpLeg to tpHit
                    else -> null
                }
                if (chosen != null) {
                    execute(chosen.first, chosen.second, bar, work, newLedger, fills, events, fx, priorLedger, idFactory, now)
                    val sibling = if (chosen.first.id == stopLeg.id) tpLeg else stopLeg
                    work[sibling.id]?.let {
                        if (it.status.isActive) work[sibling.id] = it.copy(status = OrderStatus.CANCELLED, statusReason = "OCO: eseguito l'altro ordine", lastEvaluatedSession = bar.date)
                    }
                }
                return
            }
        }
        val decision = decide(order, bar) ?: run {
            if (order.status == OrderStatus.NEW) work[order.id] = order.copy(status = OrderStatus.PENDING, statusReason = null)
            return
        }
        if (decision.triggeredOnly) {
            work[order.id] = order.copy(status = OrderStatus.PENDING, triggered = true, statusReason = "Stop attivato il ${bar.date}: ora attivo come ordine limite")
            events += EngineEvent(order.id, bar.date, "Stop-limit attivato")
            return
        }
        execute(order, decision, bar, work, newLedger, fills, events, fx, priorLedger, idFactory, now)
    }

    private fun execute(
        order: PaperOrder,
        decision: FillDecision,
        bar: Candle,
        work: MutableMap<String, PaperOrder>,
        newLedger: MutableList<LedgerEntry>,
        fills: MutableList<PaperFill>,
        events: MutableList<EngineEvent>,
        fx: FxLookup,
        priorLedger: List<LedgerEntry>,
        idFactory: () -> String,
        now: Instant,
    ) {
        val rate = if (order.currency == "EUR") 1.0 else fx.eurTo(order.currency, bar.date)
        if (rate == null) {
            work[order.id] = order.copy(status = OrderStatus.PENDING, statusReason = "Cambio EUR/${order.currency} non disponibile per il ${bar.date}")
            return
        }
        var qty = order.remainingQuantity
        var partialNote = ""
        val cap = config.maxParticipationOfBarVolume
        val barVolume = bar.volume
        if (cap != null && barVolume != null && barVolume > 0) {
            val maxQty = floor(barVolume * cap).toInt()
            if (maxQty < qty) {
                qty = maxQty
                partialNote = " Esecuzione parziale: massimo ${(cap * 100).toInt()}% del volume della seduta."
            }
        }
        if (qty <= 0) {
            work[order.id] = order.copy(status = OrderStatus.PENDING, statusReason = "Volume della seduta insufficiente")
            return
        }
        val allLedger = priorLedger + newLedger
        val gross = qty * decision.price / rate
        val commission = config.fees.commission(gross)
        val fxCost = config.fees.fxCost(gross, order.currency)
        if (order.side == OrderSide.BUY) {
            val cash = PortfolioCalculator.cash(allLedger, order.account)
            val reservedByOthers = work.values.filter { it.id != order.id && it.status.isActive && it.side == OrderSide.BUY && it.account == order.account }
                .sumOf { it.reservedCashEur }
            val available = cash - reservedByOthers
            if (gross + commission + fxCost > available + 1e-6) {
                work[order.id] = order.copy(
                    status = OrderStatus.REJECTED, reservedCashEur = 0.0, lastEvaluatedSession = bar.date,
                    statusReason = "Liquidità insufficiente al momento dell'esecuzione (${bar.date}): servono ${fmt(gross + commission + fxCost)} €, disponibili ${fmt(available)} €",
                )
                events += EngineEvent(order.id, bar.date, "Rifiutato: liquidità insufficiente")
                return
            }
        } else {
            val held = PortfolioCalculator.positions(allLedger, order.account).firstOrNull { it.instrumentId == order.instrumentId }?.quantity ?: 0.0
            if (held + 1e-9 < qty) {
                work[order.id] = order.copy(
                    status = OrderStatus.REJECTED, lastEvaluatedSession = bar.date,
                    statusReason = "Quantità in portafoglio insufficiente (${held.toInt()}): vendite allo scoperto non consentite",
                )
                events += EngineEvent(order.id, bar.date, "Rifiutato: posizione insufficiente")
                cancelSiblings(order, work, bar.date, "Posizione non più presente")
                return
            }
        }
        val fillId = idFactory()
        val basis = decision.basis + partialNote
        fills += PaperFill(fillId, order.id, order.account, order.instrumentId, order.side, bar.date, qty, decision.price, order.currency, rate, gross, commission, fxCost, basis, decision.ambiguous)
        val sign = if (order.side == OrderSide.BUY) -1.0 else 1.0
        newLedger += LedgerEntry(
            idFactory(), order.account, if (order.side == OrderSide.BUY) LedgerKind.BUY else LedgerKind.SELL,
            PortfolioCalculator.round2(sign * gross), bar.date, now, order.instrumentId,
            if (order.side == OrderSide.BUY) qty.toDouble() else -qty.toDouble(), decision.price, order.currency, rate, fillId,
        )
        if (commission > 0) newLedger += LedgerEntry(idFactory(), order.account, LedgerKind.FEE, -PortfolioCalculator.round2(commission), bar.date, now, order.instrumentId, referenceId = fillId)
        if (fxCost > 0) newLedger += LedgerEntry(idFactory(), order.account, LedgerKind.FX_COST, -PortfolioCalculator.round2(fxCost), bar.date, now, order.instrumentId, referenceId = fillId)

        val filled = order.filledQuantity + qty
        val done = filled >= order.quantity
        val reservedLeft = if (done) 0.0 else order.reservedCashEur * (order.quantity - filled).toDouble() / order.quantity
        work[order.id] = order.copy(
            filledQuantity = filled,
            status = if (done) OrderStatus.FILLED else OrderStatus.PARTIALLY_FILLED,
            reservedCashEur = reservedLeft,
            lastEvaluatedSession = bar.date,
            statusReason = if (decision.ambiguous) "Esito ambiguo: applicata ipotesi prudente" else null,
        )
        events += EngineEvent(order.id, bar.date, "Eseguiti $qty a ${fmt(decision.price)} ${order.currency}")

        if (order.role == OrderRole.ENTRY && order.side == OrderSide.BUY && (order.bracketStopLoss != null || order.bracketTakeProfit != null)) {
            attachBracket(order, qty, bar, work, newLedger, fills, events, fx, priorLedger, idFactory, now)
        }
        if (order.side == OrderSide.SELL && order.role == OrderRole.EXIT) {
            cancelSiblings(order, work, bar.date, "Posizione chiusa manualmente")
        }
    }

    private fun cancelSiblings(order: PaperOrder, work: MutableMap<String, PaperOrder>, date: LocalDate, reason: String) {
        val held = work.values.filter {
            it.id != order.id && it.status.isActive && it.instrumentId == order.instrumentId && it.account == order.account &&
                (it.role == OrderRole.STOP_LOSS || it.role == OrderRole.TAKE_PROFIT)
        }
        held.forEach { work[it.id] = it.copy(status = OrderStatus.CANCELLED, statusReason = reason, lastEvaluatedSession = date) }
    }

    private fun attachBracket(
        entry: PaperOrder,
        qty: Int,
        bar: Candle,
        work: MutableMap<String, PaperOrder>,
        newLedger: MutableList<LedgerEntry>,
        fills: MutableList<PaperFill>,
        events: MutableList<EngineEvent>,
        fx: FxLookup,
        priorLedger: List<LedgerEntry>,
        idFactory: () -> String,
        now: Instant,
    ) {
        val existing = work.values.filter { it.parentId == entry.id && it.status.isActive }
        if (existing.isNotEmpty()) {
            existing.forEach { work[it.id] = it.copy(quantity = it.quantity + qty) }
            return
        }
        val group = idFactory()
        val nextSession = Calendars.forExchange(entry.exchange).nextTradingDay(bar.date)
        val children = buildList {
            entry.bracketStopLoss?.let {
                add(PaperOrder(idFactory(), entry.account, entry.instrumentId, entry.exchange, entry.currency, OrderSide.SELL, OrderType.STOP, qty,
                    stopPrice = it, createdAt = now, firstEligibleSession = nextSession, status = OrderStatus.PENDING,
                    role = OrderRole.STOP_LOSS, parentId = entry.id, ocoGroupId = group))
            }
            entry.bracketTakeProfit?.let {
                add(PaperOrder(idFactory(), entry.account, entry.instrumentId, entry.exchange, entry.currency, OrderSide.SELL, OrderType.LIMIT, qty,
                    limitPrice = it, createdAt = now, firstEligibleSession = nextSession, status = OrderStatus.PENDING,
                    role = OrderRole.TAKE_PROFIT, parentId = entry.id, ocoGroupId = group))
            }
        }
        children.forEach { work[it.id] = it }
        events += EngineEvent(entry.id, bar.date, "Creati ordini di uscita collegati (OCO)")

        // Same-bar exit check: the bar continued after the entry, but its intraday path is unknown.
        val stopChild = children.firstOrNull { it.role == OrderRole.STOP_LOSS }
        if (config.sameBarExitPolicy == SameBarExitPolicy.CONSERVATIVE && stopChild != null && bar.low <= stopChild.stopPrice!!) {
            val price = maxOf(stopChild.stopPrice * (1 - config.fees.halfSpread - config.fees.slippage - config.fees.stopExtraSlippage), bar.low)
            val decision = FillDecision(
                price,
                "Il minimo della seduta d'ingresso (${fmt(bar.low)}) ha raggiunto lo stop ${fmt(stopChild.stopPrice)}: sequenza intraday sconosciuta, ipotesi prudente (stop colpito).",
                ambiguous = true,
            )
            execute(stopChild, decision, bar, work, newLedger, fills, events, fx, priorLedger, idFactory, now)
            children.firstOrNull { it.role == OrderRole.TAKE_PROFIT }?.let { tp ->
                work[tp.id] = tp.copy(status = OrderStatus.CANCELLED, statusReason = "OCO: stop colpito nella seduta d'ingresso")
            }
        }
    }

    private fun fmt(x: Double) = "%.2f".format(x)
}
