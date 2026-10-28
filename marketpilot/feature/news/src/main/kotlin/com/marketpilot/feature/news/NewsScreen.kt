package com.marketpilot.feature.news

import androidx.compose.foundation.layout.Row
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.model.NewsCategory
import com.marketpilot.core.model.NewsItem
import com.marketpilot.data.repositories.AnalysisRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class NewsViewModel @Inject constructor(analysis: AnalysisRepository) : ViewModel() {
    val news: StateFlow<List<NewsItem>> = analysis.observeNews(300).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

fun categoryLabel(c: NewsCategory?) = when (c) {
    null -> "Tutte"
    NewsCategory.EARNINGS -> "Trimestrali"
    NewsCategory.GUIDANCE -> "Guidance"
    NewsCategory.FED -> "Fed"
    NewsCategory.INFLATION -> "Inflazione"
    NewsCategory.EMPLOYMENT -> "Lavoro"
    NewsCategory.ACQUISITIONS -> "Acquisizioni"
    NewsCategory.REGULATION -> "Regolamentazione"
    NewsCategory.SECTOR -> "Settori"
    NewsCategory.MARKET -> "Mercato"
    NewsCategory.OTHER -> "Altro"
}

@Composable
fun NewsScreen(onBack: () -> Unit, vm: NewsViewModel = hiltViewModel()) {
    val news by vm.news.collectAsStateWithLifecycle()
    var cat by rememberSaveable { mutableStateOf<NewsCategory?>(null) }
    val uri = LocalUriHandler.current
    val list = news.filter { cat == null || it.category == cat }
    MpScreen("Notizie", onBack = onBack, testTag = "news") {
        item { ChipRow(listOf<NewsCategory?>(null) + NewsCategory.entries, cat, ::categoryLabel, { cat = it }) }
        item { Banner("Titoli riportati testualmente dagli editori, senza riassunti generati. Categoria e rilevanza sono interpretazioni automatiche.", MpColors.Info) }
        if (list.isEmpty()) item { Text("Nessuna notizia disponibile.", color = MpColors.TextSecondary) }
        list.forEach { n ->
            item(key = n.id) {
                MpCard(Modifier.testTag("news_card")) {
                    Text(n.headline, style = MaterialTheme.typography.titleMedium)
                    n.description?.takeIf { it.isNotBlank() && it != n.headline }?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary, maxLines = 3) }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${n.publisher} · ${Fmt.dateTime(n.publishedAt)}", style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                        Pill(categoryLabel(n.category), MpColors.Info)
                    }
                    if (n.relatedSymbols.isNotEmpty()) Text("Ticker: ${n.relatedSymbols.joinToString()}", style = MaterialTheme.typography.bodySmall)
                    Text("Rilevanza ${(n.relevance * 100).toInt()}% (automatica)", style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                    TextButton(onClick = { runCatching { uri.openUri(n.url) } }) { Text("Leggi alla fonte") }
                }
            }
        }
    }
}
