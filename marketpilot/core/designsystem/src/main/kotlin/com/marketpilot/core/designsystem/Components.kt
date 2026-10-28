package com.marketpilot.core.designsystem

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.MarketRegime
import com.marketpilot.core.model.Recommendation
import com.marketpilot.core.model.RiskCategory
import com.marketpilot.core.model.ScoreComponent

@Composable
fun MpCard(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val m = modifier.fillMaxWidth().animateContentSize()
    val colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    val border = androidx.compose.foundation.BorderStroke(1.dp, MpColors.Outline.copy(alpha = 0.6f))
    if (onClick != null) {
        Card(onClick = onClick, modifier = m, colors = colors, border = border, shape = MaterialTheme.shapes.medium) { Column(Modifier.padding(16.dp), content = content) }
    } else {
        Card(modifier = m, colors = colors, border = border, shape = MaterialTheme.shapes.medium) { Column(Modifier.padding(16.dp), content = content) }
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier, trailing: @Composable (() -> Unit)? = null) {
    Row(modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text.uppercase(), style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary, modifier = Modifier.weight(1f))
        trailing?.invoke()
    }
}

fun scoreColor(score: Number?): Color = when {
    score == null -> MpColors.TextSecondary
    score.toDouble() >= 65 -> MpColors.Positive
    score.toDouble() >= 45 -> MpColors.Warning
    else -> MpColors.Negative
}

fun regimeColor(r: MarketRegime): Color = when (r) {
    MarketRegime.FAVORABLE -> MpColors.Positive
    MarketRegime.NEUTRAL -> MpColors.Info
    MarketRegime.CAUTION -> MpColors.Warning
    MarketRegime.HIGH_RISK -> MpColors.Negative
    MarketRegime.INSUFFICIENT_DATA -> MpColors.TextSecondary
}

fun recommendationColor(r: Recommendation): Color = when (r) {
    Recommendation.BUY_CANDIDATE -> MpColors.Positive
    Recommendation.WATCH -> MpColors.Info
    Recommendation.WAIT -> MpColors.Warning
    Recommendation.NO_TRADE, Recommendation.HIGH_RISK -> MpColors.Negative
    Recommendation.INSUFFICIENT_DATA, Recommendation.UNAVAILABLE_PROVIDER -> MpColors.TextSecondary
}

fun riskColor(r: RiskCategory): Color = when (r) {
    RiskCategory.LOW -> MpColors.Positive
    RiskCategory.MEDIUM -> MpColors.Info
    RiskCategory.HIGH -> MpColors.Warning
    RiskCategory.VERY_HIGH -> MpColors.Negative
}

fun changeColor(x: Double?): Color = when {
    x == null || x == 0.0 -> MpColors.TextSecondary
    x > 0 -> MpColors.Positive
    else -> MpColors.Negative
}

@Composable
fun Pill(text: String, color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier
            .background(color.copy(alpha = 0.14f), RoundedCornerShape(50))
            .border(1.dp, color.copy(alpha = 0.45f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) { Text(text, color = color, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold) }
}

@Composable
fun FreshnessPill(freshness: Freshness, modifier: Modifier = Modifier) {
    val color = when (freshness) {
        Freshness.LIVE, Freshness.END_OF_DAY -> MpColors.Positive
        Freshness.DELAYED -> MpColors.Info
        Freshness.STALE -> MpColors.Warning
        Freshness.UNKNOWN -> MpColors.TextSecondary
    }
    Pill(Fmt.freshness(freshness), color, modifier)
}

/** Circular score gauge (0..100). Null score renders as "n/d" (never as a neutral 50). */
@Composable
fun ScoreGauge(score: Int?, label: String, modifier: Modifier = Modifier, size: Int = 88) {
    val color = scoreColor(score)
    Column(modifier.semantics { contentDescription = "$label: ${score?.toString() ?: "non disponibile"} su 100" }, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(size.dp)) {
            Canvas(Modifier.size(size.dp)) {
                val stroke = 8.dp.toPx()
                val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
                val topLeft = Offset(stroke / 2, stroke / 2)
                drawArc(MpColors.Outline, 135f, 270f, false, topLeft, arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
                if (score != null) drawArc(color, 135f, 270f * score.coerceIn(0, 100) / 100f, false, topLeft, arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            }
            Text(score?.toString() ?: "n/d", style = MaterialTheme.typography.titleLarge, color = color, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 2)
    }
}

/** Expandable "Perché?" explanation listing every score component. */
@Composable
fun WhyExpandable(components: List<ScoreComponent>, modifier: Modifier = Modifier, footer: String? = null, title: String = "Perché?") {
    var open by rememberSaveable { mutableStateOf(false) }
    Column(modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().clickable { open = !open }.padding(vertical = 8.dp).semantics { contentDescription = "$title: mostra spiegazione" },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Outlined.Info, null, tint = MpColors.Info, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text(title, color = MpColors.Info, style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f))
            Icon(if (open) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, null, tint = MpColors.Info)
        }
        AnimatedVisibility(open) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                components.forEach { c -> ComponentRow(c) }
                footer?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary) }
            }
        }
    }
}

@Composable
fun ComponentRow(c: ScoreComponent) {
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(c.label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
            Text(
                c.score?.let { "${it.toInt()}/100" } ?: "n/d",
                color = scoreColor(c.score), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.width(8.dp))
            Text("peso ${(c.weight * 100).toInt()}%", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        }
        if (c.score != null) {
            LinearProgressIndicator(
                progress = { (c.score / 100.0).toFloat().coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).height(4.dp),
                color = scoreColor(c.score), trackColor = MpColors.Outline,
            )
        }
        Text(c.explanation, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    }
}

@Composable
fun MetricRow(label: String, value: String, modifier: Modifier = Modifier, valueColor: Color = MaterialTheme.colorScheme.onSurface) {
    Row(modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MpColors.TextSecondary, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, color = valueColor, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun Banner(text: String, color: Color = MpColors.Warning, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().background(color.copy(alpha = 0.12f), MaterialTheme.shapes.small)
            .border(1.dp, color.copy(alpha = 0.4f), MaterialTheme.shapes.small).padding(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(Icons.Outlined.WarningAmber, null, tint = color, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
fun EmptyState(title: String, message: String, modifier: Modifier = Modifier, action: @Composable (() -> Unit)? = null) {
    Column(modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.height(6.dp))
        Text(message, style = MaterialTheme.typography.bodyMedium, color = MpColors.TextSecondary)
        action?.let { Spacer(Modifier.height(12.dp)); it() }
    }
}

const val DISCLAIMER = "Strumento di supporto alle decisioni. Nessuna raccomandazione garantisce profitti. Operatività esclusivamente simulata (paper trading)."
