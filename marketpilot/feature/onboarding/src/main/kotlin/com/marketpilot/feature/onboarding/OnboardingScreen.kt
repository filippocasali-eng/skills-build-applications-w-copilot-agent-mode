package com.marketpilot.feature.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.DISCLAIMER
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.NumberField
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.data.providers.ProviderIds
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.portfolio.AccountType
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OnboardingState(
    val step: Int = 0,
    val etfCapital: String = "",
    val tradingCapital: String = "",
    val monthly: String = "",
    val riskPct: String = "0.5",
    val preferredEtfs: Set<String> = setOf(InstrumentCatalog.VWCE),
    val preferredStocks: String = "",
    val yahooEnabled: Boolean = true,
    val alphaVantageKey: String = "",
    val finnhubKey: String = "",
    val redditClientId: String = "",
    val secContact: String = "",
    val saving: Boolean = false,
    val error: String? = null,
) {
    companion object { const val STEPS = 5 }
}

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val settings: SettingsRepository,
    private val portfolio: PortfolioRepository,
    private val market: MarketDataRepository,
) : ViewModel() {
    private val _state = MutableStateFlow(OnboardingState())
    val state = _state.asStateFlow()

    fun update(transform: (OnboardingState) -> OnboardingState) = _state.update(transform)
    fun next() = _state.update { it.copy(step = (it.step + 1).coerceAtMost(OnboardingState.STEPS - 1), error = null) }
    fun back() = _state.update { it.copy(step = (it.step - 1).coerceAtLeast(0), error = null) }

    fun finish(onDone: () -> Unit) {
        val s = _state.value
        val risk = s.riskPct.toDoubleOrZero() / 100
        if (risk <= 0 || risk > 0.05) { _state.update { it.copy(error = "Il rischio per trade deve essere tra 0,01% e 5%.") }; return }
        if (s.etfCapital.toDoubleOrZero() < 0 || s.tradingCapital.toDoubleOrZero() < 0) { _state.update { it.copy(error = "Il capitale non può essere negativo.") }; return }
        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            market.ensureCatalog()
            val tickers = s.preferredStocks.split(',', ' ', ';').map { it.trim().uppercase() }.filter { it.isNotEmpty() }.distinct().take(30)
            settings.update { cur ->
                cur.copy(
                    onboardingCompleted = true,
                    monthlyEtfContribution = s.monthly.toDoubleOrZero().coerceAtLeast(0.0),
                    preferredEtfIds = s.preferredEtfs.toList(),
                    preferredStocks = tickers,
                    risk = cur.risk.copy(riskPerTrade = risk),
                    providers = cur.providers.copy(
                        enabled = cur.providers.enabled + (ProviderIds.YAHOO to s.yahooEnabled) + (ProviderIds.YAHOO_RSS to s.yahooEnabled),
                        secContactEmail = s.secContact.trim(),
                    ),
                )
            }
            settings.setSecret(SecretKeyName.ALPHA_VANTAGE_API_KEY, s.alphaVantageKey)
            settings.setSecret(SecretKeyName.FINNHUB_API_KEY, s.finnhubKey)
            settings.setSecret(SecretKeyName.REDDIT_CLIENT_ID, s.redditClientId)
            s.etfCapital.toDoubleOrZero().takeIf { it > 0 }?.let { portfolio.deposit(AccountType.ETF, it, "Capitale iniziale (onboarding)") }
            s.tradingCapital.toDoubleOrZero().takeIf { it > 0 }?.let { portfolio.deposit(AccountType.TRADING, it, "Capitale iniziale (onboarding)") }
            s.preferredEtfs.forEach { market.addToWatchlist(it) }
            tickers.forEach { t -> market.instrument(InstrumentCatalog.stockId(t))?.let { market.addToWatchlist(it.id) } ?: market.addToWatchlist(market.addUserStock(t, null).id) }
            _state.update { it.copy(saving = false) }
            onDone()
        }
    }
}

@Composable
fun OnboardingScreen(onFinished: () -> Unit, vm: OnboardingViewModel = hiltViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize().padding(20.dp).testTag("onboarding"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("MarketPilot AI", style = MaterialTheme.typography.headlineMedium, color = MpColors.Positive, fontWeight = FontWeight.Bold)
        LinearProgressIndicator(progress = { (s.step + 1f) / OnboardingState.STEPS }, modifier = Modifier.fillMaxWidth(), color = MpColors.Positive, trackColor = MpColors.Outline)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            when (s.step) {
                0 -> Welcome()
                1 -> Capital(s, vm)
                2 -> Risk(s, vm)
                3 -> Preferences(s, vm)
                else -> Sources(s, vm)
            }
            s.error?.let { Banner(it, MpColors.Negative) }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (s.step > 0) TextButton(onClick = vm::back) { Text("Indietro") }
            Spacer(Modifier.weight(1f))
            if (s.step in 1 until OnboardingState.STEPS - 1) TextButton(onClick = vm::next, modifier = Modifier.testTag("onboarding_skip")) { Text("Salta") }
            if (s.step < OnboardingState.STEPS - 1) {
                Button(onClick = vm::next, modifier = Modifier.testTag("onboarding_next")) { Text(if (s.step == 0) "Inizia" else "Avanti") }
            } else {
                Button(onClick = { vm.finish(onFinished) }, enabled = !s.saving, modifier = Modifier.testTag("onboarding_finish")) { Text(if (s.saving) "Salvataggio…" else "Completa") }
            }
        }
    }
}

