package com.marketpilot.feature.stockdetail

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.CandlestickChart
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.FreshnessPill
import com.marketpilot.core.designsystem.IndicatorPane
import com.marketpilot.core.designsystem.MetricRow
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.NumberField
import com.marketpilot.core.designsystem.Overlay
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.ScoreGauge
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.WhyExpandable
import com.marketpilot.core.designsystem.changeColor
import com.marketpilot.core.designsystem.recommendationColor
import com.marketpilot.core.designsystem.riskColor
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.core.model.RiskCategory
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.repositories.AlertRepository
import com.marketpilot.data.repositories.AlertType
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.OnDemandRepository
import com.marketpilot.data.repositories.StockScoreDto
import com.marketpilot.data.repositories.StoredQuote
import com.marketpilot.domain.indicators.Indicators
import com.marketpilot.domain.indicators.SupportResistance
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

data class StockDetailState(
    val instrument: Instrument? = null,
    val candles: List<Candle> = emptyList(),
    val quote: StoredQuote? = null,
    val score: StockScoreDto? = null,
    val fundamentals: Pair<FundamentalsSnapshot, Instant>? = null,
    val insiders: List<InsiderTransaction> = emptyList(),
    val institutional: List<InstitutionalHolding> = emptyList(),
    val reddit: RedditTickerStats? = null,
    val news: List<NewsItem> = emptyList(),
    val inWatchlist: Boolean = false,
    val loading: Boolean = true,
    val messages: List<String> = emptyList(),
)

@HiltViewModel
class StockDetailViewModel @Inject constructor(
    handle: SavedStateHandle,
    private val market: MarketDataRepository,
    private val analysis: AnalysisRepository,
    private val onDemand: OnDemandRepository,
    private val alerts: AlertRepository,
) : ViewModel() {
    val id: String = checkNotNull(handle["id"])
    private val extra = MutableStateFlow(StockDetailState())

    val state: StateFlow<StockDetailState> = combine(extra, market.observeCandles(id), market.observeQuotes(), market.observeWatchlist()) { e, c, q, w ->
        e.copy(candles = c, quote = q[id], inWatchlist = id in w)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StockDetailState())

    init { load() }

    private suspend fun reloadLocal() {
        val inst = market.instrument(id)
        val sym = inst?.symbol ?: ""
        val stored = analysis.stockScore(id)
        extra.value = extra.value.copy(
            instrument = inst,
            score = stored ?: onDemand.scoreStock(id),
            fundamentals = analysis.fundamentals(id),
            insiders = analysis.insidersFor(sym),
            institutional = analysis.holdingsFor(sym),
            reddit = analysis.redditFor(sym),
            news = analysis.newsFor(sym, Instant.now().minusSeconds(14L * 86_400)).sortedByDescending { it.publishedAt },
        )
    }

    fun load() {
        viewModelScope.launch {
            reloadLocal()
            val r = onDemand.ensureStockData(id)
            reloadLocal()
            if (r.updatedPrices && analysis.stockScore(id) == null) extra.value = extra.value.copy(score = onDemand.scoreStock(id))
            extra.value = extra.value.copy(loading = false, messages = r.messages)
        }
    }

    fun toggleWatchlist() = viewModelScope.launch { if (state.value.inWatchlist) market.removeFromWatchlist(id) else market.addToWatchlist(id) }
    fun addAlert(type: AlertType, threshold: Double) = viewModelScope.launch { alerts.add(type, id, threshold) }
}

@Composable
fun StockDetailScreen(onBack: () -> Unit, onTrade: (String) -> Unit, onJournal: (String) -> Unit, vm: StockDetailViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    var alertDialog by remember { mutableStateOf(false) }
    val inst = s.instrument
    MpScreen(
        inst?.symbol ?: "Titolo", onBack = onBack, testTag = "stock_detail",
        actions = {
            IconButton(onClick = vm::toggleWatchlist, modifier = Modifier.testTag("watch_toggle")) {
                Icon(if (s.inWatchlist) Icons.Filled.Star else Icons.Outlined.StarOutline, contentDescription = if (s.inWatchlist) "Rimuovi dalla watchlist" else "Aggiungi alla watchlist", tint = MpColors.Warning)
            }
        },
    ) {
        if (inst == null) { item { Text(if (s.loading) "Caricamento…" else "Strumento non trovato") }; return@MpScreen }
        item { Overview(inst, s) }
        // Actions near the top: no need to scroll through the whole analysis to act on it.
        item {
            Row {
                Button(onClick = { onTrade(inst.id) }, modifier = Modifier.weight(1.3f).testTag("stock_trade")) { Text("Simula ordine", maxLines = 1) }
                Spacer(Modifier.width(6.dp))
                OutlinedButton(onClick = { alertDialog = true }, modifier = Modifier.weight(1f)) { Text("Avviso", maxLines = 1) }
                Spacer(Modifier.width(6.dp))
                OutlinedButton(onClick = { onJournal(inst.id) }, modifier = Modifier.weight(1f)) { Text("Nota", maxLines = 1) }
            }
        }
        item { Chart(s) }
        item { DecisionCard(s.score) }
        item { Fundamentals(s.fundamentals) }
        item { Signals(s) }
        item { NewsBlock(s.news) }
    }
    if (alertDialog) AlertDialogContent(onDismiss = { alertDialog = false }, onAdd = { t, v -> vm.addAlert(t, v); alertDialog = false })
}

