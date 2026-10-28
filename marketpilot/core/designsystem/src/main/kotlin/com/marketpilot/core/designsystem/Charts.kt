package com.marketpilot.core.designsystem

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.marketpilot.core.model.Candle

data class Overlay(val label: String, val values: List<Double?>, val color: Color, val dashed: Boolean = false)

private fun DrawScope.polyline(values: List<Double?>, xOf: (Int) -> Float, yOf: (Double) -> Float, color: Color, width: Float, dashed: Boolean = false) {
    var path: Path? = null
    values.forEachIndexed { i, v ->
        if (v == null) { path?.let { drawPath(it, color, style = Stroke(width, pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(10f, 8f)) else null)) }; path = null; return@forEachIndexed }
        val p = path
        if (p == null) path = Path().apply { moveTo(xOf(i), yOf(v)) } else p.lineTo(xOf(i), yOf(v))
    }
    path?.let { drawPath(it, color, style = Stroke(width, pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(10f, 8f)) else null)) }
}

/**
 * Daily candlestick chart with volume, overlays (moving averages, Bollinger) and horizontal levels.
 * Tap or long-press-and-drag to inspect a session (crosshair + OHLC readout).
 */
@Composable
fun CandlestickChart(
    candles: List<Candle>,
    overlays: List<Overlay> = emptyList(),
    levels: List<Pair<Double, Color>> = emptyList(),
    modifier: Modifier = Modifier,
    height: Int = 260,
) {
    if (candles.isEmpty()) {
        EmptyState("Nessun dato", "Storico prezzi non disponibile.")
        return
    }
    var selected by remember(candles) { mutableStateOf<Int?>(null) }
    val sel = selected?.let { candles.getOrNull(it) } ?: candles.last()
    Column(modifier) {
        Row {
            Text(Fmt.date(sel.date), style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            Spacer(Modifier.width(10.dp))
            Text(
                "A ${Fmt.num(sel.open)}  M ${Fmt.num(sel.high)}  m ${Fmt.num(sel.low)}  C ${Fmt.num(sel.close)}",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface,
            )
        }
        Row {
            overlays.forEach { o ->
                Text("● ${o.label} ", color = o.color, style = MaterialTheme.typography.labelSmall)
            }
        }
        Canvas(
            Modifier.fillMaxWidth().height(height.dp)
                .semantics { contentDescription = "Grafico a candele giornaliero di ${candles.size} sedute; ultima chiusura ${Fmt.num(candles.last().close)}" }
                .pointerInput(candles) {
                    detectTapGestures { pos -> selected = ((pos.x / size.width) * candles.size).toInt().coerceIn(0, candles.lastIndex) }
                }
                .pointerInput(candles) {
                    detectDragGesturesAfterLongPress(onDragEnd = {}) { change, _ ->
                        selected = ((change.position.x / size.width) * candles.size).toInt().coerceIn(0, candles.lastIndex)
                    }
                },
        ) {
            val volH = size.height * 0.18f
            val priceH = size.height - volH - 6f
            val values = candles.flatMap { listOf(it.high, it.low) } + overlays.flatMap { it.values.filterNotNull() } + levels.map { it.first }
            val max = values.max()
            val min = values.min()
            val span = (max - min).takeIf { it > 0 } ?: 1.0
            val step = size.width / candles.size
            fun x(i: Int) = i * step + step / 2
            fun y(v: Double) = ((max - v) / span * priceH).toFloat()
            // grid
            for (g in 0..4) {
                val gy = priceH * g / 4
                drawLine(MpColors.Outline.copy(alpha = 0.35f), Offset(0f, gy), Offset(size.width, gy), 1f)
            }
            levels.forEach { (lv, c) ->
                drawLine(c.copy(alpha = 0.7f), Offset(0f, y(lv)), Offset(size.width, y(lv)), 2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 10f)))
            }
            val maxVol = candles.mapNotNull { it.volume }.maxOrNull()?.toFloat()
            candles.forEachIndexed { i, c ->
                val up = c.close >= c.open
                val color = if (up) MpColors.Positive else MpColors.Negative
                drawLine(color, Offset(x(i), y(c.high)), Offset(x(i), y(c.low)), maxOf(1f, step * 0.12f))
                val top = y(maxOf(c.open, c.close))
                val bodyH = maxOf(1f, y(minOf(c.open, c.close)) - top)
                drawRect(color, Offset(x(i) - step * 0.35f, top), Size(step * 0.7f, bodyH))
                val vol = c.volume
                if (maxVol != null && maxVol > 0 && vol != null) {
                    val vh = volH * vol / maxVol
                    drawRect(color.copy(alpha = 0.35f), Offset(x(i) - step * 0.35f, size.height - vh), Size(step * 0.7f, vh))
                }
            }
            overlays.forEach { o -> polyline(o.values, ::x, ::y, o.color, 2.5f, o.dashed) }
            selected?.let { s ->
                drawLine(MpColors.TextSecondary, Offset(x(s), 0f), Offset(x(s), size.height), 1.5f)
                drawLine(MpColors.TextSecondary, Offset(0f, y(candles[s].close)), Offset(size.width, y(candles[s].close)), 1f)
            }
        }
    }
}

