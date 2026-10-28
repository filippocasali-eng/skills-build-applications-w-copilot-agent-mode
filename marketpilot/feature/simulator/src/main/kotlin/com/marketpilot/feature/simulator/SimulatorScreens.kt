package com.marketpilot.feature.simulator

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Button
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MetricRow
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.NumberField
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.Instrument
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.OnDemandRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.papertrading.OrderSide
import com.marketpilot.domain.papertrading.OrderStatus
import com.marketpilot.domain.papertrading.OrderTicket
import com.marketpilot.domain.papertrading.OrderType
import com.marketpilot.domain.papertrading.PaperFill
import com.marketpilot.domain.papertrading.PaperOrder
import com.marketpilot.domain.papertrading.TicketPreview
import com.marketpilot.domain.papertrading.TimeInForce
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.risk.FxContext
import com.marketpilot.domain.risk.PositionSizer
import com.marketpilot.domain.risk.SizingRequest
import com.marketpilot.domain.risk.SizingResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

data class SimulatorState(
    val orders: List<PaperOrder> = emptyList(),
    val fills: List<PaperFill> = emptyList(),
    val symbols: Map<String, String> = emptyMap(),
    val lastEvaluation: Instant? = null,
    val message: String? = null,
)

@HiltViewModel
class SimulatorViewModel @Inject constructor(
    private val portfolio: PortfolioRepository,
    market: MarketDataRepository,
    settings: SettingsRepository,
) : ViewModel() {
    private val message = MutableStateFlow<String?>(null)
    val state: StateFlow<SimulatorState> = combine(portfolio.observeOrders(), portfolio.observeFills(), market.observeInstruments(), settings.settings, message) { o, f, i, s, m ->
        SimulatorState(o, f, i.associate { it.id to it.symbol }, s.lastPaperEvaluationMs?.let(Instant::ofEpochMilli), m)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SimulatorState())

    fun cancel(id: String) = viewModelScope.launch { message.value = if (portfolio.cancel(id)) "Ordine annullato" else "Ordine non annullabile" }

    fun reconcile() = viewModelScope.launch {
        val r = portfolio.reconcile()
        message.value = "Valutazione completata: ${r.fills.size} nuove esecuzioni simulate (solo sedute concluse con dati disponibili)."
    }
}