@Composable
private fun Welcome() {
    Text("Il tuo copilota per decidere con metodo", style = MaterialTheme.typography.titleLarge)
    Text(
        "Analisi del mercato USA, ETF UCITS e titoli, con spiegazioni trasparenti, simulazione di ordini (paper trading) e storico delle decisioni. " +
            "L'app funziona interamente sul telefono: nessun server, nessun account.",
        style = MaterialTheme.typography.bodyLarge,
    )
    Banner(DISCLAIMER)
    Banner("Puoi saltare ogni domanda opzionale e modificarla in seguito dalle Impostazioni. Il capitale predefinito è zero.", MpColors.Info)
}

@Composable
private fun Capital(s: OnboardingState, vm: OnboardingViewModel) {
    Text("Capitale virtuale", style = MaterialTheme.typography.titleLarge)
    Text("Due conti separati e indipendenti. I trasferimenti tra conti sono solo manuali e registrati.", color = MpColors.TextSecondary)
    NumberField("Capitale ETF (lungo periodo)", s.etfCapital, { v -> vm.update { it.copy(etfCapital = v) } }, suffix = "€", tag = "etf_capital")
    NumberField("Capitale Trading (breve/swing)", s.tradingCapital, { v -> vm.update { it.copy(tradingCapital = v) } }, suffix = "€", tag = "trading_capital")
    NumberField("Versamento mensile ETF (PAC)", s.monthly, { v -> vm.update { it.copy(monthly = v) } }, suffix = "€/mese")
    Text("Valuta di base: EUR (unica valuta supportata nella versione 1; gli strumenti in USD sono convertiti con i cambi BCE).", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
}

@Composable
private fun Risk(s: OnboardingState, vm: OnboardingViewModel) {
    Text("Rischio per operazione", style = MaterialTheme.typography.titleLarge)
    NumberField("Rischio per trade (% del capitale Trading)", s.riskPct, { v -> vm.update { it.copy(riskPct = v) } }, suffix = "%", tag = "risk_pct")
    MpCard {
        Text("Limiti predefiniti (modificabili)", fontWeight = FontWeight.SemiBold)
        Text("• Esposizione massima per posizione: 15%\n• Massimo 3 posizioni simultanee\n• Rischio aggregato massimo: 2%\n• Rapporto rendimento/rischio minimo: 2,0\n• Nessuna leva, nessuna vendita allo scoperto", style = MaterialTheme.typography.bodyMedium)
        Text("Sono controlli di rischio, non garanzie: in caso di gap la perdita può superare lo stop.", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning)
    }
}

@Composable
private fun Preferences(s: OnboardingState, vm: OnboardingViewModel) {
    Text("Strumenti preferiti", style = MaterialTheme.typography.titleLarge)
    Text("ETF UCITS da seguire:", fontWeight = FontWeight.SemiBold)
    InstrumentCatalog.ucitsEtfs.forEach { e ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = e.id in s.preferredEtfs, onCheckedChange = { c -> vm.update { st -> st.copy(preferredEtfs = if (c) st.preferredEtfs + e.id else st.preferredEtfs - e.id) } })
            Column {
                Text("${e.symbol} · ${e.exchange} · ${e.currency}", fontWeight = FontWeight.Medium)
                Text("${e.name} (${e.isin})", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            }
        }
    }
    OutlinedTextField(
        value = s.preferredStocks, onValueChange = { v -> vm.update { it.copy(preferredStocks = v) } },
        label = { Text("Titoli USA preferiti (es. AAPL, MSFT)") }, modifier = Modifier.fillMaxWidth().testTag("preferred_stocks"),
    )
}

@Composable
private fun Sources(s: OnboardingState, vm: OnboardingViewModel) {
    Text("Fonti dati", style = MaterialTheme.typography.titleLarge)
    MpCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Yahoo Finance (prezzi, gratuito)", fontWeight = FontWeight.SemiBold)
                Text("Endpoint pubblico non ufficiale, per uso personale: può smettere di funzionare. È l'unica fonte gratuita senza chiave verificata per prezzi USA e Xetra.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
            }
            Switch(checked = s.yahooEnabled, onCheckedChange = { c -> vm.update { it.copy(yahooEnabled = c) } }, modifier = Modifier.testTag("yahoo_switch"))
        }
    }
    Text("Fonti ufficiali sempre attive senza chiave: SEC EDGAR, BCE, FRED, Cboe, Federal Reserve.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
    OutlinedTextField(s.secContact, { v -> vm.update { it.copy(secContact = v) } }, label = { Text("E-mail di contatto per SEC (consigliata)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    Text("Chiavi personali opzionali (cifrate con Android Keystore, mai incluse nell'app):", fontWeight = FontWeight.SemiBold)
    OutlinedTextField(s.alphaVantageKey, { v -> vm.update { it.copy(alphaVantageKey = v) } }, label = { Text("Alpha Vantage API key") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
    OutlinedTextField(s.finnhubKey, { v -> vm.update { it.copy(finnhubKey = v) } }, label = { Text("Finnhub API key") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
    OutlinedTextField(s.redditClientId, { v -> vm.update { it.copy(redditClientId = v) } }, label = { Text("Reddit client ID (app \"installed\")") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    Spacer(Modifier.height(4.dp))
}
