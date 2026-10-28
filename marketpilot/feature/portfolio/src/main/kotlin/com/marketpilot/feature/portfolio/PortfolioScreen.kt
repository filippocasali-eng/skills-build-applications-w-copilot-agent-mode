package com.marketpilot.feature.portfolio

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.LineChart
import com.marketpilot.core.designsystem.MetricRow
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.NumberField
import com.marketpilot.core.designsystem.Overlay
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.changeColor
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.data.repositories.AccountAnalytics
import com.marketpilot.data.repositories.Accounts
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.portfolio.AccountSnapshot
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.portfolio.LedgerEntry
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PortfolioState(
    val accounts: Accounts? = null,
    val ledger: List<LedgerEntry> = emptyList(),
    val symbols: Map<String, String> = emptyMap(),
    val analytics: Map<AccountType, AccountAnalytics> = emptyMap(),
    val monthly: Double = 0.0,
    val message: String? = null,
)

@HiltViewModel
class PortfolioViewModel @Inject constructor(
    private val portfolio: PortfolioRepository,
    market: MarketDataRepository,
    settings: SettingsRepository,
) : ViewModel() {
    private val analytics = MutableStateFlow<Map<AccountType, AccountAnalytics>>(emptyMap())
    private val message = MutableStateFlow<String?>(null)

    val state: StateFlow<PortfolioState> = combine(portfolio.observeAccounts(), portfolio.observeLedger(), market.observeInstruments(), combine(analytics, message) { a, m -> a to m }, settings.settings) { acc, l, inst, am, st ->
        PortfolioState(acc, l, inst.associate { it.id to it.symbol }, am.first, st.monthlyEtfContribution, am.second)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), PortfolioState())

    fun loadAnalytics() = viewModelScope.launch {
        analytics.value = AccountType.entries.associateWith { portfolio.analytics(it) }
    }

    fun deposit(a: AccountType, amount: Double) = op { portfolio.deposit(a, amount, "Versamento manuale") }
    fun withdraw(a: AccountType, amount: Double) = op { portfolio.withdraw(a, amount) }
    fun transfer(from: AccountType, amount: Double) = op { portfolio.transfer(from, if (from == AccountType.ETF) AccountType.TRADING else AccountType.ETF, amount) }
    fun dividend(a: AccountType, instrumentId: String, amount: Double) = op { portfolio.dividend(a, instrumentId, amount) }

    private fun op(block: suspend () -> String?) = viewModelScope.launch {
        message.value = block() ?: "Operazione registrata nel registro contabile"
        loadAnalytics()
    }

    fun dismiss() { message.value = null }
}

private enum class CashOp(val label: String) { DEPOSIT("Versa"), WITHDRAW("Preleva"), TRANSFER("Trasferisci"), DIVIDEND("Dividendo") }

