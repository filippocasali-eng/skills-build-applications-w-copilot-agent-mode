package com.marketpilot.domain.market

import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.ModelVersions
import com.marketpilot.core.model.ScoreComponent
import com.marketpilot.domain.indicators.Indicators
import com.marketpilot.domain.indicators.TechnicalSnapshot
import java.time.LocalDate
import kotlin.math.roundToInt

/** Inputs available at the assessment date. All series must end on or before [asOf]. */
data class MarketInputs(
    val asOf: LocalDate,
    val spy: List<Candle>,
    val qqq: List<Candle>,
    /** VIX daily closes (CBOE or FRED VIXCLS). */
    val vix: List<MacroObservation> = emptyList(),
    /** 10-year Treasury yield (FRED DGS10). */
    val us10y: List<MacroObservation> = emptyList(),
    /** 10y-2y spread (FRED T10Y2Y). */
    val yieldCurve: List<MacroObservation> = emptyList(),
    val sectors: Map<String, List<Candle>> = emptyMap(),
    /** Stock universe used to estimate breadth (share above SMA50). */
    val universe: Map<String, List<Candle>> = emptyMap(),
    /** Dates of recent official FOMC statements/minutes (from the Federal Reserve RSS). */
    val recentFomcDates: List<LocalDate> = emptyList(),
)

data class MarketAssessment(
    val asOf: LocalDate,
    val regime: MarketRegime,
    val marketScore: Int?,
    val etfOpportunityScore: Int?,
    val swingOpportunityScore: Int?,
    val components: List<ScoreComponent>,
    val etfComponents: List<ScoreComponent>,
    val risks: List<String>,
    val coverage: Double,
    val summary: String,
    val modelVersion: String = ModelVersions.MODEL,
)

/**
 * Deterministic, explainable market regime model. Each component is scored 0..100 by fixed rules;
 * unavailable components are excluded and reduce [MarketAssessment.coverage]. These rules are
 * heuristics, not statistically validated predictors.
 */
object MarketAssessor {
    const val MIN_COVERAGE = 0.6

    object Weights {
        const val TREND_SPX = 0.20
        const val TREND_NDX = 0.10
        const val VOLATILITY = 0.15
        const val DRAWDOWN = 0.10
        const val MOMENTUM = 0.10
        const val BREADTH = 0.10
        const val SECTORS = 0.10
        const val RISK_APPETITE = 0.05
        const val MACRO = 0.10
    }

    fun assess(input: MarketInputs): MarketAssessment {
        fun upTo(c: List<Candle>) = c.filter { !it.date.isAfter(input.asOf) }.sortedBy { it.date }
        val spy = TechnicalSnapshot.from(upTo(input.spy))
        val qqq = TechnicalSnapshot.from(upTo(input.qqq))
        val vixSeries = input.vix.filter { !it.date.isAfter(input.asOf) }.sortedBy { it.date }
        val risks = mutableListOf<String>()

        val trendSpx = trendComponent("trend_spx", "Trend S&P 500 (SPY)", spy, Weights.TREND_SPX, risks)
        val trendNdx = trendComponent("trend_ndx", "Trend Nasdaq 100 (QQQ)", qqq, Weights.TREND_NDX, risks)
        val volatility = volatilityComponent(vixSeries, spy, risks)
        val drawdown = drawdownComponent(spy, risks)
        val momentum = momentumComponent(spy)
        val breadth = breadthComponent(input.universe.mapValues { upTo(it.value) }, risks)
        val sectors = sectorComponent(input.sectors.mapValues { upTo(it.value) }, risks)
        val appetite = riskAppetiteComponent(input.sectors.mapValues { upTo(it.value) })
        val macro = macroComponent(input, risks)

        val components = listOf(trendSpx, trendNdx, volatility, drawdown, momentum, breadth, sectors, appetite, macro)
        val coverage = components.filter { it.available }.sumOf { it.weight } / components.sumOf { it.weight }
        val raw = weightedScore(components)

        val vixLast = vixSeries.lastOrNull()?.value
        val regime = when {
            raw == null || coverage < MIN_COVERAGE || !trendSpx.available -> MarketRegime.INSUFFICIENT_DATA
            (vixLast != null && vixLast >= 35) ||
                (spy != null && (spy.currentDrawdown ?: 0.0) <= -0.20 && spy.close < (spy.sma200 ?: Double.MAX_VALUE)) -> MarketRegime.HIGH_RISK
            raw >= 65 -> MarketRegime.FAVORABLE
            raw >= 50 -> MarketRegime.NEUTRAL
            raw >= 35 -> MarketRegime.CAUTION
            else -> MarketRegime.HIGH_RISK
        }
        if (coverage < 1.0) {
            val missing = components.filterNot { it.available }.joinToString { it.label }
            risks += "Dati mancanti (copertura ${(coverage * 100).roundToInt()}%): $missing"
        }

        val etfComponents = etfOpportunityComponents(spy, vixLast)
        val etfScore = if (regime == MarketRegime.INSUFFICIENT_DATA) null else weightedScore(etfComponents)?.roundToInt()

        val swing = if (regime == MarketRegime.INSUFFICIENT_DATA) null else {
            val parts = listOf(trendSpx to 0.35, breadth to 0.25, volatility to 0.25, momentum to 0.15)
                .filter { it.first.available }
            val w = parts.sumOf { it.second }
            val s = parts.sumOf { it.first.score!! * it.second } / w
            val capped = when (regime) {
                MarketRegime.HIGH_RISK -> minOf(s, 30.0)
                MarketRegime.CAUTION -> minOf(s, 50.0)
                else -> s
            }
            capped.roundToInt()
        }

        val summary = when (regime) {
            MarketRegime.FAVORABLE -> "Contesto favorevole: trend principali positivi e rischio contenuto."
            MarketRegime.NEUTRAL -> "Contesto neutrale: segnali misti, selettività e gestione del rischio."
            MarketRegime.CAUTION -> "Cautela: deterioramento di trend o volatilità. Ridurre l'aggressività."
            MarketRegime.HIGH_RISK -> "Rischio elevato: preferire attesa e protezione del capitale per il trading."
            MarketRegime.INSUFFICIENT_DATA -> "Dati insufficienti per una valutazione affidabile. Aggiorna i dati o verifica le fonti."
        }

        return MarketAssessment(
            asOf = input.asOf,
            regime = regime,
            marketScore = if (regime == MarketRegime.INSUFFICIENT_DATA) null else raw?.roundToInt(),
            etfOpportunityScore = etfScore,
            swingOpportunityScore = swing,
            components = components,
            etfComponents = etfComponents,
            risks = risks.distinct(),
            coverage = coverage,
            summary = summary,
        )
    }

