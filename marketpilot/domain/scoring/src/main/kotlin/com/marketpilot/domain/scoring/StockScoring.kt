package com.marketpilot.domain.scoring

import com.marketpilot.core.common.Calendars
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.EarningsEvent
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.HoldingChange
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.core.model.RiskCategory
import com.marketpilot.core.model.ScoreComponent
import com.marketpilot.domain.indicators.Indicators
import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.risk.PlanOutcome
import com.marketpilot.domain.risk.RiskParameters
import com.marketpilot.domain.risk.TradePlan
import com.marketpilot.domain.risk.TradePlanner
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

/** Default weights from the product specification. Configurable; NOT statistically validated. */
data class ScoringWeights(
    val momentum: Double = 0.25,
    val technical: Double = 0.20,
    val fundamental: Double = 0.15,
    val insider: Double = 0.10,
    val institutional: Double = 0.10,
    val reddit: Double = 0.10,
    val news: Double = 0.05,
    val liquidity: Double = 0.05,
) {
    val total: Double get() = momentum + technical + fundamental + insider + institutional + reddit + news + liquidity

    fun normalized(): ScoringWeights {
        val t = total.takeIf { it > 0 } ?: return ScoringWeights()
        return ScoringWeights(momentum / t, technical / t, fundamental / t, insider / t, institutional / t, reddit / t, news / t, liquidity / t)
    }
}

/**
 * Inputs for one stock. For alternative data, `null` means "not available" (provider not configured
 * or failed) while an empty list means "available, nothing found". The two are scored differently.
 */
data class StockInput(
    val instrument: Instrument,
    val candles: List<Candle>,
    val benchmark: List<Candle>,
    val fundamentals: FundamentalsSnapshot? = null,
    val insiderTransactions: List<InsiderTransaction>? = null,
    val institutional: List<InstitutionalHolding>? = null,
    val reddit: RedditTickerStats? = null,
    val redditAvailable: Boolean = false,
    val news: List<NewsItem>? = null,
    val nextEarnings: EarningsEvent? = null,
)

data class StockScore(
    val instrument: Instrument,
    val asOf: LocalDate,
    val snapshot: TechnicalSnapshot?,
    val score: Double?,
    val rankingScore: Double?,
    val coverage: Double,
    val confidence: Double,
    val components: List<ScoreComponent>,
    val momentumRaw: Double?,
    val risk: RiskCategory,
    val recommendation: Recommendation,
    val plan: TradePlan?,
    val noTradeReason: String?,
    val explanation: String,
    val bullCase: List<String>,
    val baseCase: String,
    val bearCase: List<String>,
    val reasonsToAvoid: List<String>,
    val catalyst: String,
    val insiderSignal: InsiderSignal?,
    val redditSignal: RedditSignal?,
    val excluded: Boolean,
    val exclusionReason: String?,
) {
    val isBreakout: Boolean get() = plan?.setup == com.marketpilot.domain.risk.SetupType.BREAKOUT
}

object StockScorer {
    const val MIN_COVERAGE = 0.5
    const val MIN_BARS = 200
    const val BUY_SCORE = 65.0
    const val BUY_CONFIDENCE = 0.6