@Composable
fun SimulatorScreen(onNewOrder: () -> Unit, vm: SimulatorViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val active = s.orders.filter { it.status.isActive }
    val closed = s.orders.filterNot { it.status.isActive }
    MpScreen(
        "Simulatore", testTag = "simulator",
        floating = { ExtendedFloatingActionButton(onClick = onNewOrder, icon = { Icon(Icons.Filled.Add, null) }, text = { Text("Nuovo ordine") }, modifier = Modifier.testTag("new_order")) },
    ) {
        item { Banner("PAPER TRADING: nessun ordine reale viene inviato a un broker. Le esecuzioni sono simulate su barre giornaliere senza look-ahead.", MpColors.Warning) }
        item {
            MpCard {
                MetricRow("Ultima valutazione degli ordini", s.lastEvaluation?.let { Fmt.dateTime(it) } ?: "mai")
                Text("Android può ritardare i job in background: alla riapertura l'app riconcilia gli ordini con i dati disponibili, senza attribuire orari di esecuzione esatti.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                OutlinedButton(onClick = vm::reconcile, modifier = Modifier.testTag("reconcile")) { Text("Riconcilia ora") }
            }
        }
        s.message?.let { item { Banner(it, MpColors.Info) } }
        item { SectionTitle("Ordini attivi (${active.size})") }
        if (active.isEmpty()) item { Text("Nessun ordine attivo.", color = MpColors.TextSecondary) }
        active.forEach { o -> item(key = o.id) { OrderCard(o, s.symbols, onCancel = { vm.cancel(o.id) }) } }
        item { SectionTitle("Esecuzioni simulate") }
        if (s.fills.isEmpty()) item { Text("Nessuna esecuzione.", color = MpColors.TextSecondary) }
        s.fills.take(50).forEach { f ->
            item(key = "fill_${f.id}") {
                MpCard(Modifier.testTag("fill_card")) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${f.side.label} ${f.quantity} ${s.symbols[f.instrumentId] ?: f.instrumentId}", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        if (f.ambiguous) Pill("ESITO AMBIGUO", MpColors.Warning)
                    }
                    Text("${Fmt.money(f.priceCcy, f.currency)} · seduta del ${Fmt.date(f.session)} · ${f.account.label}", style = MaterialTheme.typography.bodySmall)
                    Text("Controvalore ${Fmt.eur(f.grossEur)} · commissioni ${Fmt.eur(f.commissionEur)} · cambio ${Fmt.eur(f.fxCostEur)} (EUR/${f.currency} ${Fmt.num(f.eurToCcy, 4)})", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                    Text(f.basis, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                }
            }
        }
        item { SectionTitle("Storico ordini") }
        closed.take(40).forEach { o -> item(key = "c_${o.id}") { OrderCard(o, s.symbols, onCancel = null) } }
    }
}

@Composable
private fun OrderCard(o: PaperOrder, symbols: Map<String, String>, onCancel: (() -> Unit)?) {
    MpCard(Modifier.testTag("order_card")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${o.side.label} ${o.quantity} ${symbols[o.instrumentId] ?: o.instrumentId}", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Pill(o.status.label, when (o.status) {
                OrderStatus.FILLED -> MpColors.Positive
                OrderStatus.REJECTED, OrderStatus.CANCELLED, OrderStatus.EXPIRED -> MpColors.TextSecondary
                else -> MpColors.Info
            })
        }
        Text(
            "${o.type.label}" + (o.limitPrice?.let { " limite ${Fmt.num(it)}" } ?: "") + (o.stopPrice?.let { " stop ${Fmt.num(it)}" } ?: "") +
                " · ${o.role.label} · ${o.timeInForce.label} · ${o.account.label}",
            style = MaterialTheme.typography.bodySmall,
        )
        if (o.bracketStopLoss != null || o.bracketTakeProfit != null) Text("Bracket: SL ${Fmt.num(o.bracketStopLoss)} / TP ${Fmt.num(o.bracketTakeProfit)}", style = MaterialTheme.typography.bodySmall)
        Text("Creato ${Fmt.dateTime(o.createdAt)} · valido dalla seduta del ${Fmt.date(o.firstEligibleSession)}" + (o.lastEvaluatedSession?.let { " · valutato fino al ${Fmt.date(it)}" } ?: ""), style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
        if (o.filledQuantity > 0 && o.status != OrderStatus.FILLED) Text("Eseguite ${o.filledQuantity}/${o.quantity}", style = MaterialTheme.typography.bodySmall)
        if (o.reservedCashEur > 0) Text("Liquidità riservata ${Fmt.eur(o.reservedCashEur)}", style = MaterialTheme.typography.bodySmall)
        o.statusReason?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MpColors.Warning) }
        if (onCancel != null) TextButton(onClick = onCancel, modifier = Modifier.testTag("cancel_order")) { Text("Annulla ordine") }
    }
}

// ---------------------------------------------------------------------------------------------------
data class TicketState(
    val query: String = "",
    val results: List<Instrument> = emptyList(),
    val instrument: Instrument? = null,
    val account: AccountType = AccountType.TRADING,
    val side: OrderSide = OrderSide.BUY,
    val type: OrderType = OrderType.LIMIT,
    val quantity: String = "",
    val limit: String = "",
    val stop: String = "",
    val stopLoss: String = "",
    val takeProfit: String = "",
    val tif: TimeInForce = TimeInForce.GTC,
    val riskPct: String = "",
    val lastPrice: Double? = null,
    val atrPercent: Double? = null,
    val sizing: SizingResult? = null,
    val preview: TicketPreview? = null,
    val result: String? = null,
    val placed: Boolean = false,
)

