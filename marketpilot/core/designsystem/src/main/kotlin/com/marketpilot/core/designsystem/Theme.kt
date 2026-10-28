package com.marketpilot.core.designsystem

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object MpColors {
    val Background = Color(0xFF070B14)
    val Surface = Color(0xFF0E1526)
    val SurfaceHigh = Color(0xFF16203A)
    val Outline = Color(0xFF26324F)
    val Positive = Color(0xFF2ECC8F) // emerald
    val Negative = Color(0xFFD9645A) // muted red
    val Warning = Color(0xFFF2B33D) // amber
    val Info = Color(0xFF6EA8FE)
    val TextPrimary = Color(0xFFEAF0FA)
    val TextSecondary = Color(0xFF8F9BB3)
    val Neutral = Color(0xFFB6C0D4)
}

private val scheme = darkColorScheme(
    primary = MpColors.Positive,
    onPrimary = Color(0xFF00281A),
    // Containers (FABs, selected chips, nav indicator) stay in the app palette instead of the default purple.
    primaryContainer = MpColors.Positive,
    onPrimaryContainer = Color(0xFF00281A),
    secondaryContainer = Color(0xFF173A30),
    onSecondaryContainer = MpColors.Positive,
    tertiaryContainer = Color(0xFF3A2E12),
    onTertiaryContainer = MpColors.Warning,
    secondary = MpColors.Info,
    tertiary = MpColors.Warning,
    background = MpColors.Background,
    onBackground = MpColors.TextPrimary,
    surface = MpColors.Surface,
    onSurface = MpColors.TextPrimary,
    surfaceVariant = MpColors.SurfaceHigh,
    onSurfaceVariant = MpColors.TextSecondary,
    surfaceContainer = MpColors.Surface,
    surfaceContainerHigh = MpColors.SurfaceHigh,
    outline = MpColors.Outline,
    error = MpColors.Negative,
)

private val typography = Typography(
    headlineMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 26.sp, lineHeight = 32.sp, letterSpacing = (-0.3).sp),
    titleLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 20.sp, lineHeight = 26.sp),
    titleMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontSize = 15.sp, lineHeight = 22.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 12.sp, lineHeight = 16.sp),
    labelLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 14.sp, letterSpacing = 0.4.sp),
    labelSmall = TextStyle(fontWeight = FontWeight.Medium, fontSize = 11.sp, letterSpacing = 0.5.sp),
)

private val shapes = Shapes(
    small = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(22.dp),
)

/** Dark navy theme; text sizes are in sp so system font scaling is respected. */
@Composable
fun MarketPilotTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = scheme, typography = typography, shapes = shapes, content = content)
}