    fun score(
        input: StockInput,
        asOf: LocalDate,
        regime: MarketRegime,
        weights: ScoringWeights = ScoringWeights(),
        risk: RiskParameters = RiskParameters(),
        momentumPercentile: Double? = null,
    ): StockScore {
        val w = weights.normalized()
        val candles = input.candles.filter { !it.date.isAfter(asOf) }.sortedBy { it.date }
        val bench = input.benchmark.filter { !it.date.isAfter(asOf) }.sortedBy { it.date }
        val snap = TechnicalSnapshot.from(candles)
        val closes = candles.map { it.close }

        val momentumRaw = momentumRaw(closes, bench.map { it.close })
        val momentum = ScoreComponent(
            "momentum", "Momentum", momentumPercentile ?: momentumRaw?.let { (50 + it * 200).coerceIn(0.0, 100.0) }, w.momentum,
            if (momentumRaw == null) "Storico insufficiente per il momentum (servono 127 sedute)."
            else buildString {
                append("Rendimento 3 mesi ${pct(snap?.change63d)}, 6 mesi ${pct(snap?.change126d)}, forza relativa vs SPY a 3 mesi ${pct(Indicators.relativeStrength(closes, bench.map { it.close }, 63))}.")
                if (momentumPercentile != null) append(" Percentile nell'universo: ${momentumPercentile.roundToInt()}.")
            },
        )
        val technical = technicalComponent(snap, w.technical)
        val fundamental = fundamentalComponent(input.fundamentals, w.fundamental)
        val insiderSignal = input.insiderTransactions?.let { InsiderConviction.score(it, asOf) }
        val insider = ScoreComponent(
            "insider", "Acquisti insider", insiderSignal?.score, w.insider,
            insiderSignal?.explanation ?: "Dati SEC Form 4 non disponibili per questo titolo.",
        )
        val institutional = institutionalComponent(input.institutional, w.institutional)
        val redditSignal = input.reddit?.let { RedditSignalScorer.score(it) }
        val reddit = ScoreComponent(
            "reddit", "Sentiment Reddit", redditSignal?.score ?: if (input.redditAvailable) 45.0 else null, w.reddit,
            redditSignal?.explanation ?: if (input.redditAvailable) "Nessuna menzione rilevata nei subreddit monitorati." else "Reddit non configurato (API ufficiale richiesta).",
        )
        val news = newsComponent(input.news, asOf, w.news)
        val liquidity = liquidityComponent(snap, w.liquidity)
        val components = listOf(momentum, technical, fundamental, insider, institutional, reddit, news, liquidity)

        val coverage = components.filter { it.available }.sumOf { it.weight } / components.sumOf { it.weight }
        val available = components.filter { it.available }
        val score = if (available.isEmpty()) null else available.sumOf { it.score!! * it.weight } / available.sumOf { it.weight }

        val lastBar = candles.lastOrNull()?.date
        val sessionsOld = lastBar?.let { Calendars.NYSE.sessionsBetween(it, asOf) } ?: Int.MAX_VALUE
        val freshnessFactor = when {
            sessionsOld <= 1 -> 1.0
            sessionsOld <= 3 -> 0.8
            else -> 0.5
        }
        val confidence = (coverage * freshnessFactor).coerceIn(0.0, 1.0)

        val exclusionReason = when {
            candles.size < MIN_BARS -> "Storico insufficiente (${candles.size} sedute su $MIN_BARS richieste)."
            !momentum.available || !technical.available -> "Momentum o struttura tecnica non calcolabili."
            coverage < MIN_COVERAGE -> "Copertura dati ${(coverage * 100).roundToInt()}% inferiore al minimo ${(MIN_COVERAGE * 100).roundToInt()}%."
            sessionsOld > 3 -> "Ultimo prezzo disponibile del $lastBar: dati non aggiornati."
            else -> null
        }
        val daysToEarnings = input.nextEarnings?.let { ChronoUnit.DAYS.between(asOf, it.date).toInt() }?.takeIf { it >= 0 }
        val riskCategory = riskCategory(snap, redditSignal, daysToEarnings)
        val planOutcome = snap?.let { TradePlanner.plan(it, risk) }
        val plan = (planOutcome as? PlanOutcome.Plan)?.plan
        val noTradeReason = (planOutcome as? PlanOutcome.NoTrade)?.reason

        val recommendation = when {
            exclusionReason != null -> Recommendation.INSUFFICIENT_DATA
            riskCategory == RiskCategory.VERY_HIGH -> Recommendation.HIGH_RISK
            regime == MarketRegime.HIGH_RISK || regime == MarketRegime.INSUFFICIENT_DATA -> Recommendation.WAIT
            plan == null -> if ((score ?: 0.0) >= BUY_SCORE) Recommendation.WAIT else Recommendation.NO_TRADE
            (score ?: 0.0) >= BUY_SCORE && confidence >= BUY_CONFIDENCE &&
                !(regime == MarketRegime.CAUTION && (score ?: 0.0) < 72) -> Recommendation.BUY_CANDIDATE
            (score ?: 0.0) >= 55 -> Recommendation.WATCH
            else -> Recommendation.NO_TRADE
        }
        val rankingScore = score?.let { it * (0.6 + 0.4 * coverage) }?.takeIf { exclusionReason == null }

        val bull = mutableListOf<String>()
        val bear = mutableListOf<String>()
        val avoid = mutableListOf<String>()
        components.forEach {
            val sc = it.score ?: return@forEach
            if (sc >= 70) bull += "${it.label}: ${it.explanation}"
            if (sc <= 35) bear += "${it.label}: ${it.explanation}"
        }
        snap?.distanceFromSma50?.let { if (it > 0.15) bear += "Prezzo ${pct(it)} sopra la SMA50: rischio di ritorno verso la media." }
        snap?.rsi14?.let { if (it > 75) bear += "RSI ${it.roundToInt()}: ipercomprato." }
        if (regime == MarketRegime.CAUTION || regime == MarketRegime.HIGH_RISK) bear += "Contesto di mercato: ${regime.label.lowercase()}."
        if (redditSignal?.hypeRisk == HypeRisk.HIGH) avoid += "Attenzione Reddit con caratteristiche di hype."
        if (daysToEarnings != null && daysToEarnings <= 7) avoid += "Trimestrale entro $daysToEarnings giorni: rischio di gap."
        if (input.nextEarnings == null) avoid += "Data della prossima trimestrale non disponibile."
        if (coverage < 0.75) avoid += "Copertura dati parziale (${(coverage * 100).roundToInt()}%): fiducia ridotta."
        noTradeReason?.let { avoid += it }
        exclusionReason?.let { avoid += it }
        if (bear.isEmpty()) bear += "Inversione del trend di mercato o notizie societarie negative possono invalidare il setup."

        val atrPct = snap?.atrPercent
        val base = if (snap != null && atrPct != null) {
            "Scenario base: oscillazioni giornaliere tipiche di circa ±${"%.1f".format(atrPct * 100)}% (1 ATR); trend attuale ${snap.trend.label.lowercase()}."
        } else "Scenario base non stimabile."
        val topNews = input.news?.filter { ChronoUnit.DAYS.between(it.publishedAt.atZone(java.time.ZoneOffset.UTC).toLocalDate(), asOf) <= 7 }
            ?.maxByOrNull { it.relevance }
        val catalyst = when {
            insiderSignal != null && insiderSignal.purchases.isNotEmpty() -> "Acquisti insider recenti: ${insiderSignal.explanation}"
            topNews != null -> "Notizia: \"${topNews.headline}\" (${topNews.publisher})"
            else -> "Nessun catalizzatore specifico identificato."
        }
        val explanation = buildString {
            append(recommendation.label)
            score?.let { append(" · punteggio ${it.roundToInt()}/100") }
            append(" · copertura ${(coverage * 100).roundToInt()}% · fiducia ${(confidence * 100).roundToInt()}%. ")
            val best = components.filter { it.available }.maxByOrNull { it.score!! * it.weight }
            best?.let { append("Punto di forza principale: ${it.label.lowercase()}. ") }
            exclusionReason?.let { append(it) } ?: noTradeReason?.let { append(it) }
        }

        return StockScore(
            input.instrument, asOf, snap, score, rankingScore, coverage, confidence, components, momentumRaw, riskCategory,
            recommendation, plan, noTradeReason, explanation.trim(), bull, base, bear, avoid, catalyst, insiderSignal, redditSignal,
            exclusionReason != null, exclusionReason,
        )
    }

