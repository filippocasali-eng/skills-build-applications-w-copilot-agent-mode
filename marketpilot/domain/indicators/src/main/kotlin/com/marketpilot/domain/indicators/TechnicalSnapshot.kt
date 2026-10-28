package com.marketpilot.domain.indicators

import com.marketpilot.core.model.Candle

/** All indicators for the last bar of a series, computed only from bars up to that bar. */
data class TechnicalSnapshot(
    val lastDate: java.time.LocalDate,
    val close: Double,
    val bars: Int,
    val change1d: Double?,
    val change5d: Double?,
    val change21d: Double?,
    val change63d: Double?,
    val change126d: Double?,
    val change252d: Double?,
    val high52w: Double?,
    val low52w: Double?,
    val rsi14: Double?,
    val sma20: Double?,
    val sma50: Double?,
    val sma200: Double?,
    val ema9: Double?,
    val ema21: Double?,
    val macd: Double?,
    val macdSignal: Double?,
    val macdHistogram: Double?,
    val atr14: Double?,
    val volatility20d: Double?,
    val maxDrawdown: Double?,
    val currentDrawdown: Double?,
    val bollingerUpper: Double?,
    val bollingerLower: Double?,
    val sma50Slope20: Double?,
    val sma200Slope20: Double?,
    val avgDollarVolume20: Double?,
    val avgVolume20: Double?,
    val high20: Double?,
    val support: Double?,
    val resistance: Double?,
    val levels: List<SupportResistance.Level>,
) {
    val distanceFromSma20: Double? get() = Indicators.distanceFrom(close, sma20)
    val distanceFromSma50: Double? get() = Indicators.distanceFrom(close, sma50)
    val distanceFromSma200: Double? get() = Indicators.distanceFrom(close, sma200)
    val atrPercent: Double? get() = atr14?.let { it / close }

    val trend: Trend
        get() = when {
            sma50 == null || sma200 == null -> if (sma20 != null && close > sma20) Trend.UP_SHORT_TERM_ONLY else Trend.UNKNOWN
            close > sma50 && sma50 > sma200 -> Trend.UPTREND
            close < sma50 && sma50 < sma200 -> Trend.DOWNTREND
            else -> Trend.SIDEWAYS
        }

    companion object {
        /** Requires at least 2 bars; candles must be sorted ascending by date. */
        fun from(candles: List<Candle>): TechnicalSnapshot? {
            if (candles.size < 2) return null
            val c = candles.map { it.close }
            val h = candles.map { it.high }
            val l = candles.map { it.low }
            val v = candles.map { it.volume }
            val last = c.size - 1
            val macd = Indicators.macd(c)
            val boll = Indicators.bollinger(c)
            val dd = Indicators.drawdown(c.takeLast(252))
            val sma50 = Indicators.sma(c, 50)
            val sma200 = Indicators.sma(c, 200)
            val volWindow = v.takeLast(20)
            val hasVolume = volWindow.size == 20 && volWindow.all { it != null && it > 0 }
            val levels = SupportResistance.levels(h, l, c)
            return TechnicalSnapshot(
                lastDate = candles.last().date,
                close = c[last],
                bars = c.size,
                change1d = Indicators.returnOver(c, 1),
                change5d = Indicators.returnOver(c, 5),
                change21d = Indicators.returnOver(c, 21),
                change63d = Indicators.returnOver(c, 63),
                change126d = Indicators.returnOver(c, 126),
                change252d = Indicators.returnOver(c, 252),
                high52w = if (c.size >= 200) Indicators.highest(h, 252) else null,
                low52w = if (c.size >= 200) Indicators.lowest(l, 252) else null,
                rsi14 = Indicators.rsi(c, 14)[last],
                sma20 = Indicators.sma(c, 20)[last],
                sma50 = sma50[last],
                sma200 = sma200[last],
                ema9 = Indicators.ema(c, 9)[last],
                ema21 = Indicators.ema(c, 21)[last],
                macd = macd.macd[last],
                macdSignal = macd.signal[last],
                macdHistogram = macd.histogram[last],
                atr14 = Indicators.atr(h, l, c, 14)[last],
                volatility20d = Indicators.historicalVolatility(c, 20),
                maxDrawdown = dd?.maxDrawdown,
                currentDrawdown = dd?.currentDrawdown,
                bollingerUpper = boll.upper[last],
                bollingerLower = boll.lower[last],
                sma50Slope20 = Indicators.slope(sma50, 20),
                sma200Slope20 = Indicators.slope(sma200, 20),
                avgDollarVolume20 = if (hasVolume) candles.takeLast(20).map { it.close * it.volume!! }.average() else null,
                avgVolume20 = if (hasVolume) volWindow.map { it!!.toDouble() }.average() else null,
                high20 = if (c.size > 20) Indicators.highest(h.dropLast(1), 20) else null,
                support = SupportResistance.nearestSupport(levels, c[last])?.price,
                resistance = SupportResistance.nearestResistance(levels, c[last])?.price,
                levels = levels,
            )
        }
    }
}

enum class Trend(val label: String) {
    UPTREND("Rialzista"),
    DOWNTREND("Ribassista"),
    SIDEWAYS("Laterale"),
    UP_SHORT_TERM_ONLY("Rialzo di breve (storico insufficiente)"),
    UNKNOWN("Non determinabile"),
}
