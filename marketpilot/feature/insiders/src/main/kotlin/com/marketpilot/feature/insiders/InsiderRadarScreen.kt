package com.marketpilot.feature.insiders

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.scoreColor
import com.marketpilot.core.model.HoldingChange
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.domain.scoring.InsiderConviction
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.time.LocalDate
import javax.inject.Inject

data class InsiderState(val transactions: List<InsiderTransaction> = emptyList(), val holdings: List<InstitutionalHolding> = emptyList())

@HiltViewModel
class InsiderViewModel @Inject constructor(analysis: AnalysisRepository) : ViewModel() {
    val state: StateFlow<InsiderState> = combine(analysis.observeInsiders(LocalDate.now().minusDays(90)), analysis.observeHoldings()) { t, h ->
        InsiderState(t, h)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InsiderState())
}

private enum class Tab(val label: String) { PURCHASES("Acquisti sul mercato"), ALL("Tutte le operazioni"), INSTITUTIONAL("Istituzionali 13F") }

fun typeLabel(t: InsiderTransactionType) = when (t) {
    InsiderTransactionType.OPEN_MARKET_PURCHASE -> "Acquisto sul mercato (P)"
    InsiderTransactionType.OPEN_MARKET_SALE -> "Vendita sul mercato (S)"
    InsiderTransactionType.GRANT_OR_AWARD -> "Assegnazione (A)"
    InsiderTransactionType.OPTION_EXERCISE -> "Esercizio/conversione (M)"
    InsiderTransactionType.TAX_WITHHOLDING -> "Ritenuta fiscale (F)"
    InsiderTransactionType.GIFT -> "Donazione (G)"
    InsiderTransactionType.OTHER -> "Altro"
}