@HiltViewModel
class TicketViewModel @Inject constructor(
    handle: SavedStateHandle,
    private val market: MarketDataRepository,
    private val portfolio: PortfolioRepository,
    private val onDemand: OnDemandRepository,
    private val settings: SettingsRepository,
) : ViewModel() {
    private val _state = MutableStateFlow(TicketState())
    val state: StateFlow<TicketState> = _state

    init {
        viewModelScope.launch {
            _state.value = _state.value.copy(riskPct = Fmt.num(settings.current().risk.riskPerTrade * 100, 2).replace(',', '.'))
            val id: String? = handle["instrumentId"]
            val acc: String? = handle["account"]
            acc?.let { a -> runCatching { AccountType.valueOf(a) }.getOrNull()?.let { _state.value = _state.value.copy(account = it) } }
            id?.let { market.instrument(it) }?.let { select(it) }
        }
    }

    fun update(t: (TicketState) -> TicketState) { _state.value = t(_state.value).copy(preview = null, result = null) }

    fun search(q: String) = viewModelScope.launch {
        _state.value = _state.value.copy(query = q, results = onDemand.search(q, market.instruments().filter { it.assetClass == AssetClass.ETF || it.assetClass == AssetClass.STOCK }))
    }

    fun select(inst: Instrument) = viewModelScope.launch {
        val candles = market.candles(inst.id)
        val snap = TechnicalSnapshot.from(candles)
        val last = market.quote(inst.id)?.quote?.price ?: candles.lastOrNull()?.close
        _state.value = _state.value.copy(
            instrument = inst, results = emptyList(), query = inst.symbol, lastPrice = last, atrPercent = snap?.atrPercent,
            account = if (inst.assetClass == AssetClass.ETF && inst.isUcits) AccountType.ETF else AccountType.TRADING,
            limit = last?.let { "%.2f".format(java.util.Locale.US, it) } ?: "",
        )
    }

    private fun ticket(s: TicketState): OrderTicket? {
        val inst = s.instrument ?: return null
        return OrderTicket(
            s.account, inst.id, inst.exchange, inst.currency, inst.assetClass, inst.isUcits, s.side, s.type, s.quantity.toDoubleOrZero().toInt(),
            limitPrice = s.limit.toDoubleOrNull(), stopPrice = s.stop.toDoubleOrNull(), timeInForce = s.tif,
            stopLoss = s.stopLoss.toDoubleOrNull(), takeProfit = s.takeProfit.toDoubleOrNull(),
        )
    }

    /** Suggests a quantity from the risk budget (requires entry and stop loss). */
    fun size() = viewModelScope.launch {
        val s = _state.value
        val inst = s.instrument ?: return@launch
        val entry = (if (s.type == OrderType.STOP) s.stop.toDoubleOrNull() else s.limit.toDoubleOrNull()) ?: s.lastPrice
        val sl = s.stopLoss.toDoubleOrNull()
        if (entry == null || sl == null) { _state.value = s.copy(result = "Per il dimensionamento servono prezzo di ingresso e stop loss."); return@launch }
        val snap = portfolio.snapshot(s.account)
        val st = settings.current()
        val fx = if (inst.currency == "EUR") FxContext.EUR else market.fxLookup().eurTo(inst.currency, java.time.LocalDate.now())?.let { FxContext(inst.currency, it) }
        if (fx == null) { _state.value = s.copy(result = "Cambio non disponibile: aggiorna i dati."); return@launch }
        val candles = market.candles(inst.id)
        val tech = TechnicalSnapshot.from(candles)
        val openRisk = portfolio.orders().filter { it.status.isActive && it.account == s.account && it.side == OrderSide.BUY && it.bracketStopLoss != null }.sumOf { o ->
            val e = o.limitPrice ?: o.stopPrice ?: 0.0
            (o.remainingQuantity * (e - (o.bracketStopLoss ?: e))).coerceAtLeast(0.0) / fx.eurToCcy
        }
        val res = PositionSizer.size(
            SizingRequest(
                equityEur = snap.equityEur, availableCashEur = snap.availableCashEur, entry = entry, stop = sl, fx = fx,
                riskFraction = s.riskPct.toDoubleOrZero() / 100, params = SettingsRepository.risk(st), fees = SettingsRepository.fees(st),
                avgDailyVolume = tech?.avgVolume20, openPositions = snap.positions.size, currentOpenRiskEur = openRisk,
                atrPercent = tech?.atrPercent, volatility20d = tech?.volatility20d, avgDollarVolume20 = tech?.avgDollarVolume20,
            ),
        )
        _state.value = _state.value.copy(sizing = res, quantity = if (res.isValid) res.quantity.toString() else s.quantity)
    }

    fun preview() = viewModelScope.launch {
        val t = ticket(_state.value) ?: return@launch
        _state.value = _state.value.copy(preview = portfolio.preview(t))
    }

    fun place() = viewModelScope.launch {
        val t = ticket(_state.value) ?: return@launch
        val p = portfolio.place(t)
        _state.value = _state.value.copy(
            preview = p.preview, placed = p.order.status != OrderStatus.REJECTED,
            result = if (p.order.status == OrderStatus.REJECTED) "Ordine RIFIUTATO: ${p.order.statusReason}" else "Ordine simulato registrato. Sarà valutato dalla seduta del ${Fmt.date(p.order.firstEligibleSession)}.",
        )
    }
}

