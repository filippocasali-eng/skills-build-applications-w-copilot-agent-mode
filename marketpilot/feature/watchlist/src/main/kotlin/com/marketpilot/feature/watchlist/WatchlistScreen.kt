package com.marketpilot.feature.watchlist

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.database.AlertEntity
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.changeColor
import com.marketpilot.core.designsystem.recommendationColor
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.Recommendation
import com.marketpilot.data.repositories.AlertRepository
import com.marketpilot.data.repositories.AlertType
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.OnDemandRepository
import com.marketpilot.data.repositories.StockScoreDto
import com.marketpilot.data.repositories.StoredQuote
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class WatchRow(val instrument: Instrument, val quote: StoredQuote?, val score: StockScoreDto?, val lastClose: Double?)

data class WatchState(val rows: List<WatchRow> = emptyList(), val alerts: List<AlertEntity> = emptyList(), val names: Map<String, String> = emptyMap(), val message: String? = null)

@HiltViewModel
class WatchlistViewModel @Inject constructor(
    private val market: MarketDataRepository,
    analysis: AnalysisRepository,
    private val alerts: AlertRepository,
    private val onDemand: OnDemandRepository,
) : ViewModel() {
    private val message = MutableStateFlow<String?>(null)
    val state: StateFlow<WatchState> = combine(
        combine(market.observeWatchlist(), market.observeInstruments(), market.observeQuotes()) { w, i, q -> Triple(w, i, q) },
        analysis.observeStockScores(), alerts.observe(), message,
    ) { (w, inst, q), scores, al, msg ->
        val byId = inst.associateBy { it.id }
        WatchState(
            rows = w.mapNotNull { id -> byId[id]?.let { WatchRow(it, q[id], scores.firstOrNull { s -> s.instrumentId == id }, null) } },
            alerts = al,
            names = inst.associate { it.id to it.symbol },
            message = msg,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), WatchState())

    fun add(ticker: String) = viewModelScope.launch {
        val inst = onDemand.resolveTicker(ticker)
        if (inst == null) { message.value = "Ticker non valido"; return@launch }
        market.addToWatchlist(inst.id)
        message.value = "${inst.symbol} aggiunto. I dati verranno scaricati al prossimo aggiornamento o aprendo la scheda."
    }

    fun remove(id: String) = viewModelScope.launch { market.removeFromWatchlist(id) }
    fun toggleAlert(a: AlertEntity, enabled: Boolean) = viewModelScope.launch { alerts.setEnabled(a, enabled) }
    fun deleteAlert(id: Long) = viewModelScope.launch { alerts.delete(id) }
}

@Composable
fun WatchlistScreen(onBack: () -> Unit, onOpen: (Instrument) -> Unit, vm: WatchlistViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    var ticker by remember { mutableStateOf("") }
    MpScreen("Watchlist e avvisi", onBack = onBack, testTag = "watchlist") {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(ticker, { ticker = it.uppercase() }, label = { Text("Aggiungi ticker USA (es. AAPL)") }, singleLine = true, modifier = Modifier.weight(1f).testTag("watch_input"))
                Spacer(Modifier.width(8.dp))
                Button(onClick = { vm.add(ticker); ticker = "" }, enabled = ticker.isNotBlank(), modifier = Modifier.testTag("watch_add")) { Text("Aggiungi") }
            }
        }
        s.message?.let { item { Banner(it, MpColors.Info) } }
        if (s.rows.isEmpty()) item { Text("La watchlist è vuota.", color = MpColors.TextSecondary) }
        s.rows.forEach { r ->
            item(key = r.instrument.id) {
                MpCard(onClick = { onOpen(r.instrument) }, modifier = Modifier.testTag("watch_${r.instrument.symbol}")) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(r.instrument.symbol, style = MaterialTheme.typography.titleMedium)
                            Text(r.instrument.name, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 1)
                            r.quote?.let { q ->
                                Row {
                                    Text(Fmt.money(q.quote.price, q.quote.currency), fontWeight = FontWeight.SemiBold)
                                    Spacer(Modifier.width(6.dp))
                                    q.quote.changePercent?.let { Text(Fmt.pct(it / 100), color = changeColor(it)) }
                                }
                                Text(Fmt.dateTime(q.quote.observedAt), style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                            } ?: Text("Prezzo non ancora scaricato", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                        }
                        r.score?.let { sc -> Pill(Recommendation.valueOf(sc.recommendation).label, recommendationColor(Recommendation.valueOf(sc.recommendation))) }
                        IconButton(onClick = { vm.remove(r.instrument.id) }) { Icon(Icons.Outlined.Delete, contentDescription = "Rimuovi ${r.instrument.symbol}") }
                    }
                }
            }
        }
        item { SectionTitle("Avvisi") }
        item {
            Banner(
                "Gli avvisi sono verificati a ogni aggiornamento, manuale o in background. Android può ritardare i job in background (Doze, ottimizzazione batteria): " +
                    "gli avvisi non sono in tempo reale. Per maggiore affidabilità escludi l'app dall'ottimizzazione della batteria. Avvisi automatici: esecuzioni simulate, acquisti insider e trimestrali dei titoli in watchlist.",
                MpColors.Info,
            )
        }
        if (s.alerts.isEmpty()) item { Text("Nessun avviso. Creane uno dalla scheda di un titolo.", color = MpColors.TextSecondary) }
        s.alerts.forEach { a ->
            item(key = "alert_${a.id}") {
                MpCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("${s.names[a.instrumentId] ?: a.instrumentId} · ${runCatching { AlertType.valueOf(a.type).label }.getOrDefault(a.type)} ${Fmt.num(a.threshold)}", fontWeight = FontWeight.Medium)
                            a.lastTriggeredAtMs?.let { Text("Ultimo: ${Fmt.dateTime(java.time.Instant.ofEpochMilli(it))}", style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary) }
                        }
                        Switch(checked = a.enabled, onCheckedChange = { vm.toggleAlert(a, it) })
                        IconButton(onClick = { vm.deleteAlert(a.id) }) { Icon(Icons.Outlined.Delete, contentDescription = "Elimina avviso") }
                    }
                }
            }
        }
    }
}
