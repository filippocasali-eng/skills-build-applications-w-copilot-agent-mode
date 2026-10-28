package com.marketpilot.feature.journal

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.database.JournalEntryEntity
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MetricRow
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.changeColor
import com.marketpilot.core.designsystem.recommendationColor
import com.marketpilot.data.repositories.DecisionTrackerRepository
import com.marketpilot.data.repositories.JournalRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.TrackerOverview
import com.marketpilot.domain.backtesting.SnapshotKind
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

@HiltViewModel
class JournalViewModel @Inject constructor(
    handle: SavedStateHandle,
    private val journal: JournalRepository,
    market: MarketDataRepository,
) : ViewModel() {
    val prefillInstrument: String? = handle["instrumentId"]
    val entries: StateFlow<Pair<List<JournalEntryEntity>, Map<String, String>>> = combine(journal.observe(), market.observeInstruments()) { e, i -> e to i.associate { it.id to it.symbol } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList<JournalEntryEntity>() to emptyMap())

    fun save(id: Long?, title: String, body: String, instrumentId: String?, setup: String, emotion: String, lessons: String, tags: String) = viewModelScope.launch {
        journal.save(id, title.ifBlank { "Nota" }, body, instrumentId, null, null, setup.ifBlank { null }, emotion.ifBlank { null }, lessons.ifBlank { null },
            tags.split(',').map { it.trim() }.filter { it.isNotEmpty() })
    }

    fun delete(id: Long) = viewModelScope.launch { journal.delete(id) }
}