@Composable
fun InsiderRadarScreen(onBack: () -> Unit, onOpenStock: (String) -> Unit, vm: InsiderViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(Tab.PURCHASES) }
    val uri = LocalUriHandler.current
    MpScreen("Insider e istituzionali", onBack = onBack, testTag = "insiders") {
        item { ChipRow(Tab.entries, tab, { it.label }, { tab = it }) }
        when (tab) {
            Tab.PURCHASES -> {
                item { Banner("Solo acquisti sul mercato (codice P) non legati a piani automatici 10b5-1. I Form 4 sono depositati fino a 2 giorni lavorativi dopo l'operazione.", MpColors.Info) }
                val bySymbol = s.transactions.groupBy { it.issuerSymbol }
                    .mapValues { (_, tx) -> InsiderConviction.score(tx, LocalDate.now(), 90) }
                    .filter { it.value.purchases.isNotEmpty() }
                    .toList().sortedByDescending { it.second.score }
                if (bySymbol.isEmpty()) item { Text("Nessun acquisto significativo negli ultimi 90 giorni tra i filing scaricati.", color = MpColors.TextSecondary) }
                bySymbol.forEach { (sym, sig) ->
                    item(key = "p_$sym") {
                        MpCard(onClick = { onOpenStock(InstrumentCatalog.stockId(sym)) }) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(sym, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                                Pill("Conviction ${sig.score.toInt()}", scoreColor(sig.score))
                            }
                            Text(sig.explanation, style = MaterialTheme.typography.bodySmall)
                            sig.purchases.take(4).forEach { p ->
                                Text("• ${p.insiderName} (${p.insiderRole}): ${Fmt.num(p.shares, 0)} az. a ${Fmt.num(p.pricePerShare)} il ${Fmt.date(p.transactionDate)}, depositato ${Fmt.date(p.filingDate)}", style = MaterialTheme.typography.bodySmall)
                            }
                            sig.purchases.firstOrNull()?.let { p -> TextButton(onClick = { runCatching { uri.openUri(p.filingUrl) } }) { Text("Filing originale SEC") } }
                        }
                    }
                }
            }
            Tab.ALL -> {
                if (s.transactions.isEmpty()) item { Text("Nessuna operazione scaricata.", color = MpColors.TextSecondary) }
                s.transactions.take(200).forEachIndexed { i, t ->
                    item(key = "a_${t.accessionNumber}_$i") {
                        MpCard {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(t.issuerSymbol, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                                Pill(typeLabel(t.type), if (t.type == InsiderTransactionType.OPEN_MARKET_PURCHASE) MpColors.Positive else if (t.type == InsiderTransactionType.OPEN_MARKET_SALE) MpColors.Negative else MpColors.TextSecondary)
                            }
                            Text("${t.insiderName} · ${t.insiderRole}", style = MaterialTheme.typography.bodySmall)
                            Text(
                                "${if (t.acquiredDisposed == "A") "Acquisite" else "Cedute"} ${Fmt.num(t.shares, 0)} az." + (t.pricePerShare?.let { " a ${Fmt.num(it)} (${Fmt.compact(t.dollarValue)} USD)" } ?: "") +
                                    " · proprietà ${if (t.ownershipType == "I") "indiretta" else "diretta"}" + (if (t.isRule10b51Plan) " · piano 10b5-1 (automatico)" else ""),
                                style = MaterialTheme.typography.bodySmall,
                            )
                            Text("Operazione ${Fmt.date(t.transactionDate)} · deposito ${Fmt.date(t.filingDate)} (ritardo ${t.filingDelayDays} gg)", style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                            TextButton(onClick = { runCatching { uri.openUri(t.filingUrl) } }) { Text("Filing SEC") }
                        }
                    }
                }
            }
            Tab.INSTITUTIONAL -> {
                item { Banner("I 13F sono trimestrali e depositati fino a 45 giorni dopo la fine del trimestre: mostrano posizioni passate, non operazioni in tempo reale. Gestori monitorati: elenco predefinito modificabile.", MpColors.Warning) }
                item { TextButton(onClick = { runCatching { uri.openUri("https://www.dataroma.com/m/home.php") } }) { Text("Riferimento esterno: Dataroma (superinvestitori)") } }
                val byManager = s.holdings.groupBy { it.managerName }
                if (byManager.isEmpty()) item { Text("13F non ancora scaricati: esegui un aggiornamento (download settimanale).", color = MpColors.TextSecondary) }
                byManager.forEach { (manager, list) ->
                    item(key = "m_$manager") {
                        MpCard {
                            Text(manager, style = MaterialTheme.typography.titleMedium)
                            val first = list.first()
                            Text("Periodo ${Fmt.date(first.periodOfReport)} · depositato ${Fmt.date(first.filingDate)} · ${list.count { it.shares > 0 }} posizioni", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                            val changes = list.filter { it.change in setOf(HoldingChange.NEW, HoldingChange.INCREASED, HoldingChange.REDUCED, HoldingChange.SOLD_OUT) }.sortedByDescending { it.valueUsd }
                            changes.take(10).forEach { h ->
                                val c = when (h.change) { HoldingChange.NEW -> "NUOVA"; HoldingChange.INCREASED -> "AUMENTATA"; HoldingChange.REDUCED -> "RIDOTTA"; HoldingChange.SOLD_OUT -> "VENDUTA"; else -> "" }
                                Text("• ${h.symbol ?: h.issuerName}: $c (${Fmt.compact(h.previousShares)} → ${Fmt.compact(h.shares)} az.)", style = MaterialTheme.typography.bodySmall,
                                    color = if (h.change == HoldingChange.NEW || h.change == HoldingChange.INCREASED) MpColors.Positive else MpColors.Negative)
                            }
                            Column(Modifier.padding(top = 4.dp)) {
                                list.filter { it.shares > 0 }.sortedByDescending { it.valueUsd }.take(5).forEach { h ->
                                    Text("${h.symbol ?: h.issuerName}: ${Fmt.compact(h.valueUsd)} USD", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                                }
                            }
                            TextButton(onClick = { runCatching { uri.openUri(first.filingUrl) } }) { Text("Filing SEC") }
                        }
                    }
                }
            }
        }
    }
}