@Composable
fun PortfolioScreen(onOpenInstrument: (String) -> Unit, vm: PortfolioViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    var account by rememberSaveable { mutableStateOf(AccountType.ETF) }
    var dialog by remember { mutableStateOf<CashOp?>(null) }
    LaunchedEffect(s.ledger.size) { vm.loadAnalytics() }
    val snap = s.accounts?.let { if (account == AccountType.ETF) it.etf else it.trading }
    MpScreen("Portafoglio", testTag = "portfolio") {
        item { ChipRow(AccountType.entries, account, { it.label }, { account = it }, Modifier.testTag("account_tabs")) }
        item { Text(if (account == AccountType.ETF) "Investimento di lungo periodo in ETF." else "Trading di breve/swing. Rischio per trade e limiti dalle Impostazioni.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
        s.message?.let { m -> item { Banner(m, if (m.startsWith("Operazione")) MpColors.Positive else MpColors.Negative) } }
        if (snap == null) { item { Text("Caricamento…") }; return@MpScreen }
        item { Summary(snap, account, s.monthly) }
        item {
            Row(Modifier.fillMaxWidth()) {
                CashOp.entries.forEach { op ->
                    OutlinedButton(onClick = { dialog = op }, modifier = Modifier.weight(1f).padding(horizontal = 2.dp).testTag("cash_${op.name}")) { Text(op.label, style = MaterialTheme.typography.labelSmall) }
                }
            }
        }
        item { Positions(snap, s.symbols, onOpenInstrument) }
        s.analytics[account]?.let { a -> item { Analytics(a) } }
        item { Ledger(s.ledger.filter { it.account == account }, s.symbols) }
    }
    dialog?.let { op ->
        CashDialog(op, account, snap?.positions?.map { it.position.instrumentId } ?: emptyList(), s.symbols, onDismiss = { dialog = null }) { amount, instrumentId ->
            when (op) {
                CashOp.DEPOSIT -> vm.deposit(account, amount)
                CashOp.WITHDRAW -> vm.withdraw(account, amount)
                CashOp.TRANSFER -> vm.transfer(account, amount)
                CashOp.DIVIDEND -> instrumentId?.let { vm.dividend(account, it, amount) }
            }
            dialog = null
        }
    }
}

@Composable
private fun Summary(s: AccountSnapshot, account: AccountType, monthly: Double) {
    MpCard(Modifier.testTag("account_summary")) {
        SectionTitle(account.label)
        Text(Fmt.eur(s.equityEur), style = MaterialTheme.typography.headlineMedium, modifier = Modifier.testTag("equity_value"))
        s.totalReturnPct?.let { Text("Rendimento totale ${Fmt.eur(s.totalReturnEur)} (${Fmt.pct(it)})", color = changeColor(it)) }
        MetricRow("Liquidità", Fmt.eur(s.cashEur))
        MetricRow("Liquidità disponibile", Fmt.eur(s.availableCashEur))
        MetricRow("Riservata da ordini in attesa", Fmt.eur(s.reservedEur))
        MetricRow("Investito (valore di mercato)", Fmt.eur(s.investedValueEur))
        MetricRow("P&L non realizzato", Fmt.eur(s.unrealizedPnlEur), valueColor = changeColor(s.unrealizedPnlEur))
        MetricRow("P&L realizzato", Fmt.eur(s.realizedPnlEur), valueColor = changeColor(s.realizedPnlEur))
        MetricRow("Versamenti netti", Fmt.eur(s.netContributionsEur))
        MetricRow("Commissioni e costi di cambio", Fmt.eur(s.feesEur))
        MetricRow("Dividendi", Fmt.eur(s.dividendsEur))
        if (account == AccountType.ETF) MetricRow("PAC mensile pianificato", Fmt.eur(monthly))
        if (s.unpricedInstruments.isNotEmpty()) Banner("Senza prezzo (esclusi dal valore): ${s.unpricedInstruments.joinToString()}")
        if (s.equityEur == 0.0) Text("Capitale non configurato: usa Versa per aggiungere capitale virtuale.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    }
}

@Composable
private fun Positions(s: AccountSnapshot, symbols: Map<String, String>, onOpen: (String) -> Unit) {
    MpCard {
        SectionTitle("Posizioni aperte")
        if (s.positions.isEmpty()) Text("Nessuna posizione.", color = MpColors.TextSecondary)
        s.positions.forEach { p ->
            Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(symbols[p.position.instrumentId] ?: p.position.instrumentId, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Text(Fmt.eur(p.marketValueEur), fontWeight = FontWeight.Medium)
                }
                Text(
                    "${Fmt.num(p.position.quantity, 0)} quote · prezzo medio ${Fmt.money(p.position.avgPriceCcy, p.position.currency)} · costo medio ${Fmt.eur(p.position.avgCostEur)}",
                    style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary,
                )
                p.unrealizedPnlEur?.let { Text("P&L ${Fmt.eur(it)} (${Fmt.pct(p.unrealizedPnlPct)}) · valutato al ${Fmt.date(p.mark?.date)}", style = MaterialTheme.typography.bodySmall, color = changeColor(it)) }
                TextButton(onClick = { onOpen(p.position.instrumentId) }) { Text("Dettagli") }
            }
        }
    }
}

@Composable
private fun Analytics(a: AccountAnalytics) {
    MpCard(Modifier.testTag("analytics")) {
        SectionTitle("Analisi delle performance")
        if (a.curve.size >= 2) {
            LineChart(listOf(Overlay("Portafoglio", a.curve.map { it.equityEur }, MpColors.Positive), Overlay(a.benchmarkLabel, a.benchmark.map { it.equityEur }, MpColors.Info, dashed = true)))
            MetricRow("Variazione dell'ultima seduta (al netto dei versamenti)", Fmt.eur(a.dailyChangeEur), valueColor = changeColor(a.dailyChangeEur))
            MetricRow("Drawdown massimo", Fmt.pct(a.maxDrawdown))
            a.benchmark.lastOrNull()?.let { b -> MetricRow("Valore benchmark (${a.benchmarkLabel})", Fmt.eur(b.equityEur)) }
        } else Text("Curva disponibile dopo almeno due sedute con movimenti.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        val st = a.stats
        MetricRow("Operazioni chiuse", st.trades.toString())
        MetricRow("Percentuale vincenti", Fmt.pct(st.winRate, 0, signed = false))
        MetricRow("Profit factor", st.profitFactor?.let { Fmt.num(it) } ?: "n/d")
        MetricRow("Expectancy per operazione", Fmt.eur(st.expectancyEur))
        MetricRow("Guadagno medio / perdita media", "${Fmt.eur(st.averageWinEur)} / ${Fmt.eur(st.averageLossEur)}")
        if (a.closedTrades.isNotEmpty()) {
            Text("Ultime operazioni chiuse", fontWeight = FontWeight.SemiBold)
            a.closedTrades.takeLast(8).reversed().forEach { t ->
                Text("${t.instrumentId}: ${Fmt.eur(t.pnlEur)} (${Fmt.pct(t.returnPct)}) chiusa il ${Fmt.date(t.exitDate)}", style = MaterialTheme.typography.bodySmall, color = changeColor(t.pnlEur))
            }
        }
    }
}

@Composable
private fun Ledger(entries: List<LedgerEntry>, symbols: Map<String, String>) {
    MpCard {
        SectionTitle("Registro contabile (verificabile)")
        if (entries.isEmpty()) Text("Nessun movimento.", color = MpColors.TextSecondary)
        entries.sortedByDescending { it.createdAt }.take(40).forEach { e ->
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(e.kind.label + (e.instrumentId?.let { " · ${symbols[it] ?: it}" } ?: ""), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                    Text("${Fmt.date(e.sessionDate)}" + (e.note?.let { " · $it" } ?: "") + (e.transferId?.let { " · rif. trasferimento ${it.take(8)}" } ?: ""), style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                }
                Text(Fmt.eur(e.amountEur), color = changeColor(e.amountEur), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun CashDialog(op: CashOp, account: AccountType, positions: List<String>, symbols: Map<String, String>, onDismiss: () -> Unit, onConfirm: (Double, String?) -> Unit) {
    var amount by remember { mutableStateOf("") }
    var instrument by remember { mutableStateOf(positions.firstOrNull()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(op.label + " · " + account.label) },
        text = {
            Column {
                NumberField("Importo", amount, { amount = it }, suffix = "€", tag = "cash_amount")
                if (op == CashOp.TRANSFER) Text("Verso ${if (account == AccountType.ETF) AccountType.TRADING.label else AccountType.ETF.label}. Il trasferimento è registrato su entrambi i conti con lo stesso riferimento.", style = MaterialTheme.typography.bodySmall)
                if (op == CashOp.DIVIDEND) {
                    if (positions.isEmpty()) Text("Nessuna posizione aperta.") else ChipRow(positions, instrument ?: positions.first(), { symbols[it] ?: it }, { instrument = it })
                    Text("Importo netto ricevuto in EUR, inserito manualmente.", style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = { Button(onClick = { onConfirm(amount.toDoubleOrZero(), instrument) }, modifier = Modifier.testTag("cash_confirm")) { Text("Conferma") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annulla") } },
    )
}