    fun weightedScore(components: List<ScoreComponent>): Double? {
        val available = components.filter { it.available && it.weight > 0 }
        if (available.isEmpty()) return null
        return available.sumOf { it.score!! * it.weight } / available.sumOf { it.weight }
    }

    private fun pct(x: Double) = "${if (x >= 0) "+" else ""}${"%.1f".format(x * 100)}%"

    private fun trendComponent(key: String, label: String, s: TechnicalSnapshot?, weight: Double, risks: MutableList<String>): ScoreComponent {
        val sma200 = s?.sma200
        val sma50 = s?.sma50
        if (s == null || sma200 == null || sma50 == null) {
            return ScoreComponent(key, label, null, weight, "Storico insufficiente (servono almeno 200 sedute).")
        }
        var score = 0.0
        val notes = mutableListOf<String>()
        if (s.close > sma200) { score += 35; notes += "prezzo sopra SMA200" } else { notes += "prezzo sotto SMA200"; risks += "$label: prezzo sotto la media a 200 sedute" }
        if (sma50 > sma200) { score += 25; notes += "SMA50 sopra SMA200" } else notes += "SMA50 sotto SMA200"
        if (s.close > sma50) { score += 20; notes += "prezzo sopra SMA50" } else notes += "prezzo sotto SMA50"
        val slope = s.sma50Slope20
        if (slope != null && slope > 0) { score += 20; notes += "SMA50 in salita" } else notes += "SMA50 piatta o in discesa"
        return ScoreComponent(key, label, score, weight, notes.joinToString(", ").replaceFirstChar { it.uppercase() } + ".")
    }

    private fun volatilityComponent(vix: List<MacroObservation>, spy: TechnicalSnapshot?, risks: MutableList<String>): ScoreComponent {
        val label = "Volatilità"
        val last = vix.lastOrNull()
        if (last != null) {
            val v = last.value
            var score = when {
                v <= 13 -> 85.0
                v <= 17 -> 75.0
                v <= 20 -> 60.0
                v <= 25 -> 40.0
                v <= 30 -> 25.0
                v <= 40 -> 10.0
                else -> 0.0
            }
            val avg20 = vix.takeLast(21).dropLast(1).map { it.value }.takeIf { it.size >= 10 }?.average()
            var extra = ""
            if (avg20 != null && v > avg20 * 1.25) {
                score = (score - 10).coerceAtLeast(0.0)
                extra = " In forte aumento rispetto alla media a 20 giorni (${"%.1f".format(avg20)})."
            }
            if (v > 25) risks += "VIX elevato (${"%.1f".format(v)})"
            return ScoreComponent("volatility", label, score, Weights.VOLATILITY, "VIX a ${"%.1f".format(v)} (${last.date}).$extra")
        }
        val hv = spy?.volatility20d ?: return ScoreComponent("volatility", label, null, Weights.VOLATILITY, "VIX e volatilità realizzata non disponibili.")
        val score = when {
            hv < 0.12 -> 80.0
            hv < 0.18 -> 65.0
            hv < 0.25 -> 40.0
            else -> 15.0
        }
        risks += "VIX non disponibile: usata la volatilità realizzata di SPY"
        return ScoreComponent("volatility", label, score, Weights.VOLATILITY, "VIX non disponibile; volatilità realizzata SPY 20 sedute ${"%.1f".format(hv * 100)}% annua.")
    }