@Composable
fun JournalScreen(onBack: () -> Unit, onTracker: () -> Unit, vm: JournalViewModel = hiltViewModel()) {
    val (entries, symbols) = vm.entries.collectAsStateWithLifecycle().value
    var editing by remember { mutableStateOf<JournalEntryEntity?>(null) }
    var creating by rememberSaveable { mutableStateOf(vm.prefillInstrument != null) }
    MpScreen(
        "Diario di trading", onBack = onBack, testTag = "journal",
        floating = { ExtendedFloatingActionButton(onClick = { creating = true }, icon = { Icon(Icons.Filled.Add, null) }, text = { Text("Nuova nota") }, modifier = Modifier.testTag("journal_new")) },
    ) {
        item { TextButton(onClick = onTracker) { Text("Apri lo storico delle decisioni del modello →") } }
        if (entries.isEmpty()) item { Text("Nessuna nota. Registra motivazioni, emozioni e lezioni di ogni operazione simulata.", color = MpColors.TextSecondary) }
        entries.forEach { e ->
            item(key = e.id) {
                MpCard(onClick = { editing = e }, modifier = Modifier.testTag("journal_entry")) {
                    Text(e.title, style = MaterialTheme.typography.titleMedium)
                    Text("${Fmt.dateTime(Instant.ofEpochMilli(e.createdAtMs))}" + (e.instrumentId?.let { " · ${symbols[it] ?: it}" } ?: ""), style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                    if (e.body.isNotBlank()) Text(e.body, style = MaterialTheme.typography.bodyMedium, maxLines = 4)
                    e.setup?.let { Text("Setup: $it", style = MaterialTheme.typography.bodySmall) }
                    e.emotion?.let { Text("Stato emotivo: $it", style = MaterialTheme.typography.bodySmall) }
                    e.lessons?.let { Text("Lezioni: $it", style = MaterialTheme.typography.bodySmall, color = MpColors.Info) }
                    if (e.tagsCsv.isNotBlank()) Row { e.tagsCsv.split(',').forEach { Pill(it, MpColors.TextSecondary, Modifier.padding(end = 4.dp)) } }
                }
            }
        }
    }
    if (creating || editing != null) {
        EntryDialog(editing, vm.prefillInstrument, onDismiss = { creating = false; editing = null }, onDelete = editing?.let { e -> { vm.delete(e.id); editing = null } }) { title, body, setup, emotion, lessons, tags ->
            vm.save(editing?.id, title, body, editing?.instrumentId ?: vm.prefillInstrument, setup, emotion, lessons, tags)
            creating = false; editing = null
        }
    }
}

@Composable
private fun EntryDialog(e: JournalEntryEntity?, instrument: String?, onDismiss: () -> Unit, onDelete: (() -> Unit)?, onSave: (String, String, String, String, String, String) -> Unit) {
    var title by remember { mutableStateOf(e?.title ?: instrument?.substringBefore(':')?.let { "Nota su $it" } ?: "") }
    var body by remember { mutableStateOf(e?.body ?: "") }
    var setup by remember { mutableStateOf(e?.setup ?: "") }
    var emotion by remember { mutableStateOf(e?.emotion ?: "") }
    var lessons by remember { mutableStateOf(e?.lessons ?: "") }
    var tags by remember { mutableStateOf(e?.tagsCsv ?: "") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (e == null) "Nuova nota" else "Modifica nota") },
        text = {
            Column {
                OutlinedTextField(title, { title = it }, label = { Text("Titolo") }, singleLine = true, modifier = Modifier.fillMaxWidth().testTag("journal_title"))
                OutlinedTextField(body, { body = it }, label = { Text("Motivazione / note") }, minLines = 3, modifier = Modifier.fillMaxWidth().testTag("journal_body"))
                OutlinedTextField(setup, { setup = it }, label = { Text("Setup") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(emotion, { emotion = it }, label = { Text("Stato emotivo") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(lessons, { lessons = it }, label = { Text("Lezioni apprese") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(tags, { tags = it }, label = { Text("Tag (separati da virgola)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = { Button(onClick = { onSave(title, body, setup, emotion, lessons, tags) }, modifier = Modifier.testTag("journal_save")) { Text("Salva") } },
        dismissButton = {
            Row {
                onDelete?.let { TextButton(onClick = it) { Text("Elimina", color = MpColors.Negative) } }
                TextButton(onClick = onDismiss) { Text("Annulla") }
            }
        },
    )
}

// -------------------------------------------------------------------------------------------------
@HiltViewModel
class TrackerViewModel @Inject constructor(private val tracker: DecisionTrackerRepository, market: MarketDataRepository) : ViewModel() {
    val kind = MutableStateFlow<SnapshotKind?>(SnapshotKind.STOCK)
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    val state: StateFlow<Pair<TrackerOverview?, Map<String, String>>> = combine(kind.flatMapLatest { tracker.observeOverview(it) }, market.observeInstruments()) { o, i -> o to i.associate { it.id to it.symbol } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null to emptyMap())

    fun evaluate() = viewModelScope.launch { tracker.evaluatePending() }
}

@Composable
fun DecisionTrackerScreen(onBack: () -> Unit, vm: TrackerViewModel = hiltViewModel()) {
    val (o, symbols) = vm.state.collectAsStateWithLifecycle().value
    val kind by vm.kind.collectAsStateWithLifecycle()
    MpScreen("Storico decisioni", onBack = onBack, testTag = "tracker") {
        item {
            Banner(
                "Ogni valutazione giornaliera completata viene salvata come snapshot immutabile e valutata dopo 1, 5, 20, 60 e 90 sedute di borsa. " +
                    "Una raccomandazione è considerata corretta solo se batte il benchmark (SPY) al netto dei costi, non semplicemente se il prezzo sale. Tutti gli snapshot sono inclusi.",
                MpColors.Info,
            )
        }
        item { ChipRow(listOf<SnapshotKind?>(SnapshotKind.STOCK, SnapshotKind.ETF, SnapshotKind.MARKET, null), kind, { it?.name ?: "TUTTI" }, { vm.kind.value = it }) }
        if (o == null) { item { Text("Caricamento…") }; return@MpScreen }
        item {
            MpCard {
                MetricRow("Snapshot salvati", o.snapshots.toString())
                MetricRow("Con almeno un esito valutato", o.evaluated.toString())
                TextButton(onClick = vm::evaluate) { Text("Rivaluta ora") }
                if (o.evaluated == 0) Text("Gli esiti richiedono che trascorrano sedute dopo lo snapshot: i primi risultati compaiono dal giorno di borsa successivo.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            }
        }
        o.summaries.filter { it.evaluated > 0 }.forEach { sm ->
            item(key = "h${sm.horizon}") {
                MpCard {
                    SectionTitle("Orizzonte ${sm.horizon} sedute · ${sm.evaluated} valutazioni")
                    MetricRow("Chiamate direzionali (Candidato/Osserva)", sm.directionalCalls.toString())
                    MetricRow("Accuratezza vs SPY", Fmt.pct(sm.directionalAccuracy, 0, signed = false))
                    MetricRow("Rendimento netto medio", Fmt.pct(sm.avgNetReturnDirectional), valueColor = changeColor(sm.avgNetReturnDirectional))
                    MetricRow("Extra-rendimento medio vs SPY", Fmt.pct(sm.avgExcessDirectional), valueColor = changeColor(sm.avgExcessDirectional))
                    MetricRow("Valore delle astensioni (Attendi/Nessun trade)", Fmt.pct(sm.avoidanceValue))
                    MetricRow("Stop toccato per primo", Fmt.pct(sm.stopFirstRate, 0, signed = false))
                    if (sm.ambiguousCount > 0) MetricRow("Esiti ambigui (stop e target nella stessa seduta)", sm.ambiguousCount.toString())
                    Text("Calibrazione per fascia di punteggio", fontWeight = FontWeight.SemiBold)
                    sm.buckets.filter { it.count > 0 }.forEach { b ->
                        Text("${b.bucket.label}: n=${b.count}, rend. medio ${Fmt.pct(b.avgNetReturn)}, positivi ${Fmt.pct(b.hitRate, 0, signed = false)}, vs SPY ${Fmt.pct(b.avgExcessVsBenchmark)}", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        item { SectionTitle("Snapshot recenti") }
        o.recent.take(40).forEach { (snap, outcomes) ->
            item(key = snap.id) {
                MpCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${symbols[snap.instrumentId] ?: snap.instrumentId} · ${Fmt.date(snap.assessmentDate)}", fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                        Pill(snap.recommendation.label, recommendationColor(snap.recommendation))
                    }
                    Text("Score ${snap.score?.toInt() ?: "n/d"} · prezzo ${Fmt.num(snap.price)} · regime ${snap.regime.label} · ${snap.modelVersion}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                    outcomes.sortedBy { it.horizonSessions }.forEach { h ->
                        Text("${h.horizonSessions}s: ${Fmt.pct(h.netReturn)} netto · SPY ${Fmt.pct(h.benchmarkReturns["SPY"])} · MAE ${Fmt.pct(h.maxAdverseExcursion)} · MFE ${Fmt.pct(h.maxFavorableExcursion)}",
                            style = MaterialTheme.typography.bodySmall, color = changeColor(h.netReturn))
                    }
                }
            }
        }
    }
}
