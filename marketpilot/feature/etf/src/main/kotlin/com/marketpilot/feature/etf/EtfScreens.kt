package com.marketpilot.feature.etf

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
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
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstrumentRole
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.EtfAnalysisDto
import com.marketpilot.data.repositories.EtfDecisionDto
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.OnDemandRepository
import com.marketpilot.data.repositories.StoredQuote
import com.marketpilot.domain.backtesting.EntryComparison
import com.marketpilot.domain.indicators.Indicators
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class EtfRow(val instrument: Instrument, val analysis: EtfAnalysisDto?, val quote: StoredQuote?)

@HiltViewModel
class EtfRadarViewModel @Inject constructor(market: MarketDataRepository, analysis: AnalysisRepository) : ViewModel() {
    val rows: StateFlow<List<EtfRow>> = combine(market.observeInstruments(), analysis.observeEtfAnalyses(), market.observeQuotes()) { inst, an, q ->
        inst.filter { InstrumentRole.ETF_RADAR in it.roles || (InstrumentRole.MARKET_BENCHMARK in it.roles && it.assetClass.name == "ETF") }
            .map { i -> EtfRow(i, an.firstOrNull { it.instrumentId == i.id }, q[i.id]) }
            .sortedWith(compareByDescending<EtfRow> { it.instrument.isUcits }.thenByDescending { it.analysis?.opportunityScore ?: -1 })
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

@Composable
fun EtfRadarScreen(onOpen: (String) -> Unit, vm: EtfRadarViewModel = hiltViewModel()) {
    val rows by vm.rows.collectAsStateWithLifecycle()
    MpScreen("ETF Radar", testTag = "etf_radar") {
        item {
            Banner("ETF UCITS acquistabili da investitori UE. SPY e QQQ (domiciliati USA) sono mostrati solo come riferimento.", MpColors.Info)
        }
        if (rows.isEmpty()) item { Text("Catalogo in caricamento…", color = MpColors.TextSecondary) }
        rows.forEach { r ->
            item(key = r.instrument.id) { EtfRowCard(r, onOpen) }
        }
    }
}

@Composable
private fun EtfRowCard(r: EtfRow, onOpen: (String) -> Unit) {
    val t = r.analysis?.technical
    MpCard(onClick = { onOpen(r.instrument.id) }, modifier = Modifier.testTag("etf_${r.instrument.symbol}")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(r.instrument.symbol, style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.width(8.dp))
                    Pill(if (r.instrument.isUcits) "UCITS" else "USA · solo benchmark", if (r.instrument.isUcits) MpColors.Positive else MpColors.TextSecondary)
                }
                Text(r.instrument.name, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 1)
                Text("${r.instrument.exchange} · ${r.instrument.currency} · ${r.instrument.isin ?: ""}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                if (t != null) {
                    Row {
                        Text(Fmt.money(t.close, r.instrument.currency), fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.width(8.dp))
                        Text(Fmt.pct(t.change1d), color = changeColor(t.change1d))
                    }
                    Text("Chiusura del ${Fmt.date(t.lastDate)}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                } else Text("Dati non disponibili", color = MpColors.TextSecondary)
                r.analysis?.let { Text("Tattico: ${it.tactical.verdict}", style = MaterialTheme.typography.bodySmall) }
            }
            ScoreGauge(r.analysis?.opportunityScore, "Score", size = 64)
        }
    }
}

data class EtfDetailState(
    val instrument: Instrument? = null,
    val candles: List<Candle> = emptyList(),
    val analysis: EtfAnalysisDto? = null,
    val quote: StoredQuote? = null,
    val loading: Boolean = true,
    val message: String? = null,
    val comparison: EntryComparison? = null,
    val comparing: Boolean = false,
)

@HiltViewModel
class EtfDetailViewModel @Inject constructor(
    handle: SavedStateHandle,
    private val market: MarketDataRepository,
    private val analysis: AnalysisRepository,
    private val onDemand: OnDemandRepository,
) : ViewModel() {
    private val id: String = checkNotNull(handle["id"])
    private val extra = MutableStateFlow(EtfDetailState())

    val state: StateFlow<EtfDetailState> = combine(extra, market.observeCandles(id), analysis.observeEtfAnalyses(), market.observeQuotes()) { e, c, a, q ->
        e.copy(candles = c, analysis = a.firstOrNull { it.instrumentId == id }, quote = q[id])
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), EtfDetailState())

    init {
        viewModelScope.launch {
            extra.value = extra.value.copy(instrument = market.instrument(id))
            val r = onDemand.ensureStockData(id)
            extra.value = extra.value.copy(loading = false, message = r.messages.firstOrNull())
        }
    }

