package com.marketpilot.feature.toptrade

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
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
import com.marketpilot.core.designsystem.MetricRow
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.WhyExpandable
import com.marketpilot.core.designsystem.recommendationColor
import com.marketpilot.core.designsystem.riskColor
import com.marketpilot.core.designsystem.scoreColor
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.RiskCategory
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.StockScoreDto
import com.marketpilot.data.repositories.StoredQuote
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

enum class TopTab(val label: String) {
    TOP5("Top 5"), TOP10("Top 10"), MOMENTUM("Momentum"), INSIDER("Insider"), REDDIT("Reddit"), BREAKOUT("Breakout"), WATCHLIST("Watchlist")
}

data class TopTradeState(val scores: List<StockScoreDto> = emptyList(), val quotes: Map<String, StoredQuote> = emptyMap(), val watchlist: Set<String> = emptySet())

@HiltViewModel
class TopTradeViewModel @Inject constructor(analysis: AnalysisRepository, market: MarketDataRepository) : ViewModel() {
    val state: StateFlow<TopTradeState> = combine(analysis.observeStockScores(), market.observeQuotes(), market.observeWatchlist()) { s, q, w ->
        TopTradeState(s, q, w.toSet())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TopTradeState())
}

fun List<StockScoreDto>.forTab(tab: TopTab, watch: Set<String>): List<StockScoreDto> {
    val ranked = filter { !it.excluded && it.rankingScore != null }.sortedByDescending { it.rankingScore }
    return when (tab) {
        TopTab.TOP5 -> ranked.filter { it.recommendation == Recommendation.BUY_CANDIDATE.name }.take(5)
        TopTab.TOP10 -> ranked.filter { it.recommendation in setOf(Recommendation.BUY_CANDIDATE.name, Recommendation.WATCH.name, Recommendation.WAIT.name) }.take(10)
        TopTab.MOMENTUM -> ranked.sortedByDescending { it.momentumRaw ?: -1.0 }.take(10)
        TopTab.INSIDER -> ranked.filter { it.insiderPurchases > 0 }
        TopTab.REDDIT -> ranked.filter { it.redditSummary != null && (it.components.firstOrNull { c -> c.key == "reddit" }?.score ?: 0.0) > 45 }
        TopTab.BREAKOUT -> ranked.filter { it.isBreakout }
        TopTab.WATCHLIST -> filter { it.instrumentId in watch }.sortedByDescending { it.rankingScore ?: -1.0 }
    }
}

@Composable
fun TopTradeScreen(onOpen: (String) -> Unit, vm: TopTradeViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(TopTab.TOP5) }
    val list = s.scores.forTab(tab, s.watchlist)
    MpScreen("Top Trade USA", testTag = "toptrade") {
        item { ChipRow(TopTab.entries, tab, { it.label }, { tab = it }, Modifier.testTag("toptrade_tabs")) }
        item { Banner("Classifica quantitativa con pesi configurabili, non validati statisticamente. Livelli di ingresso/stop/target sono scenari derivati dal modello.", MpColors.Info) }
        if (s.scores.isEmpty()) {
            item { Text("Nessuna analisi disponibile: esegui AGGIORNA MERCATO dalla schermata Oggi.", color = MpColors.TextSecondary) }
        } else if (list.isEmpty()) {
            item {
                MpCard(Modifier.testTag("no_trade")) {
                    Text("NESSUN TRADE", style = MaterialTheme.typography.headlineMedium, color = MpColors.Warning, fontWeight = FontWeight.Bold)
                    Text(
                        when (tab) {
                            TopTab.TOP5 -> "Nessun titolo soddisfa insieme punteggio, fiducia, contesto di mercato e rapporto rendimento/rischio minimo. Attendere è una decisione valida."
                            TopTab.INSIDER -> "Nessun acquisto insider sul mercato rilevato tra i titoli analizzati."
                            TopTab.REDDIT -> "Reddit non configurato o nessuna attenzione rilevante."
                            TopTab.WATCHLIST -> "Nessun titolo della watchlist ha un'analisi."
                            else -> "Nessun titolo in questa categoria."
                        },
                        color = MpColors.TextSecondary,
                    )
                }
            }
        }
        list.forEachIndexed { i, st -> item(key = "${tab.name}_${st.instrumentId}") { CandidateCard(i + 1, st, s.quotes[st.instrumentId], onOpen) } }
        val excluded = s.scores.count { it.excluded }
        if (excluded > 0) item { Text("$excluded titoli esclusi per dati insufficienti o non aggiornati.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
    }
}

@Composable
fun CandidateCard(rank: Int, st: StockScoreDto, quote: StoredQuote?, onOpen: (String) -> Unit) {
    val rec = Recommendation.valueOf(st.recommendation)
    val risk = RiskCategory.valueOf(st.risk)
    MpCard(onClick = { onOpen(st.instrumentId) }, modifier = Modifier.testTag("candidate_${st.symbol}")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("#$rank ", color = MpColors.TextSecondary)
            Text(st.symbol, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.width(6.dp))
            Text(st.name, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 1, modifier = Modifier.weight(1f))
            Pill(rec.label, recommendationColor(rec))
        }
        val price = quote?.quote?.price ?: st.technical?.close
        Text(
            "${Fmt.money(price, "USD")} · " + (quote?.let { "quotazione ${Fmt.dateTime(it.quote.observedAt)}" } ?: "chiusura ${st.technical?.lastDate ?: "n/d"}"),
            style = MaterialTheme.typography.bodySmall,
        )
        Row {
            Text("Score ${st.score?.toInt() ?: "n/d"}", color = scoreColor(st.score), fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(12.dp))
            Text("Copertura ${(st.coverage * 100).toInt()}%", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.width(12.dp))
            Text("Fiducia ${(st.confidence * 100).toInt()}%", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.width(12.dp))
            Text("Rischio ${risk.label}", color = riskColor(risk), style = MaterialTheme.typography.bodySmall)
        }
        Text(st.explanation, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        st.plan?.let { p ->
            Column {
                MetricRow("Zona di ingresso (${p.setup})", "${Fmt.num(p.entryLow)} – ${Fmt.num(p.entryHigh)}")
                MetricRow("Stop (${p.stopMethod})", Fmt.num(p.stop))
                MetricRow("Target 1 / 2", "${Fmt.num(p.target1)} / ${Fmt.num(p.target2)}")
                MetricRow("Rendimento/rischio", Fmt.num(p.riskReward))
            }
        } ?: st.noTradeReason?.let { Text("Nessun piano: $it", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning) }
        Text("Catalizzatore: ${st.catalyst}", style = MaterialTheme.typography.bodySmall)
        st.bearCase.firstOrNull()?.let { Text("Scenario negativo: $it", style = MaterialTheme.typography.bodySmall, color = MpColors.Negative) }
        WhyExpandable(st.components, footer = "Fonti: prezzi Yahoo Finance; insider SEC Form 4; 13F SEC; fondamentali SEC XBRL; notizie RSS. Dettagli e link nella scheda titolo.")
        TextButton(onClick = { onOpen(st.instrumentId) }) { Text("Analisi completa") }
    }
}
