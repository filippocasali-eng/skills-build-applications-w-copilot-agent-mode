package com.marketpilot.domain.scoring

import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.ScoreComponent
import com.marketpilot.domain.indicators.TechnicalSnapshot
import com.marketpilot.domain.market.MarketAssessor
import java.time.LocalDate
import kotlin.math.roundToInt

enum class DecisionTone { POSITIVE, NEUTRAL, CAUTION, NEGATIVE, UNKNOWN }

data class EtfDecision(val title: String, val verdict: String, val tone: DecisionTone, val reasons: List<String>)

data class EtfAnalysis(
    val instrument: Instrument,
    val asOf: LocalDate,
    val snapshot: TechnicalSnapshot?,
    val opportunityScore: Int?,
    val components: List<ScoreComponent>,
    val longTerm: EtfDecision,
    val tactical: EtfDecision,
    val concentration: EtfDecision,
)

/** Current ETF allocation of the ETF account, in EUR by exposure family and by instrument id. */
data class EtfAllocation(
    val totalValueEur: Double,
    val byFamilyEur: Map<String, Double>,
    val byInstrumentEur: Map<String, Double>,
)

object EtfAnalyzer {
    const val MAX_FAMILY_SHARE = 0.70
    const val MAX_SINGLE_SHARE = 0.80

    fun analyze(
        instrument: Instrument,
        candles: List<Candle>,
        asOf: LocalDate,
        regime: MarketRegime,
        allocation: EtfAllocation?,
        plannedPurchaseEur: Double = 0.0,
    ): EtfAnalysis {
        val c = candles.filter { !it.date.isAfter(asOf) }.sortedBy { it.date }
        val s = TechnicalSnapshot.from(c)
        val components = components(s)
        val score = if (s?.sma200 == null) null else MarketAssessor.weightedScore(components)?.roundToInt()
        return EtfAnalysis(
            instrument, asOf, s, score, components,
            longTerm = longTerm(instrument, s),
            tactical = tactical(s, score, regime),
            concentration = concentration(instrument, allocation, plannedPurchaseEur),
        )
    }

    private fun pct(x: Double) = "${if (x >= 0) "+" else ""}${"%.1f".format(x * 100)}%"

    fun components(s: TechnicalSnapshot?): List<ScoreComponent> {
        val sma200 = s?.sma200
        if (s == null || sma200 == null) {
            return listOf(ScoreComponent("trend", "Trend di lungo periodo", null, 1.0, "Servono almeno 200 sedute di storico."))
        }
        val trend = if (s.close > sma200) 70.0 to "Prezzo sopra la SMA200: trend di lungo periodo positivo."
        else 45.0 to "Prezzo sotto la SMA200: trend di lungo periodo negativo."
        val dd = s.currentDrawdown ?: 0.0
        val pullback = when {
            dd > -0.03 -> 45.0 to "Vicino ai massimi a 52 settimane (${pct(dd)})."
            dd > -0.10 -> 75.0 to "Ritracciamento moderato dai massimi (${pct(dd)})."
            dd > -0.20 -> 65.0 to "Correzione marcata (${pct(dd)}): prezzi più bassi, volatilità più alta."
            else -> 55.0 to "Fase ribassista (${pct(dd)}): possibile ulteriore debolezza."
        }
        val stretch = s.distanceFromSma200?.let { d ->
            when {
                d > 0.15 -> 30.0 to "Molto sopra la SMA200 (${pct(d)})."
                d > 0.08 -> 50.0 to "Sopra la SMA200 (${pct(d)})."
                d > -0.05 -> 70.0 to "Vicino alla SMA200 (${pct(d)})."
                else -> 60.0 to "Sotto la SMA200 (${pct(d)})."
            }
        }
        val rsi = s.rsi14?.let { r ->
            when {
                r > 70 -> 30.0 to "RSI ${r.roundToInt()}: ipercomprato."
                r < 35 -> 70.0 to "RSI ${r.roundToInt()}: ipervenduto."
                else -> 55.0 to "RSI ${r.roundToInt()}: neutrale."
            }
        }
        return listOf(
            ScoreComponent("trend", "Trend di lungo periodo", trend.first, 0.25, trend.second),
            ScoreComponent("pullback", "Ritracciamento", pullback.first, 0.30, pullback.second),
            ScoreComponent("stretch", "Distanza da SMA200", stretch?.first, 0.25, stretch?.second ?: "Non disponibile."),
            ScoreComponent("rsi", "RSI 14", rsi?.first, 0.20, rsi?.second ?: "Non disponibile."),
        )
    }