/** Indicator pane (e.g. RSI with 30/70 bands, MACD line/signal/histogram). */
@Composable
fun IndicatorPane(
    title: String,
    lines: List<Overlay>,
    histogram: List<Double?> = emptyList(),
    bands: List<Double> = emptyList(),
    fixedRange: ClosedFloatingPointRange<Double>? = null,
    modifier: Modifier = Modifier,
    height: Int = 90,
) {
    Column(modifier) {
        Row {
            Text(title, style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
            Spacer(Modifier.width(8.dp))
            lines.forEach { l -> Text("${l.label} ${Fmt.num(l.values.lastOrNull { it != null })}  ", color = l.color, style = MaterialTheme.typography.labelSmall) }
        }
        Canvas(Modifier.fillMaxWidth().height(height.dp).semantics { contentDescription = title }) {
            val all = lines.flatMap { it.values.filterNotNull() } + histogram.filterNotNull() + bands
            if (all.isEmpty()) return@Canvas
            val max = fixedRange?.endInclusive ?: all.max()
            val min = fixedRange?.start ?: all.min()
            val span = (max - min).takeIf { it > 0 } ?: 1.0
            val n = maxOf(lines.maxOfOrNull { it.values.size } ?: 0, histogram.size)
            val step = size.width / maxOf(1, n)
            fun x(i: Int) = i * step + step / 2
            fun y(v: Double) = ((max - v) / span * size.height).toFloat()
            bands.forEach { b -> drawLine(MpColors.Outline, Offset(0f, y(b)), Offset(size.width, y(b)), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))) }
            if (histogram.isNotEmpty()) {
                val zero = y(0.0)
                histogram.forEachIndexed { i, h ->
                    if (h != null) {
                        val c = if (h >= 0) MpColors.Positive else MpColors.Negative
                        drawRect(c.copy(alpha = 0.5f), Offset(x(i) - step * 0.35f, minOf(zero, y(h))), Size(step * 0.7f, kotlin.math.abs(y(h) - zero)))
                    }
                }
            }
            lines.forEach { l -> polyline(l.values, ::x, ::y, l.color, 2f, l.dashed) }
        }
    }
}

/** Simple multi-series line chart (equity curve vs benchmark). */
@Composable
fun LineChart(series: List<Overlay>, modifier: Modifier = Modifier, height: Int = 180) {
    Column(modifier) {
        Row { series.forEach { s -> Text("● ${s.label}  ", color = s.color, style = MaterialTheme.typography.labelSmall) } }
        Canvas(Modifier.fillMaxWidth().height(height.dp).semantics { contentDescription = "Grafico: " + series.joinToString { it.label } }) {
            val all = series.flatMap { it.values.filterNotNull() }
            if (all.size < 2) return@Canvas
            val max = all.max()
            val min = all.min()
            val span = (max - min).takeIf { it > 0 } ?: 1.0
            val n = series.maxOf { it.values.size }
            val step = size.width / maxOf(1, n - 1)
            for (g in 0..3) drawLine(MpColors.Outline.copy(alpha = 0.3f), Offset(0f, size.height * g / 3), Offset(size.width, size.height * g / 3), 1f)
            series.forEach { s -> polyline(s.values, { it * step }, { ((max - it) / span * size.height).toFloat() }, s.color, 3f, s.dashed) }
        }
    }
}