@Composable
fun TicketScreen(onBack: () -> Unit, onDone: () -> Unit, vm: TicketViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    MpScreen("Ordine simulato", onBack = onBack, testTag = "ticket") {
        item { Banner("Simulazione: nessun ordine reale viene inviato.", MpColors.Warning) }
        item {
            OutlinedTextField(s.query, { vm.search(it) }, label = { Text("Strumento (ticker, nome o ISIN)") }, singleLine = true, modifier = Modifier.fillMaxWidth().testTag("ticket_search"))
        }
        s.results.forEach { r -> item(key = "r_${r.id}") { TextButton(onClick = { vm.select(r) }, modifier = Modifier.testTag("result_${r.symbol}")) { Text("${r.symbol} · ${r.name} (${r.exchange})") } } }
        val inst = s.instrument ?: return@MpScreen
        item {
            MpCard {
                Text("${inst.symbol} · ${inst.name}", fontWeight = FontWeight.SemiBold)
                Text("Ultimo prezzo disponibile: ${Fmt.money(s.lastPrice, inst.currency)}" + (s.atrPercent?.let { " · ATR ${Fmt.pct(it, signed = false)}" } ?: ""), style = MaterialTheme.typography.bodySmall)
                ChipRow(AccountType.entries, s.account, { it.label }, { a -> vm.update { it.copy(account = a) } })
                ChipRow(OrderSide.entries, s.side, { it.label }, { v -> vm.update { it.copy(side = v) } })
                ChipRow(OrderType.entries, s.type, { it.label }, { v -> vm.update { it.copy(type = v) } }, Modifier.testTag("order_type"))
                if (s.type == OrderType.LIMIT || s.type == OrderType.STOP_LIMIT) NumberField("Prezzo limite (${inst.currency})", s.limit, { v -> vm.update { it.copy(limit = v) } }, tag = "ticket_limit")
                if (s.type == OrderType.STOP || s.type == OrderType.STOP_LIMIT) NumberField("Prezzo stop (${inst.currency})", s.stop, { v -> vm.update { it.copy(stop = v) } })
                if (s.side == OrderSide.BUY) {
                    NumberField("Stop loss (${inst.currency})", s.stopLoss, { v -> vm.update { it.copy(stopLoss = v) } }, tag = "ticket_sl")
                    NumberField("Take profit (${inst.currency})", s.takeProfit, { v -> vm.update { it.copy(takeProfit = v) } }, tag = "ticket_tp")
                }
                ChipRow(TimeInForce.entries, s.tif, { it.label }, { v -> vm.update { it.copy(tif = v) } })
                NumberField("Rischio per questo trade", s.riskPct, { v -> vm.update { it.copy(riskPct = v) } }, suffix = "%")
                OutlinedButton(onClick = vm::size, modifier = Modifier.testTag("ticket_size")) { Text("Calcola quantità dal rischio") }
                NumberField("Quantità", s.quantity, { v -> vm.update { it.copy(quantity = v.filter(Char::isDigit)) } }, tag = "ticket_qty")
            }
        }
        s.sizing?.let { z -> item { SizingCard(z) } }
        item {
            Row {
                OutlinedButton(onClick = vm::preview, modifier = Modifier.weight(1f).testTag("ticket_preview")) { Text("Anteprima") }
                Spacer(Modifier.width(8.dp))
                Button(onClick = vm::place, modifier = Modifier.weight(1f).testTag("ticket_place"), enabled = !s.placed) { Text("Invia (simulato)") }
            }
        }
        s.preview?.let { p -> item { PreviewCard(p, inst.currency) } }
        s.result?.let { r ->
            item {
                Banner(r, if (s.placed) MpColors.Positive else MpColors.Negative)
                if (s.placed) TextButton(onClick = onDone, modifier = Modifier.testTag("ticket_done")) { Text("Vai agli ordini") }
            }
        }
    }
}