    /** Raw momentum blend used for cross-sectional percentile normalization. */
    fun momentumRaw(closes: List<Double>, bench: List<Double>): Double? {
        val r63 = Indicators.returnOver(closes, 63) ?: return null
        val r126 = Indicators.returnOver(closes, 126) ?: return null
        val rs = Indicators.relativeStrength(closes, bench, 63) ?: 0.0
        return 0.4 * r63 + 0.3 * r126 + 0.3 * rs
    }

    private fun technicalComponent(s: TechnicalSnapshot?, weight: Double): ScoreComponent {
        val sma50 = s?.sma50
        val sma200 = s?.sma200
        if (s == null || sma50 == null || sma200 == null) {
            return ScoreComponent("technical", "Struttura tecnica", null, weight, "Servono almeno 200 sedute di storico.")
        }
        var pts = 0.0
        val notes = mutableListOf<String>()
        if (s.close > sma50) { pts += 20; notes += "sopra SMA50" } else notes += "sotto SMA50"
        if (sma50 > sma200) { pts += 20; notes += "SMA50 > SMA200" }
        if (s.close > sma200) { pts += 15; notes += "sopra SMA200" } else notes += "sotto SMA200"
        s.rsi14?.let {
            when {
                it in 45.0..70.0 -> { pts += 15; notes += "RSI ${it.roundToInt()} sano" }
                it > 75 -> notes += "RSI ${it.roundToInt()} ipercomprato"
                it < 40 -> { pts += 5; notes += "RSI ${it.roundToInt()} debole" }
                else -> { pts += 10; notes += "RSI ${it.roundToInt()}" }
            }
        }
        if ((s.macdHistogram ?: 0.0) > 0) { pts += 10; notes += "MACD positivo" }
        val fromHigh = s.high52w?.let { s.close / it - 1 }
        if (fromHigh != null && fromHigh > -0.10) { pts += 10; notes += "vicino ai massimi a 52 settimane" }
        val dist = s.distanceFromSma50
        if (dist != null && dist < 0.15) pts += 10 else notes += "esteso rispetto alla SMA50"
        return ScoreComponent("technical", "Struttura tecnica", pts.coerceIn(0.0, 100.0), weight, notes.joinToString(", ").replaceFirstChar { it.uppercase() } + ".")
    }

