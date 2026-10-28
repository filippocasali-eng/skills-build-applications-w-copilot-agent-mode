package com.marketpilot.feature.reddit

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.data.repositories.AnalysisRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.scoring.HypeRisk
import com.marketpilot.domain.scoring.RedditSignalScorer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.time.Duration
import java.time.Instant
import javax.inject.Inject

data class RedditState(val configured: Boolean = false, val stats: List<RedditTickerStats> = emptyList())

@HiltViewModel
class RedditViewModel @Inject constructor(analysis: AnalysisRepository, settings: SettingsRepository) : ViewModel() {
    val state: StateFlow<RedditState> = combine(analysis.observeReddit(), settings.secretsVersion) { st, _ ->
        RedditState(settings.hasSecret(SecretKeyName.REDDIT_CLIENT_ID), st.sortedByDescending { it.mentions })
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), RedditState())
}

@Composable
fun RedditRadarScreen(onBack: () -> Unit, onOpenStock: (String) -> Unit, onConfigure: () -> Unit, vm: RedditViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val uri = LocalUriHandler.current
    MpScreen("Reddit Radar", onBack = onBack, testTag = "reddit") {
        item { Banner("Il sentiment Reddit è un'interpretazione automatica di testi pubblici e può riflettere hype o promozione. Non è mai sufficiente da solo per un segnale d'acquisto.", MpColors.Warning) }
        if (!s.configured) {
            item {
                MpCard(Modifier.testTag("reddit_not_configured")) {
                    Text("Reddit non configurato", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Reddit blocca l'accesso anonimo. Per usare l'API ufficiale crea un'app personale di tipo \"installed app\" su reddit.com/prefs/apps " +
                            "(nessun secret richiesto) e inserisci il client ID nelle Fonti dati.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Row {
                        Button(onClick = onConfigure) { Text("Configura") }
                        Spacer(Modifier.width(8.dp))
                        TextButton(onClick = { runCatching { uri.openUri("https://www.reddit.com/prefs/apps") } }) { Text("Apri reddit.com/prefs/apps") }
                    }
                }
            }
        }
        if (s.stats.isEmpty() && s.configured) item { Text("Nessuna osservazione: esegui un aggiornamento.", color = MpColors.TextSecondary) }
        s.stats.firstOrNull()?.let { first ->
            val age = Duration.between(first.windowEnd, Instant.now())
            if (age > Duration.ofHours(24)) item { Banner("Dati Reddit del ${Fmt.dateTime(first.windowEnd)}: non sono attuali.", MpColors.Warning) }
        }
        s.stats.forEach { st ->
            item(key = st.symbol) {
                val signal = RedditSignalScorer.score(st)
                MpCard(onClick = { onOpenStock(InstrumentCatalog.stockId(st.symbol)) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(st.symbol, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                        Pill("Hype ${signal.hypeRisk.label}", when (signal.hypeRisk) { HypeRisk.LOW -> MpColors.Positive; HypeRisk.MODERATE -> MpColors.Warning; HypeRisk.HIGH -> MpColors.Negative })
                    }
                    Text("${st.mentions} menzioni (24h) vs ${st.previousMentions} (24h precedenti) · ${st.uniqueAuthors} autori unici", style = MaterialTheme.typography.bodySmall)
                    Text("Engagement: ${st.totalScore} voti, ${st.totalComments} commenti · autore più attivo ${(st.topAuthorShare * 100).toInt()}% dei post", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                    Text("Sentiment ${Fmt.num(st.sentiment)}" + (st.sentimentAcceleration?.let { " (variazione ${Fmt.num(it)})" } ?: "") + " · subreddit: ${st.subreddits.joinToString()}", style = MaterialTheme.typography.bodySmall)
                    Text(signal.explanation, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                    Text("Finestra: ${Fmt.dateTime(st.windowStart)} – ${Fmt.dateTime(st.windowEnd)}", style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                }
            }
        }
    }
}