    fun compare(amount: Double, horizon: Int) {
        viewModelScope.launch {
            extra.value = extra.value.copy(comparing = true)
            extra.value = extra.value.copy(comparison = onDemand.entryComparison(id, amount, horizon), comparing = false)
        }
    }
}

@Composable
fun EtfDetailScreen(onBack: () -> Unit, onTrade: (String) -> Unit, vm: EtfDetailViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val inst = s.instrument
    MpScreen(inst?.symbol ?: "ETF", onBack = onBack, testTag = "etf_detail") {
        if (inst == null) { item { Text("Caricamento…") }; return@MpScreen }
        item { Overview(inst, s) }
        item { ChartCard(s.candles) }
        s.analysis?.let { a ->
            item {
                MpCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            SectionTitle("Opportunity Score")
                            Text("Euristico, non validato statisticamente.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                        }
                        ScoreGauge(a.opportunityScore, "Score")
                    }
                    WhyExpandable(a.components)
                }
            }
            item { Decision(a.longTerm) }
            item { Decision(a.tactical) }
            item { Decision(a.concentration) }
            item { Metrics(a, inst) }
        }
        item { EntryStrategies(s, vm) }
        item {
            Button(onClick = { onTrade(inst.id) }, modifier = Modifier.fillMaxWidth().testTag("etf_trade")) { Text("Simula acquisto (conto ETF)") }
        }
    }
}