    private fun fundamentalComponent(f: FundamentalsSnapshot?, weight: Double): ScoreComponent {
        if (f == null) return ScoreComponent("fundamental", "Qualità fondamentale", null, weight, "Dati SEC XBRL non disponibili.")
        val parts = mutableListOf<Pair<Double, Double>>() // points, max
        val notes = mutableListOf<String>()
        f.revenueGrowth?.let { g ->
            parts += (when { g > 0.10 -> 25.0; g > 0 -> 15.0; else -> 0.0 }) to 25.0
            notes += "crescita ricavi ${pct(g)}"
        }
        f.netMargin?.let { m ->
            parts += (when { m > 0.15 -> 25.0; m > 0.05 -> 15.0; m > 0 -> 8.0; else -> 0.0 }) to 25.0
            notes += "margine netto ${pct(m)}"
        }
        f.freeCashFlow?.let { fcf ->
            parts += (if (fcf > 0) 20.0 else 0.0) to 20.0
            notes += if (fcf > 0) "free cash flow positivo" else "free cash flow negativo"
        }
        f.debtToEquity?.let { de ->
            parts += (when { de < 1 -> 15.0; de < 2 -> 8.0; else -> 0.0 }) to 15.0
            notes += "debito/patrimonio ${"%.2f".format(de)}"
        }
        f.operatingMargin?.let { om ->
            parts += (if (om > 0.15) 15.0 else if (om > 0) 7.0 else 0.0) to 15.0
            notes += "margine operativo ${pct(om)}"
        }
        if (parts.size < 2) return ScoreComponent("fundamental", "Qualità fondamentale", null, weight, "Meno di due metriche fondamentali disponibili.")
        val score = parts.sumOf { it.first } / parts.sumOf { it.second } * 100
        val period = f.fiscalPeriodEnd?.let { " (esercizio chiuso il $it, fonte SEC)" } ?: ""
        return ScoreComponent("fundamental", "Qualità fondamentale", score, weight, notes.joinToString(", ").replaceFirstChar { it.uppercase() } + period + ".")
    }

    private fun institutionalComponent(holdings: List<InstitutionalHolding>?, weight: Double): ScoreComponent {
        if (holdings == null) return ScoreComponent("institutional", "Attività istituzionale", null, weight, "Dati 13F non caricati.")
        if (holdings.isEmpty()) {
            return ScoreComponent("institutional", "Attività istituzionale", 40.0, weight, "Nessun gestore monitorato detiene il titolo nell'ultimo 13F (dati trimestrali, ritardo fino a 45 giorni).")
        }
        val buys = holdings.count { it.change == HoldingChange.NEW || it.change == HoldingChange.INCREASED }
        val sells = holdings.count { it.change == HoldingChange.REDUCED || it.change == HoldingChange.SOLD_OUT }
        val score = (50 + 15.0 * (buys - sells)).coerceIn(0.0, 100.0)
        val latest = holdings.maxOf { it.periodOfReport }
        return ScoreComponent(
            "institutional", "Attività istituzionale", score, weight,
            "${holdings.size} gestori monitorati: $buys aumenti/nuove posizioni, $sells riduzioni (13F al $latest; non sono operazioni in tempo reale).",
        )
    }

    private fun newsComponent(news: List<NewsItem>?, asOf: LocalDate, weight: Double): ScoreComponent {
        if (news == null) return ScoreComponent("news", "Catalizzatori news", null, weight, "Fonte news non disponibile.")
        val recent = news.filter { ChronoUnit.DAYS.between(it.publishedAt.atZone(java.time.ZoneOffset.UTC).toLocalDate(), asOf) in 0..7 }
        if (recent.isEmpty()) return ScoreComponent("news", "Catalizzatori news", 45.0, weight, "Nessuna notizia negli ultimi 7 giorni.")
        val tone = recent.map { NewsClassifier.tone(it.headline) }
        val pos = tone.count { it > 0 }
        val neg = tone.count { it < 0 }
        return ScoreComponent(
            "news", "Catalizzatori news", (50 + 10.0 * (pos - neg)).coerceIn(0.0, 100.0), weight,
            "${recent.size} notizie in 7 giorni: $pos con tono positivo, $neg negativo (interpretazione automatica dei titoli).",
        )
    }