@Composable
private fun SizingCard(z: SizingResult) {
    MpCard {
        SectionTitle("Dimensionamento")
        z.errors.forEach { Text("• $it", color = MpColors.Negative, style = MaterialTheme.typography.bodySmall) }
        if (z.errors.isEmpty()) {
            MetricRow("Quantità suggerita", z.quantity.toString())
            MetricRow("Limitata da", z.limitingFactor?.label ?: "n/d")
            MetricRow("Budget di rischio", Fmt.eur(z.riskBudgetEur))
            MetricRow("Perdita stimata allo stop", Fmt.eur(z.estimatedLossAtStopEur))
            MetricRow("Esposizione", "${Fmt.eur(z.exposureEur)} (${Fmt.pct(z.exposurePercent, signed = false)})")
            Text("Alternative: " + z.candidates.entries.joinToString { "${it.key.label} ${it.value}" }, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        }
        z.warnings.forEach { Text("⚠ $it", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning) }
    }
}

@Composable
private fun PreviewCard(p: TicketPreview, ccy: String) {
    MpCard(Modifier.testTag("ticket_preview_card")) {
        SectionTitle("Anteprima")
        p.errors.forEach { Text("✕ $it", color = MpColors.Negative, style = MaterialTheme.typography.bodySmall) }
        MetricRow("Prezzo di riferimento", Fmt.money(p.referencePriceCcy, ccy))
        MetricRow("Esposizione stimata", Fmt.eur(p.exposureEur))
        MetricRow("Liquidità riservata", Fmt.eur(p.reservationEur))
        MetricRow("Costi stimati", Fmt.eur(p.estimatedFeesEur))
        MetricRow("Potere d'acquisto", Fmt.eur(p.buyingPowerEur))
        MetricRow("Budget di rischio (impostazioni)", Fmt.eur(p.riskBudgetEur))
        MetricRow("Perdita potenziale allo stop", Fmt.eur(p.potentialLossEur))
        MetricRow("Guadagno potenziale al target", Fmt.eur(p.potentialGainEur))
        MetricRow("Rendimento/rischio", p.riskReward?.let { Fmt.num(it) } ?: "n/d")
        MetricRow("Rischio sul capitale", Fmt.pct(p.riskOfEquity, 2, signed = false))
        MetricRow("Concentrazione dopo l'ordine", Fmt.pct(p.concentrationAfter, signed = false))
        MetricRow("Prima seduta valutabile", Fmt.date(p.firstEligibleSession))
        p.warnings.forEach { Text("⚠ $it", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning) }
    }
}