@Composable
private fun AlertDialogContent(onDismiss: () -> Unit, onAdd: (AlertType, Double) -> Unit) {
    var type by remember { mutableStateOf(AlertType.PRICE_ABOVE) }
    var value by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Nuovo avviso") },
        text = {
            Column {
                ChipRow(AlertType.entries, type, { it.label }, { type = it })
                NumberField(if (type == AlertType.SCORE_ABOVE) "Punteggio (0-100)" else "Prezzo", value, { value = it })
                Text("Gli avvisi vengono verificati a ogni aggiornamento (manuale o in background): non sono in tempo reale.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            }
        },
        confirmButton = { TextButton(onClick = { value.toDoubleOrNull()?.let { onAdd(type, it) } }) { Text("Salva") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annulla") } },
    )
}

@Composable
private fun Overview(inst: Instrument, s: StockDetailState) {
    MpCard {
        Text(inst.name, style = MaterialTheme.typography.titleMedium)
        val q = s.quote
        val last = s.candles.lastOrNull()
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(Fmt.money(q?.quote?.price ?: last?.close, inst.currency), style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.width(8.dp))
            q?.quote?.changePercent?.let { Text(Fmt.pct(it / 100), color = changeColor(it)) }
            Spacer(Modifier.weight(1f))
            q?.let { FreshnessPill(MarketSessions.classify(Calendars.NYSE, it.quote.observedAt, Instant.now())) }
        }
        Text(
            q?.let { "Quotazione del ${Fmt.dateTime(it.quote.observedAt)} (fonte ${ProviderCatalog.displayName(it.providerId)})" } ?: last?.let { "Chiusura del ${Fmt.date(it.date)}" } ?: "Nessun prezzo disponibile",
            style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary,
        )
        MetricRow("Valuta / borsa", "${inst.currency} · NYSE/Nasdaq")
        MetricRow("Settore (SIC SEC)", s.fundamentals?.first?.sicDescription ?: inst.sector ?: "n/d")
        val shares = s.fundamentals?.first?.sharesOutstanding
        val price = q?.quote?.price ?: last?.close
        MetricRow("Capitalizzazione (stima)", if (shares != null && price != null) Fmt.compact(shares * price) + " USD" else "n/d")
        if (s.loading) Text("Aggiornamento dati in corso…", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        s.messages.forEach { Banner(it) }
    }
}

@Composable
private fun Chart(s: StockDetailState) {
    var range by remember { mutableStateOf(126) }
    MpCard {
        SectionTitle("Grafico giornaliero")
        if (s.candles.isEmpty()) { Text("Storico non disponibile.", color = MpColors.TextSecondary); return@MpCard }
        ChipRow(listOf(63, 126, 252), range, { when (it) { 63 -> "3M"; 126 -> "6M"; else -> "1A" } }, { range = it })
        val closes = s.candles.map { it.close }
        val view = s.candles.takeLast(range)
        val off = s.candles.size - view.size
        fun tail(l: List<Double?>) = l.drop(off)
        val bb = Indicators.bollinger(closes)
        val levels = SupportResistance.levels(s.candles.map { it.high }, s.candles.map { it.low }, closes)
        val price = closes.last()
        val sup = SupportResistance.nearestSupport(levels, price)
        val res = SupportResistance.nearestResistance(levels, price)
        CandlestickChart(
            view,
            overlays = listOf(
                Overlay("SMA50", tail(Indicators.sma(closes, 50)), MpColors.Warning),
                Overlay("SMA200", tail(Indicators.sma(closes, 200)), androidx.compose.ui.graphics.Color(0xFFB388FF)),
                Overlay("BB sup", tail(bb.upper), MpColors.Info, dashed = true),
                Overlay("BB inf", tail(bb.lower), MpColors.Info, dashed = true),
            ),
            levels = listOfNotNull(sup?.let { it.price to MpColors.Positive }, res?.let { it.price to MpColors.Negative }),
        )
        Text("Linee tratteggiate verde/rossa: supporto e resistenza più vicini (pivot confermati).", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        IndicatorPane("RSI 14", listOf(Overlay("RSI", tail(Indicators.rsi(closes)), MpColors.Info)), bands = listOf(30.0, 70.0), fixedRange = 0.0..100.0)
        val m = Indicators.macd(closes)
        IndicatorPane("MACD (12,26,9)", listOf(Overlay("MACD", tail(m.macd), MpColors.Positive), Overlay("Segnale", tail(m.signal), MpColors.Warning)), histogram = tail(m.histogram))
    }
}

@Composable
private fun DecisionCard(sc: StockScoreDto?) {
    MpCard(Modifier.testTag("decision_card")) {
        SectionTitle("Decisione del modello")
        if (sc == null) { Text("Analisi non disponibile: servono almeno 200 sedute di storico.", color = MpColors.TextSecondary); return@MpCard }
        val rec = Recommendation.valueOf(sc.recommendation)
        val risk = RiskCategory.valueOf(sc.risk)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(rec.label, style = MaterialTheme.typography.titleLarge, color = recommendationColor(rec), fontWeight = FontWeight.Bold)
                Text("Fiducia ${(sc.confidence * 100).toInt()}% · copertura ${(sc.coverage * 100).toInt()}%", style = MaterialTheme.typography.bodySmall)
                Pill("Rischio ${risk.label}", riskColor(risk))
            }
            ScoreGauge(sc.score?.toInt(), "Score")
        }
        Text(sc.explanation, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        WhyExpandable(sc.components)
        Text("Scenari (derivati dal modello, non previsioni)", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
        Text("Rialzista:", color = MpColors.Positive, fontWeight = FontWeight.Medium)
        if (sc.bullCase.isEmpty()) Text("Nessun fattore marcatamente positivo.", style = MaterialTheme.typography.bodySmall)
        sc.bullCase.forEach { Text("• $it", style = MaterialTheme.typography.bodySmall) }
        Text("Base:", color = MpColors.Info, fontWeight = FontWeight.Medium)
        Text(sc.baseCase, style = MaterialTheme.typography.bodySmall)
        Text("Ribassista:", color = MpColors.Negative, fontWeight = FontWeight.Medium)
        sc.bearCase.forEach { Text("• $it", style = MaterialTheme.typography.bodySmall) }
        sc.plan?.let { p ->
            Text("Piano (scenario del modello)", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
            MetricRow("Setup", p.setup)
            MetricRow("Trigger di ingresso", "")
            Text(p.entryTrigger, style = MaterialTheme.typography.bodySmall)
            MetricRow("Zona di ingresso", "${Fmt.num(p.entryLow)} – ${Fmt.num(p.entryHigh)}")
            MetricRow("Stop", "${Fmt.num(p.stop)} (${p.stopMethod})")
            MetricRow("Target", "${Fmt.num(p.target1)} / ${Fmt.num(p.target2)}")
            MetricRow("Rendimento/rischio", Fmt.num(p.riskReward))
            p.notes.forEach { Text("• $it", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
        }
        if (sc.reasonsToAvoid.isNotEmpty()) {
            Text("Motivi per evitare / cautele", fontWeight = FontWeight.SemiBold, color = MpColors.Warning, modifier = Modifier.padding(top = 8.dp))
            sc.reasonsToAvoid.forEach { Text("• $it", style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@Composable
private fun Fundamentals(f: Pair<FundamentalsSnapshot, Instant>?) {
    val uri = LocalUriHandler.current
    MpCard {
        SectionTitle("Fondamentali (SEC XBRL, ultimo 10-K)")
        if (f == null) { Text("Non disponibili (scaricati al primo accesso online o durante l'aggiornamento).", color = MpColors.TextSecondary); return@MpCard }
        val x = f.first
        MetricRow("Esercizio chiuso il", Fmt.date(x.fiscalPeriodEnd))
        MetricRow("Ricavi", Fmt.compact(x.revenue) + " USD")
        MetricRow("Crescita ricavi a/a", Fmt.pct(x.revenueGrowth))
        MetricRow("Utile netto", Fmt.compact(x.netIncome) + " USD")
        MetricRow("Margine operativo / netto", "${Fmt.pct(x.operatingMargin, signed = false)} / ${Fmt.pct(x.netMargin, signed = false)}")
        MetricRow("Flusso di cassa operativo", Fmt.compact(x.operatingCashFlow) + " USD")
        MetricRow("Free cash flow", Fmt.compact(x.freeCashFlow) + " USD")
        MetricRow("Debito a lungo termine", Fmt.compact(x.totalDebt) + " USD")
        MetricRow("Debito / patrimonio netto", Fmt.num(x.debtToEquity))
        MetricRow("EPS diluito (annuo)", Fmt.num(x.epsDiluted))
        Text("Recuperati il ${Fmt.dateTime(f.second)}. P/E e altri multipli non mostrati: richiederebbero stime non verificate.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        TextButton(onClick = { runCatching { uri.openUri(x.sourceUrl) } }) { Text("Fonte SEC") }
    }
}

@Composable
private fun Signals(s: StockDetailState) {
    val uri = LocalUriHandler.current
    MpCard {
        SectionTitle("Segnali alternativi")
        Text("Insider (SEC Form 4, ultimi 120 giorni)", fontWeight = FontWeight.SemiBold)
        if (s.insiders.isEmpty()) Text("Nessuna operazione registrata o dati non ancora scaricati.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        s.insiders.take(8).forEach { t ->
            val label = when (t.type) {
                InsiderTransactionType.OPEN_MARKET_PURCHASE -> "Acquisto sul mercato"
                InsiderTransactionType.OPEN_MARKET_SALE -> "Vendita sul mercato"
                InsiderTransactionType.GRANT_OR_AWARD -> "Assegnazione"
                InsiderTransactionType.OPTION_EXERCISE -> "Esercizio opzioni"
                InsiderTransactionType.TAX_WITHHOLDING -> "Ritenuta fiscale"
                InsiderTransactionType.GIFT -> "Donazione"
                InsiderTransactionType.OTHER -> "Altro (${t.transactionCode})"
            }
            Column(Modifier.padding(vertical = 3.dp)) {
                Text("$label · ${t.insiderName} (${t.insiderRole})", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium,
                    color = if (t.type == InsiderTransactionType.OPEN_MARKET_PURCHASE) MpColors.Positive else MaterialTheme.colorScheme.onSurface)
                Text(
                    "${Fmt.num(t.shares, 0)} az. a ${Fmt.num(t.pricePerShare)} · ${Fmt.compact(t.dollarValue)} USD · operazione ${Fmt.date(t.transactionDate)}, depositato ${Fmt.date(t.filingDate)} (${t.filingDelayDays} gg)" +
                        if (t.isRule10b51Plan) " · piano 10b5-1" else "",
                    style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary,
                )
            }
        }
        Text("Istituzionali (13F gestori monitorati)", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
        if (s.institutional.isEmpty()) Text("Nessun gestore monitorato detiene il titolo, o 13F non ancora scaricati.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        s.institutional.forEach { h ->
            Text("${h.managerName}: ${Fmt.compact(h.shares)} az. (${h.change.name}) al ${Fmt.date(h.periodOfReport)}, depositato ${Fmt.date(h.filingDate)}", style = MaterialTheme.typography.bodySmall)
        }
        Text("Reddit", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
        s.reddit?.let { r ->
            Text("${r.mentions} menzioni (prec. ${r.previousMentions}) · ${r.uniqueAuthors} autori · sentiment ${Fmt.num(r.sentiment)} (interpretazione automatica) · finestra fino a ${Fmt.dateTime(r.windowEnd)}", style = MaterialTheme.typography.bodySmall)
            r.samplePermalinks.firstOrNull()?.let { link -> TextButton(onClick = { runCatching { uri.openUri(link) } }) { Text("Post più votato") } }
        } ?: Text("Nessun dato Reddit (API non configurata o nessuna menzione).", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    }
}

@Composable
private fun NewsBlock(news: List<NewsItem>) {
    val uri = LocalUriHandler.current
    MpCard {
        SectionTitle("Notizie (14 giorni)")
        if (news.isEmpty()) Text("Nessuna notizia.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        news.take(8).forEach { n ->
            Column(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                Text(n.headline, style = MaterialTheme.typography.bodyMedium)
                Row {
                    Text("${n.publisher} · ${Fmt.dateTime(n.publishedAt)}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, modifier = Modifier.weight(1f))
                    TextButton(onClick = { runCatching { uri.openUri(n.url) } }) { Text("Apri") }
                }
            }
        }
    }
}