    private fun liquidityComponent(s: TechnicalSnapshot?, weight: Double): ScoreComponent {
        val dv = s?.avgDollarVolume20 ?: return ScoreComponent("liquidity", "Liquidità", null, weight, "Volumi non disponibili.")
        val score = when {
            dv > 1e9 -> 100.0
            dv > 2e8 -> 85.0
            dv > 5e7 -> 70.0
            dv > 2e7 -> 50.0
            dv > 5e6 -> 25.0
            else -> 0.0
        }
        return ScoreComponent("liquidity", "Liquidità", score, weight, "Controvalore medio giornaliero ${"%,.0f".format(dv / 1e6)} milioni USD (20 sedute).")
    }

    fun riskCategory(s: TechnicalSnapshot?, reddit: RedditSignal?, daysToEarnings: Int?): RiskCategory {
        val atr = s?.atrPercent ?: return RiskCategory.HIGH
        val vol = s.volatility20d ?: 0.5
        var level = when {
            atr < 0.02 && vol < 0.25 -> 0
            atr < 0.035 && vol < 0.40 -> 1
            atr < 0.05 && vol < 0.60 -> 2
            else -> 3
        }
        if (reddit?.hypeRisk == HypeRisk.HIGH) level++
        if (daysToEarnings != null && daysToEarnings <= 5) level++
        return RiskCategory.entries[level.coerceAtMost(3)]
    }

    private fun pct(x: Double?) = x?.let { "${if (it >= 0) "+" else ""}${"%.1f".format(it * 100)}%" } ?: "n/d"
}

/** Cross-sectional ranking of the universe with percentile-normalized momentum. */
object StockRanker {
    data class Ranking(
        val all: List<StockScore>,
        val top5: List<StockScore>,
        val top10: List<StockScore>,
        val momentumLeaders: List<StockScore>,
        val insiderAccumulation: List<StockScore>,
        val redditTrending: List<StockScore>,
        val breakouts: List<StockScore>,
        val noTrade: Boolean,
        val noTradeReason: String?,
    )

    fun rank(
        inputs: List<StockInput>,
        asOf: LocalDate,
        regime: MarketRegime,
        weights: ScoringWeights = ScoringWeights(),
        risk: RiskParameters = RiskParameters(),
    ): Ranking {
        val raw = inputs.associate { inp ->
            val closes = inp.candles.filter { !it.date.isAfter(asOf) }.sortedBy { it.date }.map { it.close }
            val bench = inp.benchmark.filter { !it.date.isAfter(asOf) }.sortedBy { it.date }.map { it.close }
            inp.instrument.id to StockScorer.momentumRaw(closes, bench)
        }
        val valid = raw.values.filterNotNull().sorted()
        fun percentile(v: Double?): Double? {
            if (v == null || valid.size < 5) return null
            val below = valid.count { it < v }
            val equal = valid.count { it == v }
            return (below + 0.5 * equal) / valid.size * 100
        }
        val scores = inputs.map { StockScorer.score(it, asOf, regime, weights, risk, percentile(raw[it.instrument.id])) }
        val ranked = scores.filter { !it.excluded && it.rankingScore != null }.sortedByDescending { it.rankingScore }
        val candidates = ranked.filter { it.recommendation == Recommendation.BUY_CANDIDATE }
        val noTradeReason = when {
            ranked.isEmpty() -> "Nessun titolo con dati sufficienti."
            candidates.isEmpty() && (regime == MarketRegime.HIGH_RISK || regime == MarketRegime.INSUFFICIENT_DATA) ->
                "Regime di mercato ${regime.label.lowercase()}: nessun nuovo trade suggerito."
            candidates.isEmpty() -> "Nessun candidato soddisfa insieme punteggio, fiducia e rapporto rischio/rendimento minimo."
            else -> null
        }
        return Ranking(
            all = scores.sortedByDescending { it.rankingScore ?: -1.0 },
            top5 = candidates.take(5),
            top10 = ranked.filter { it.recommendation == Recommendation.BUY_CANDIDATE || it.recommendation == Recommendation.WATCH || it.recommendation == Recommendation.WAIT }.take(10),
            momentumLeaders = ranked.sortedByDescending { it.momentumRaw ?: -1.0 }.take(10),
            insiderAccumulation = ranked.filter { (it.insiderSignal?.purchases?.size ?: 0) > 0 }.sortedByDescending { it.insiderSignal!!.score },
            redditTrending = ranked.filter { it.redditSignal != null && (it.redditSignal.score > 45) }.sortedByDescending { it.redditSignal!!.score },
            breakouts = ranked.filter { it.isBreakout },
            noTrade = candidates.isEmpty(),
            noTradeReason = noTradeReason,
        )
    }
}