    private fun longTerm(instrument: Instrument, s: TechnicalSnapshot?): EtfDecision {
        val title = "Accumulo di lungo periodo"
        if (s == null || s.bars < 60) {
            return EtfDecision(title, "DATI INSUFFICIENTI", DecisionTone.UNKNOWN, listOf("Storico prezzi non disponibile o troppo breve."))
        }
        val reasons = mutableListOf<String>()
        if (!instrument.isUcits) {
            return EtfDecision(
                title, "SOLO BENCHMARK", DecisionTone.CAUTION,
                listOf("ETF domiciliato negli USA: in genere non acquistabile da investitori retail UE (assenza di KID PRIIPs). Usato solo come riferimento."),
            )
        }
        reasons += "ETF UCITS su indice ${instrument.trackedIndex ?: "n/d"}, ${if (instrument.distribution.name == "ACCUMULATING") "ad accumulazione (dividendi reinvestiti)" else "a distribuzione"}."
        when (instrument.exposureFamily) {
            "GLOBAL_ALL_CAP", "GLOBAL_DEVELOPED" -> reasons += "Diversificazione globale ampia: adatto come nucleo di portafoglio."
            "US_LARGE_CAP" -> reasons += "Esposizione concentrata sulle large cap USA e sul dollaro."
            "US_LARGE_CAP_GROWTH" -> reasons += "Indice concentrato su tecnologia e crescita: volatilità superiore a un indice globale."
        }
        reasons += "Per orizzonti lunghi, la regolarità degli acquisti (PAC) conta più del singolo punto di ingresso; nessun modello garantisce di battere l'investimento regolare."
        if (instrument.terPercent == null) reasons += "TER non verificato nell'app: controlla il KID ufficiale prima di investire."
        val tone = if (instrument.exposureFamily == "US_LARGE_CAP_GROWTH") DecisionTone.NEUTRAL else DecisionTone.POSITIVE
        return EtfDecision(title, if (tone == DecisionTone.POSITIVE) "ADATTO AL PAC" else "ADATTO COME SATELLITE", tone, reasons)
    }

    private fun tactical(s: TechnicalSnapshot?, score: Int?, regime: MarketRegime): EtfDecision {
        val title = "Acquisto tattico oggi"
        if (s == null || score == null) {
            return EtfDecision(title, "DATI INSUFFICIENTI", DecisionTone.UNKNOWN, listOf("Servono almeno 200 sedute per la valutazione tattica."))
        }
        val reasons = mutableListOf("Opportunity Score $score/100 (modello euristico, non validato statisticamente).")
        val (verdict, tone) = when {
            regime == MarketRegime.HIGH_RISK -> "PREFERIRE INGRESSO A TRANCHE" to DecisionTone.CAUTION
            score >= 65 -> "MOMENTO RAGIONEVOLE" to DecisionTone.POSITIVE
            score >= 45 -> "NEUTRALE: PAC O TRANCHE" to DecisionTone.NEUTRAL
            else -> "ATTENDI O INGRESSO GRADUALE" to DecisionTone.CAUTION
        }
        if (regime == MarketRegime.HIGH_RISK) reasons += "Regime di mercato ad alto rischio: suddividere l'ingresso riduce il rischio di tempismo."
        s.rsi14?.let { if (it > 70) reasons += "Ipercomprato nel breve periodo." }
        return EtfDecision(title, verdict, tone, reasons)
    }

    private fun concentration(instrument: Instrument, allocation: EtfAllocation?, planned: Double): EtfDecision {
        val title = "Concentrazione del portafoglio ETF"
        if (allocation == null || allocation.totalValueEur + planned <= 0) {
            return EtfDecision(title, "NESSUNA POSIZIONE", DecisionTone.NEUTRAL, listOf("Conto ETF senza posizioni: nessun rischio di concentrazione da valutare."))
        }
        val total = allocation.totalValueEur + planned
        val family = instrument.exposureFamily
        val familyShare = ((family?.let { allocation.byFamilyEur[it] } ?: 0.0) + planned) / total
        val single = ((allocation.byInstrumentEur[instrument.id] ?: 0.0) + planned) / total
        val reasons = mutableListOf(
            "Peso dello strumento dopo l'acquisto: ${(single * 100).roundToInt()}%.",
            "Peso della famiglia di esposizione (${family ?: "n/d"}): ${(familyShare * 100).roundToInt()}%.",
        )
        if (family == "US_LARGE_CAP" || family == "US_LARGE_CAP_GROWTH") {
            val global = (allocation.byFamilyEur["GLOBAL_ALL_CAP"] ?: 0.0) + (allocation.byFamilyEur["GLOBAL_DEVELOPED"] ?: 0.0)
            if (global > 0) reasons += "Gli indici globali contengono già una quota rilevante di azioni USA: sovrapposizione con gli ETF globali posseduti."
        }
        val (verdict, tone) = when {
            familyShare > MAX_FAMILY_SHARE || (single > MAX_SINGLE_SHARE && family?.startsWith("GLOBAL") != true) -> "CONCENTRAZIONE ELEVATA" to DecisionTone.CAUTION
            else -> "CONCENTRAZIONE ACCETTABILE" to DecisionTone.POSITIVE
        }
        return EtfDecision(title, verdict, tone, reasons)
    }
}
