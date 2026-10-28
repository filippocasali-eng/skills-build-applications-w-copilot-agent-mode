package com.marketpilot.core.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate

/** One daily OHLCV bar for a trading session (date in the exchange's local calendar). */
@Serializable
data class Candle(
    val instrumentId: String,
    @Serializable(with = LocalDateSerializer::class) val date: LocalDate,
    val open: Double,
    val high: Double,
    val low: Double,
    val close: Double,
    val adjClose: Double? = null,
    val volume: Long? = null,
) {
    /** Basic OHLC sanity: rejects bars that cannot be real (used by normalization). */
    fun isConsistent(): Boolean =
        open > 0 && high > 0 && low > 0 && close > 0 &&
            high >= low && high >= maxOf(open, close) - EPS && low <= minOf(open, close) + EPS

    private companion object { const val EPS = 1e-6 }
}

@Serializable
data class Quote(
    val instrumentId: String,
    val price: Double,
    val currency: String,
    @Serializable(with = InstantSerializer::class) val observedAt: Instant,
    val previousClose: Double? = null,
    val changePercent: Double? = null,
    val dayHigh: Double? = null,
    val dayLow: Double? = null,
    val volume: Long? = null,
    val fiftyTwoWeekHigh: Double? = null,
    val fiftyTwoWeekLow: Double? = null,
    val marketState: String? = null,
)

/** A daily FX reference rate: 1 [base] = [rate] [quote]. */
@Serializable
data class FxRate(
    val base: String,
    val quote: String,
    @Serializable(with = LocalDateSerializer::class) val date: LocalDate,
    val rate: Double,
)

/** One observation of a macro/volatility time series (e.g. FRED VIXCLS). */
@Serializable
data class MacroObservation(
    val seriesId: String,
    @Serializable(with = LocalDateSerializer::class) val date: LocalDate,
    val value: Double,
)