    private fun drawdownComponent(spy: TechnicalSnapshot?, risks: MutableList<String>): ScoreComponent {
        val dd = spy?.currentDrawdown ?: return ScoreComponent("drawdown", "Drawdown S&P 500", null, Weights.DRAWDOWN, "Dati non disponibili.")
        val score = when {
            dd > -0.03 -> 85.0
            dd > -0.07 -> 65.0
            dd > -0.12 -> 45.0
            dd > -0.20 -> 25.0
            else -> 10.0
        }
        if (dd <= -0.10) risks += "S&P 500 in correzione (${pct(dd)} dal massimo a 52 settimane)"
        return ScoreComponent("drawdown", "Drawdown S&P 500", score, Weights.DRAWDOWN, "SPY a ${pct(dd)} dal massimo delle ultime 52 settimane.")
    }

    private fun momentumComponent(spy: TechnicalSnapshot?): ScoreComponent {
        val r21 = spy?.change21d
        val r63 = spy?.change63d
        if (r21 == null || r63 == null) return ScoreComponent("momentum", "Momentum S&P 500", null, Weights.MOMENTUM, "Storico insufficiente.")
        val score = (50 + r21 * 400 + r63 * 200).coerceIn(0.0, 100.0)
        return ScoreComponent("momentum", "Momentum S&P 500", score, Weights.MOMENTUM, "Rendimento SPY 1 mese ${pct(r21)}, 3 mesi ${pct(r63)}.")
    }

    private fun breadthComponent(universe: Map<String, List<Candle>>, risks: MutableList<String>): ScoreComponent {
        val label = "Ampiezza di mercato"
        val flags = universe.values.mapNotNull { c ->
            if (c.size < 50) null else {
                val closes = c.map { it.close }
                val sma = Indicators.sma(closes, 50).last() ?: return@mapNotNull null
                closes.last() > sma
            }
        }
        if (flags.size < 20) return ScoreComponent("breadth", label, null, Weights.BREADTH, "Servono almeno 20 titoli con 50 sedute di storico (disponibili: ${flags.size}).")
        val share = flags.count { it }.toDouble() / flags.size
        if (share < 0.4) risks += "Ampiezza debole: solo ${(share * 100).roundToInt()}% dei titoli monitorati sopra la SMA50"
        return ScoreComponent(
            "breadth", label, (share * 100).coerceIn(0.0, 100.0), Weights.BREADTH,
            "${(share * 100).roundToInt()}% dei ${flags.size} titoli monitorati sopra la media a 50 sedute (stima sull'universo dell'app, non sull'intero indice).",
        )
    }

    private fun sectorComponent(sectors: Map<String, List<Candle>>, risks: MutableList<String>): ScoreComponent {
        val label = "Condizioni settoriali"
        val status = sectors.mapNotNull { (k, c) ->
            val s = TechnicalSnapshot.from(c) ?: return@mapNotNull null
            val sma = s.sma50 ?: return@mapNotNull null
            k to (s.close > sma)
        }
        if (status.size < 6) return ScoreComponent("sectors", label, null, Weights.SECTORS, "Dati settoriali insufficienti (${status.size} settori).")
        val share = status.count { it.second }.toDouble() / status.size
        val weak = status.filterNot { it.second }.joinToString { it.first }
        if (share < 0.5) risks += "Maggioranza dei settori sotto la SMA50 ($weak)"
        return ScoreComponent(
            "sectors", label, share * 100, Weights.SECTORS,
            "${status.count { it.second }} settori su ${status.size} sopra la SMA50." + if (weak.isNotEmpty()) " Deboli: $weak." else "",
        )
    }

    private fun riskAppetiteComponent(sectors: Map<String, List<Candle>>): ScoreComponent {
        val label = "Propensione al rischio (XLY vs XLP)"
        val y = sectors.entries.firstOrNull { it.key.startsWith("XLY") }?.value?.map { it.close }
        val p = sectors.entries.firstOrNull { it.key.startsWith("XLP") }?.value?.map { it.close }
        val rs = if (y != null && p != null) Indicators.relativeStrength(y, p, 63) else null
        rs ?: return ScoreComponent("risk_appetite", label, null, Weights.RISK_APPETITE, "Dati non disponibili.")
        return ScoreComponent(
            "risk_appetite", label, (50 + rs * 500).coerceIn(0.0, 100.0), Weights.RISK_APPETITE,
            "Beni voluttuari vs beni di prima necessità a 3 mesi: ${pct(rs)}. Positivo = mercato propenso al rischio.",
        )
    }

