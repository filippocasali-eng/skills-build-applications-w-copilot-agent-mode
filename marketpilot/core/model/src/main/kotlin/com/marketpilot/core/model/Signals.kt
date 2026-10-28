package com.marketpilot.core.model

import kotlinx.serialization.Serializable

@Serializable
enum class MarketRegime(val label: String) {
    FAVORABLE("FAVOREVOLE"),
    NEUTRAL("NEUTRALE"),
    CAUTION("CAUTELA"),
    HIGH_RISK("RISCHIO ELEVATO"),
    INSUFFICIENT_DATA("DATI INSUFFICIENTI"),
}

/** Outcome of an analysis. The app always allows "do nothing" outcomes. */
@Serializable
enum class Recommendation(val label: String) {
    BUY_CANDIDATE("CANDIDATO"),
    WATCH("OSSERVA"),
    WAIT("ATTENDI"),
    NO_TRADE("NESSUN TRADE"),
    INSUFFICIENT_DATA("DATI INSUFFICIENTI"),
    HIGH_RISK("RISCHIO ELEVATO"),
    UNAVAILABLE_PROVIDER("FONTE NON DISPONIBILE"),
}

@Serializable
enum class RiskCategory(val label: String) { LOW("BASSO"), MEDIUM("MEDIO"), HIGH("ALTO"), VERY_HIGH("MOLTO ALTO") }

/** A component of a score with its own explanation, shown in the "Perché?" sections. */
@Serializable
data class ScoreComponent(
    val key: String,
    val label: String,
    /** 0..100, null when the input is unavailable. */
    val score: Double?,
    val weight: Double,
    val explanation: String,
) {
    val available: Boolean get() = score != null
}

object ModelVersions {
    const val MODEL = "mp-model-1.0.0"
    const val STRATEGY = "mp-strategy-1.0.0"
}
