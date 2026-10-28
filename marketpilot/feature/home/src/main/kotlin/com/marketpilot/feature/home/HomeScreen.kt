package com.marketpilot.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.common.SessionStatus
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.DISCLAIMER
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.ScoreGauge
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.WhyExpandable
import com.marketpilot.core.designsystem.changeColor
import com.marketpilot.core.designsystem.recommendationColor
import com.marketpilot.core.designsystem.regimeColor
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.ProviderOperationalState
import com.marketpilot.core.model.ProviderStatus
import com.marketpilot.core.model.Recommendation
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.EtfAnalysisDto
import com.marketpilot.data.repositories.MarketAssessmentView
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.RefreshEngine
import com.marketpilot.data.repositories.RefreshOutcome
import com.marketpilot.data.repositories.RefreshState
import com.marketpilot.data.repositories.RefreshTrigger
import com.marketpilot.data.repositories.StockScoreDto
import com.marketpilot.data.repositories.StoredQuote
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject

data class HomeState(
    val today: LocalDate,
    val session: SessionStatus,
    val assessment: MarketAssessmentView? = null,
    val lastRefresh: Instant? = null,
    val refresh: RefreshState = RefreshState.Idle,
    val topStocks: List<StockScoreDto> = emptyList(),
    val noTradeReason: String? = null,
    val bestEtf: EtfAnalysisDto? = null,
    val etfNames: Map<String, String> = emptyMap(),
    val news: List<NewsItem> = emptyList(),
    val providers: List<ProviderStatus> = emptyList(),
    val quotes: Map<String, StoredQuote> = emptyMap(),
    val tradingEquity: Double? = null,
    val etfEquity: Double? = null,
    val message: String? = null,
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val engine: RefreshEngine,
    analysis: AnalysisRepository,
    market: MarketDataRepository,
    portfolio: PortfolioRepository,
    private val clock: AppClock,
) : ViewModel() {
    private val message = MutableStateFlow<String?>(null)

    private val base = combine(
        analysis.observeAssessment(), market.observeLastSuccessfulRefresh(), engine.state, analysis.observeStockScores(), analysis.observeEtfAnalyses(),
    ) { a, last, r, stocks, etfs -> listOf(a, last, r, stocks, etfs) }

    private val extra = combine(analysis.observeNews(60), market.observeProviderStatus(), market.observeQuotes(), portfolio.observeAccounts(), market.observeInstruments()) { n, p, q, acc, inst ->
        listOf(n, p, q, acc, inst)
    }

    @Suppress("UNCHECKED_CAST")
    val state: StateFlow<HomeState> = combine(base, extra, message) { b, e, msg ->
        val now = clock.now()
        val stocks = b[3] as List<StockScoreDto>
        val etfs = b[4] as List<EtfAnalysisDto>
        val candidates = stocks.filter { it.recommendation == Recommendation.BUY_CANDIDATE.name }
        val accounts = e[3] as com.marketpilot.data.repositories.Accounts
        val instruments = e[4] as List<com.marketpilot.core.model.Instrument>
        HomeState(
            today = now.atZone(AppClock.DISPLAY_ZONE).toLocalDate(),
            session = MarketSessions.status(Calendars.NYSE, now),
            assessment = b[0] as MarketAssessmentView?,
            lastRefresh = b[1] as Instant?,
            refresh = b[2] as RefreshState,
            topStocks = candidates.take(3),
            noTradeReason = if (stocks.isNotEmpty() && candidates.isEmpty()) "Nessun candidato soddisfa insieme punteggio, fiducia e rapporto rischio/rendimento." else null,
            bestEtf = etfs.filter { inst -> instruments.firstOrNull { it.id == inst.instrumentId }?.isUcits == true && inst.opportunityScore != null }.maxByOrNull { it.opportunityScore!! },
            etfNames = instruments.associate { it.id to it.symbol },
            news = (e[0] as List<NewsItem>).sortedByDescending { it.relevance }.take(3),
            providers = e[1] as List<ProviderStatus>,
            quotes = e[2] as Map<String, StoredQuote>,
            tradingEquity = accounts.trading.equityEur,
            etfEquity = accounts.etf.equityEur,
            message = msg,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeState(LocalDate.now(), MarketSessions.status(Calendars.NYSE, clock.now())))

    fun refresh() {
        viewModelScope.launch {
            message.value = when (val r = engine.refresh(RefreshTrigger.MANUAL)) {
                RefreshOutcome.AlreadyRunning -> "Aggiornamento già in corso"
                is RefreshOutcome.Done -> if (r.status == "COMPLETED") "Aggiornamento completato" else "Aggiornamento parziale: alcuni dati non sono stati aggiornati (dettagli nel riepilogo)"
            }
        }
    }

    fun cancel() = engine.cancel()
    fun dismissMessage() { message.value = null }
}

@Composable
fun HomeScreen(
    onOpenStock: (String) -> Unit,
    onOpenEtf: (String) -> Unit,
    onNavigate: (String) -> Unit,
    vm: HomeViewModel = hiltViewModel(),
) {
    val s by vm.state.collectAsStateWithLifecycle()
    var menu by remember { mutableStateOf(false) }
    MpScreen(
        title = "Oggi",
        testTag = "home",
        actions = {
            IconButton(onClick = { menu = true }, modifier = Modifier.testTag("home_menu")) { Icon(Icons.Filled.MoreVert, contentDescription = "Altre sezioni") }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                listOf(
                    "watchlist" to "Watchlist e avvisi", "news" to "Notizie", "insiders" to "Insider e istituzionali", "reddit" to "Reddit Radar",
                    "journal" to "Diario di trading", "tracker" to "Storico decisioni", "datasources" to "Fonti dati", "settings" to "Impostazioni",
                ).forEach { (route, label) -> DropdownMenuItem(text = { Text(label) }, onClick = { menu = false; onNavigate(route) }, modifier = Modifier.testTag("menu_$route")) }
            }
        },
    ) {
        item { Header(s) }
        item { RefreshCard(s, vm::refresh, vm::cancel) }
        s.message?.let { m -> item { Banner(m, if (m.startsWith("Aggiornamento completato")) MpColors.Positive else MpColors.Warning) } }
        item { RegimeCard(s.assessment) }
        item { ScoresCard(s.assessment) }
        item { RisksCard(s.assessment) }
        item { OpportunitiesCard(s, onOpenStock, onNavigate) }
        item { EtfCard(s, onOpenEtf) }
        item { PortfolioCard(s, onNavigate) }
        item { NewsCard(s.news, onNavigate) }
        item { DataQualityCard(s, onNavigate) }
        item { Text(DISCLAIMER, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
    }
}

@Composable
private fun Header(s: HomeState) {
    Column {
        Text(Fmt.date(s.today).replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.headlineMedium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Pill(s.session.phase.label + " · NYSE", if (s.session.phase.name == "OPEN") MpColors.Positive else MpColors.TextSecondary)
            Spacer(Modifier.width(8.dp))
            Text("Ora NY ${s.session.localNow.toLocalTime().withNano(0).withSecond(0)}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        }
        Text(
            "Ultimo aggiornamento riuscito: ${s.lastRefresh?.let { Fmt.dateTime(it) } ?: "mai"}",
            style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, modifier = Modifier.testTag("last_refresh"),
        )
    }
}

@Composable
private fun RefreshCard(s: HomeState, onRefresh: () -> Unit, onCancel: () -> Unit) {
    val running = s.refresh as? RefreshState.Running
    if (running != null) {
        MpCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Determinate (step-based) progress: no infinite animation, so UI tests can reach idle.
                CircularProgressIndicator(
                    progress = { running.step.toFloat() / running.totalSteps.coerceAtLeast(1) },
                    modifier = Modifier.size(22.dp), strokeWidth = 2.dp, color = MpColors.Positive,
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text("Aggiornamento in corso (${running.step}/${running.totalSteps})", fontWeight = FontWeight.SemiBold)
                    Text(running.label, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                }
                OutlinedButton(onClick = onCancel, modifier = Modifier.testTag("refresh_cancel")) { Text("Annulla") }
            }
        }
    } else {
        Button(
            onClick = onRefresh, modifier = Modifier.fillMaxWidth().height(52.dp).testTag("refresh_button"),
            colors = ButtonDefaults.buttonColors(containerColor = MpColors.Positive),
        ) {
            Icon(Icons.Filled.Refresh, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("AGGIORNA MERCATO", fontWeight = FontWeight.Bold)
        }
        (s.refresh as? RefreshState.Finished)?.let { f ->
            WhyExpandable(
                components = emptyList(), title = "Riepilogo aggiornamento (${if (f.status == "COMPLETED") "completo" else "parziale"})",
                footer = f.summary.steps.joinToString("\n") { "• ${it.name}: ${it.status} — ${it.detail}" } +
                    (if (f.summary.notes.isNotEmpty()) "\n" + f.summary.notes.joinToString("\n") else ""),
            )
        }
    }
}

@Composable
private fun RegimeCard(a: MarketAssessmentView?) {
    MpCard(Modifier.testTag("regime_card")) {
        SectionTitle("Regime di mercato")
        if (a == null) {
            Text("Nessuna analisi disponibile", style = MaterialTheme.typography.titleLarge, color = MpColors.TextSecondary)
            Text("Premi AGGIORNA MERCATO per scaricare i dati. Senza dati l'app non produce valutazioni.", color = MpColors.TextSecondary)
            return@MpCard
        }
        Text(a.regime.label, style = MaterialTheme.typography.headlineMedium, color = regimeColor(a.regime), fontWeight = FontWeight.Bold, modifier = Modifier.testTag("regime_label"))
        Text(a.summary, style = MaterialTheme.typography.bodyMedium)
        Text("Valutazione sulla seduta del ${Fmt.date(a.asOf)} · copertura dati ${(a.coverage * 100).toInt()}% · ${a.modelVersion}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        WhyExpandable(a.components, footer = "Regole deterministiche e trasparenti (vedi SCORING_MODEL.md). I pesi non sono validati statisticamente.")
    }
}

@Composable
private fun ScoresCard(a: MarketAssessmentView?) {
    MpCard {
        SectionTitle("Punteggi")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            ScoreGauge(a?.marketScore, "Opportunità\nmercato")
            ScoreGauge(a?.etfScore, "Opportunità\nETF")
            ScoreGauge(a?.swingScore, "Opportunità\nswing")
        }
        if (a != null) WhyExpandable(a.etfComponents, title = "Perché? (punteggio ETF)", footer = "Il PAC resta valido indipendentemente dal punteggio: il market timing non batte in modo affidabile l'investimento regolare.")
    }
}

@Composable
private fun RisksCard(a: MarketAssessmentView?) {
    if (a == null) return
    MpCard {
        SectionTitle("Rischi principali")
        if (a.risks.isEmpty()) Text("Nessun rischio rilevante segnalato dalle regole del modello.", color = MpColors.TextSecondary)
        a.risks.take(5).forEach { Text("• $it", style = MaterialTheme.typography.bodyMedium) }
    }
}

@Composable
private fun OpportunitiesCard(s: HomeState, onOpenStock: (String) -> Unit, onNavigate: (String) -> Unit) {
    MpCard(Modifier.testTag("opportunities")) {
        SectionTitle("Migliori opportunità (titoli USA)") { androidx.compose.material3.TextButton(onClick = { onNavigate("toptrade") }) { Text("Top Trade") } }
        when {
            s.topStocks.isEmpty() && s.noTradeReason != null -> {
                Text("NESSUN TRADE", style = MaterialTheme.typography.titleLarge, color = MpColors.Warning, fontWeight = FontWeight.Bold)
                Text(s.noTradeReason, color = MpColors.TextSecondary)
            }
            s.topStocks.isEmpty() -> Text("Dati non ancora disponibili: esegui un aggiornamento.", color = MpColors.TextSecondary)
            else -> s.topStocks.forEach { st ->
                Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${st.symbol} · ${st.name}", fontWeight = FontWeight.SemiBold)
                        Text(st.catalyst, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 2)
                    }
                    Pill("${st.score?.toInt() ?: "n/d"}", recommendationColor(Recommendation.valueOf(st.recommendation)))
                    androidx.compose.material3.TextButton(onClick = { onOpenStock(st.instrumentId) }) { Text("Apri") }
                }
                HorizontalDivider(color = MpColors.Outline)
            }
        }
    }
}

@Composable
private fun EtfCard(s: HomeState, onOpenEtf: (String) -> Unit) {
    MpCard(onClick = s.bestEtf?.let { { onOpenEtf(it.instrumentId) } }) {
        SectionTitle("Miglior candidato ETF (tattico)")
        val e = s.bestEtf
        if (e == null) { Text("Nessuna analisi ETF disponibile.", color = MpColors.TextSecondary); return@MpCard }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(s.etfNames[e.instrumentId] ?: e.instrumentId, style = MaterialTheme.typography.titleMedium)
                Text("${e.tactical.verdict} · ${e.longTerm.verdict}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                val q = s.quotes[e.instrumentId]
                q?.let { Text("${Fmt.money(it.quote.price, it.quote.currency)} · ${Fmt.dateTime(it.quote.observedAt)}", style = MaterialTheme.typography.bodySmall) }
            }
            ScoreGauge(e.opportunityScore, "Score", size = 64)
        }
    }
}

@Composable
private fun PortfolioCard(s: HomeState, onNavigate: (String) -> Unit) {
    MpCard(onClick = { onNavigate("portfolio") }) {
        SectionTitle("Portafogli virtuali")
        com.marketpilot.core.designsystem.MetricRow("Capitale ETF", Fmt.eur(s.etfEquity))
        com.marketpilot.core.designsystem.MetricRow("Capitale Trading", Fmt.eur(s.tradingEquity))
        Text("Variazione giornaliera e analisi complete nella sezione Portafoglio.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    }
}

@Composable
private fun NewsCard(news: List<NewsItem>, onNavigate: (String) -> Unit) {
    val uri = LocalUriHandler.current
    MpCard {
        SectionTitle("Notizie rilevanti") { androidx.compose.material3.TextButton(onClick = { onNavigate("news") }) { Text("Tutte") } }
        if (news.isEmpty()) Text("Nessuna notizia disponibile.", color = MpColors.TextSecondary)
        news.forEach { n ->
            Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text(n.headline, fontWeight = FontWeight.Medium, modifier = Modifier.testTag("news_item"))
                Text("${n.publisher} · ${Fmt.dateTime(n.publishedAt)}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                androidx.compose.material3.TextButton(onClick = { runCatching { uri.openUri(n.url) } }, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) { Text("Fonte", style = MaterialTheme.typography.bodySmall) }
            }
        }
    }
}

@Composable
private fun DataQualityCard(s: HomeState, onNavigate: (String) -> Unit) {
    MpCard(onClick = { onNavigate("datasources") }) {
        SectionTitle("Qualità e freschezza dei dati")
        if (s.providers.isEmpty()) Text("Nessuna fonte ancora contattata.", color = MpColors.TextSecondary)
        s.providers.sortedBy { it.providerId }.forEach { p ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                val c = when (p.state) {
                    ProviderOperationalState.OPERATIONAL -> MpColors.Positive
                    ProviderOperationalState.DEGRADED -> MpColors.Warning
                    ProviderOperationalState.NEEDS_CONFIGURATION, ProviderOperationalState.DISABLED, ProviderOperationalState.UNTESTED -> MpColors.TextSecondary
                    ProviderOperationalState.UNSUPPORTED -> MpColors.Negative
                }
                Text("● ", color = c)
                Text(p.providerId, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                Text(p.lastSuccessAt?.let { Fmt.dateTime(it) } ?: "mai riuscito", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            }
        }
        val stale = s.assessment?.let { it.asOf.isBefore(s.session.lastCompletedSession) } ?: false
        if (stale) Banner("Le valutazioni si riferiscono a una seduta precedente all'ultima conclusa: aggiorna i dati.", MpColors.Warning)
        if (s.assessment?.regime == MarketRegime.INSUFFICIENT_DATA) Banner("Dati insufficienti per il regime di mercato.", MpColors.Warning)
    }
}