    private fun macroComponent(input: MarketInputs, risks: MutableList<String>): ScoreComponent {
        val label = "Contesto macro"
        val y10 = input.us10y.filter { !it.date.isAfter(input.asOf) }.sortedBy { it.date }
        val curve = input.yieldCurve.filter { !it.date.isAfter(input.asOf) }.sortedBy { it.date }
        if (y10.size < 22 && curve.isEmpty()) {
            return ScoreComponent("macro", label, null, Weights.MACRO, "Serie FRED non disponibili.")
        }
        var score = 65.0
        val notes = mutableListOf<String>()
        if (y10.size >= 22) {
            val change = y10.last().value - y10[y10.size - 22].value
            notes += "Treasury 10 anni ${"%.2f".format(y10.last().value)}% (${if (change >= 0) "+" else ""}${"%.2f".format(change)} pp in 1 mese)"
            if (change > 0.30) { score -= 20; risks += "Rendimenti a 10 anni in forte rialzo" }
            if (change < -0.30) score -= 5
        }
        curve.lastOrNull()?.let {
            notes += "spread 10a-2a ${"%.2f".format(it.value)} pp"
            if (it.value < 0) { score -= 10; risks += "Curva dei rendimenti invertita" }
        }
        val recentFomc = input.recentFomcDates.filter { !it.isAfter(input.asOf) && !it.isBefore(input.asOf.minusDays(3)) }
        if (recentFomc.isNotEmpty()) {
            score -= 10
            notes += "comunicazione FOMC recente (${recentFomc.max()})"
            risks += "Comunicazione FOMC negli ultimi giorni: volatilità possibile"
        }
        return ScoreComponent("macro", label, score.coerceIn(0.0, 100.0), Weights.MACRO, notes.joinToString("; ").replaceFirstChar { it.uppercase() } + ".")
    }

    /** Tactical ETF opportunity: favours pullbacks within intact long-term uptrends. */
    private fun etfOpportunityComponents(spy: TechnicalSnapshot?, vix: Double?): List<ScoreComponent> {
        val sma200 = spy?.sma200
        if (spy == null || sma200 == null) {
            return listOf(ScoreComponent("etf_trend", "Trend di lungo periodo", null, 1.0, "Storico insufficiente."))
        }
        val above200 = spy.close > sma200
        val dd = spy.currentDrawdown ?: 0.0
        val pullback = when {
            !above200 && dd <= -0.20 -> 55.0 to "Mercato in fase ribassista: prezzi più bassi ma rischio di ulteriori cali."
            dd > -0.03 -> 45.0 to "Vicino ai massimi: nessuno sconto rispetto al recente passato."
            dd > -0.12 && above200 -> 75.0 to "Ritracciamento moderato (${pct(dd)}) con trend di lungo periodo intatto."
            else -> 60.0 to "Correzione significativa (${pct(dd)})."
        }
        val stretch = spy.distanceFromSma200?.let { d ->
            when {
                d > 0.15 -> 30.0 to "Prezzo molto sopra la SMA200 (${pct(d)}): ingresso tattico meno conveniente."
                d > 0.08 -> 50.0 to "Prezzo sopra la SMA200 (${pct(d)})."
                d > -0.05 -> 70.0 to "Prezzo vicino alla SMA200 (${pct(d)})."
                else -> 60.0 to "Prezzo sotto la SMA200 (${pct(d)})."
            }
        }
        val rsi = spy.rsi14?.let { r ->
            when {
                r > 70 -> 30.0 to "RSI ${"%.0f".format(r)}: ipercomprato."
                r < 35 -> 70.0 to "RSI ${"%.0f".format(r)}: ipervenduto."
                else -> 55.0 to "RSI ${"%.0f".format(r)}: neutrale."
            }
        }
        val fear = vix?.let { v -> if (v > 25) 65.0 to "VIX ${"%.0f".format(v)}: paura elevata, storicamente fasi di prezzi più bassi." else 50.0 to "VIX ${"%.0f".format(v)}." }
        return listOf(
            ScoreComponent("etf_pullback", "Ritracciamento", pullback.first, 0.35, pullback.second),
            ScoreComponent("etf_stretch", "Distanza da SMA200", stretch?.first, 0.25, stretch?.second ?: "Non disponibile."),
            ScoreComponent("etf_rsi", "RSI S&P 500", rsi?.first, 0.20, rsi?.second ?: "Non disponibile."),
            ScoreComponent("etf_sentiment", "Sentiment (VIX)", fear?.first, 0.20, fear?.second ?: "VIX non disponibile."),
        )
    }
}