@Composable
private fun Overview(inst: Instrument, s: EtfDetailState) {
    MpCard {
        Text(inst.name, style = MaterialTheme.typography.titleMedium)
        MetricRow("ISIN", inst.isin ?: "n/d")
        MetricRow("Borsa / valuta", "${inst.exchange} · ${inst.currency}")
        MetricRow("Indice", inst.trackedIndex ?: "n/d")
        MetricRow("UCITS", if (inst.isUcits) "Sì (domicilio ${inst.domicile})" else "No (domicilio USA)")
        MetricRow("Politica dividendi", when (inst.distribution.name) { "ACCUMULATING" -> "Accumulazione"; "DISTRIBUTING" -> "Distribuzione"; else -> "n/d" })
        MetricRow("TER", inst.terPercent?.let { "${Fmt.num(it)}% (${inst.terVerifiedSource})" } ?: "Non verificato: controlla il KID")
        s.quote?.let { q ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${Fmt.money(q.quote.price, q.quote.currency)} ", style = MaterialTheme.typography.titleLarge)
                Text(Fmt.pct(q.quote.changePercent?.div(100)), color = changeColor(q.quote.changePercent))
                Spacer(Modifier.weight(1f))
                FreshnessPill(MarketSessions.classify(Calendars.forExchange(inst.exchange), q.quote.observedAt, java.time.Instant.now()))
            }
            Text("Prezzo del ${Fmt.dateTime(q.quote.observedAt)} · fonte ${ProviderCatalog.displayName(q.providerId)}", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        }
        if (s.loading) Text("Verifica aggiornamenti…", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        s.message?.let { Banner(it) }
    }
}

@Composable
fun ChartCard(candles: List<Candle>) {
    var range by remember { mutableStateOf(126) }
    MpCard {
        SectionTitle("Grafico giornaliero")
        ChipRow(listOf(63, 126, 252, 504), range, { when (it) { 63 -> "3M"; 126 -> "6M"; 252 -> "1A"; else -> "2A" } }, { range = it })
        val closes = candles.map { it.close }
        val view = candles.takeLast(range)
        val off = candles.size - view.size
        fun tail(l: List<Double?>) = l.drop(off)
        CandlestickChart(
            view,
            overlays = listOf(
                Overlay("SMA20", tail(Indicators.sma(closes, 20)), MpColors.Info),
                Overlay("SMA50", tail(Indicators.sma(closes, 50)), MpColors.Warning),
                Overlay("SMA200", tail(Indicators.sma(closes, 200)), androidx.compose.ui.graphics.Color(0xFFB388FF)),
            ),
        )
        IndicatorPane("RSI 14", listOf(Overlay("RSI", tail(Indicators.rsi(closes)), MpColors.Info)), bands = listOf(30.0, 70.0), fixedRange = 0.0..100.0)
        val m = Indicators.macd(closes)
        IndicatorPane("MACD (12,26,9)", listOf(Overlay("MACD", tail(m.macd), MpColors.Positive), Overlay("Segnale", tail(m.signal), MpColors.Warning)), histogram = tail(m.histogram))
    }
}

@Composable
private fun Decision(d: EtfDecisionDto) {
    val color = when (d.tone) { "POSITIVE" -> MpColors.Positive; "NEUTRAL" -> MpColors.Info; "CAUTION" -> MpColors.Warning; "NEGATIVE" -> MpColors.Negative; else -> MpColors.TextSecondary }
    MpCard {
        SectionTitle(d.title)
        Text(d.verdict, style = MaterialTheme.typography.titleLarge, color = color, fontWeight = FontWeight.Bold)
        d.reasons.forEach { Text("• $it", style = MaterialTheme.typography.bodyMedium) }
    }
}

@Composable
private fun Metrics(a: EtfAnalysisDto, inst: Instrument) {
    val t = a.technical ?: return
    MpCard {
        SectionTitle("Indicatori (chiusura ${Fmt.date(t.lastDate)})")
        MetricRow("Prezzo", Fmt.money(t.close, inst.currency))
        MetricRow("Var. giornaliera / settimanale / mensile", "${Fmt.pct(t.change1d)} / ${Fmt.pct(t.change5d)} / ${Fmt.pct(t.change21d)}")
        MetricRow("Massimo / minimo 52 settimane", "${Fmt.num(t.high52w)} / ${Fmt.num(t.low52w)}")
        MetricRow("RSI 14", Fmt.num(t.rsi14, 1))
        MetricRow("SMA 20 / 50 / 200", "${Fmt.num(t.sma20)} / ${Fmt.num(t.sma50)} / ${Fmt.num(t.sma200)}")
        MetricRow("EMA 9 / 21", "${Fmt.num(t.ema9)} / ${Fmt.num(t.ema21)}")
        MetricRow("MACD / segnale", "${Fmt.num(t.macd, 3)} / ${Fmt.num(t.macdSignal, 3)}")
        MetricRow("ATR 14", Fmt.num(t.atr14))
        MetricRow("Volatilità storica (20s, annua)", Fmt.pct(t.volatility20d, signed = false))
        MetricRow("Drawdown attuale / massimo (1A)", "${Fmt.pct(t.currentDrawdown)} / ${Fmt.pct(t.maxDrawdown)}")
        MetricRow("Trend", t.trend)
        MetricRow("Distanza da SMA50 / SMA200", "${Fmt.pct(t.distanceFromSma50)} / ${Fmt.pct(t.distanceFromSma200)}")
        MetricRow("Supporto / resistenza", "${Fmt.num(t.support)} / ${Fmt.num(t.resistance)}")
    }
}

@Composable
private fun EntryStrategies(s: EtfDetailState, vm: EtfDetailViewModel) {
    var amount by remember { mutableStateOf("10000") }
    var horizon by remember { mutableStateOf(252) }
    MpCard(Modifier.testTag("entry_comparison")) {
        SectionTitle("Confronto storico modalità di ingresso")
        Text("Unica soluzione vs PAC mensile vs 3 o 6 tranche, su finestre storiche reali di questo ETF.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        NumberField("Importo da investire", amount, { amount = it }, suffix = "€")
        ChipRow(listOf(252, 504), horizon, { if (it == 252) "Orizzonte 1 anno" else "Orizzonte 2 anni" }, { horizon = it })
        OutlinedButton(onClick = { vm.compare(amount.toDoubleOrZero(), horizon) }, enabled = !s.comparing) { Text(if (s.comparing) "Calcolo…" else "Calcola") }
        val c = s.comparison
        if (c == null && !s.comparing) Text("Premi Calcola (servono almeno ~2 anni di storico).", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        c?.let {
            Text("Finestre dal ${it.firstWindowStart} al ${it.lastWindowStart}", style = MaterialTheme.typography.bodySmall)
            it.stats.forEach { st ->
                Column(Modifier.padding(vertical = 4.dp)) {
                    Text(st.strategy.label, fontWeight = FontWeight.SemiBold)
                    MetricRow("Valore finale medio / mediano", "${Fmt.eur(st.meanFinalValue)} / ${Fmt.eur(st.medianFinalValue)}")
                    MetricRow("Peggiore / migliore", "${Fmt.eur(st.worstFinalValue)} / ${Fmt.eur(st.bestFinalValue)}")
                    st.lumpSumWinRate?.let { w -> MetricRow("Volte in cui l'unica soluzione ha fatto meglio", Fmt.pct(w, 0, signed = false)) }
                }
            }
            it.notes.forEach { n -> Text("• $n", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
        }
        if (c == null && s.comparison == null && !s.comparing && s.candles.size < 600) Text("Storico disponibile: ${s.candles.size} sedute.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    }
}
