package com.marketpilot.feature.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.marketpilot.core.datastore.AppSettings
import com.marketpilot.core.designsystem.Banner
import com.marketpilot.core.designsystem.ChipRow
import com.marketpilot.core.designsystem.Fmt
import com.marketpilot.core.designsystem.MpCard
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.core.designsystem.MpScreen
import com.marketpilot.core.designsystem.NumberField
import com.marketpilot.core.designsystem.Pill
import com.marketpilot.core.designsystem.SectionTitle
import com.marketpilot.core.designsystem.toDoubleOrZero
import com.marketpilot.core.model.ProviderOperationalState
import com.marketpilot.core.model.ProviderStatus
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.providers.ProviderIds
import com.marketpilot.data.repositories.ExportRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.OnDemandRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.papertrading.SameBarExitPolicy
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/** Hook implemented by the app module (WorkManager scheduling depends on notification/background settings). */
fun interface ScheduleUpdater { fun apply(settings: AppSettings) }

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settings: SettingsRepository,
    private val export: ExportRepository,
    private val scheduler: ScheduleUpdater,
) : ViewModel() {
    val message = MutableStateFlow<String?>(null)
    val state: StateFlow<AppSettings?> = settings.settings.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun save(transform: (AppSettings) -> AppSettings) = viewModelScope.launch {
        val s = settings.update(transform)
        scheduler.apply(s)
        message.value = "Impostazioni salvate"
    }

    fun exportTo(write: (ByteArray) -> Unit, password: String) = viewModelScope.launch {
        message.value = runCatching {
            val bytes = export.export(password.takeIf { it.isNotEmpty() }?.toCharArray())
            withContext(Dispatchers.IO) { write(bytes) }
            "Esportazione completata" + if (password.isEmpty()) " (file NON cifrato)" else " (cifrata AES-256)"
        }.getOrElse { "Esportazione non riuscita: ${it.message}" }
    }

    fun importFrom(read: () -> ByteArray, password: String) = viewModelScope.launch {
        message.value = runCatching {
            val bytes = withContext(Dispatchers.IO) { read() }
            val r = export.import(bytes, password.toCharArray())
            "Ripristino completato: ${r.ledger} movimenti, ${r.orders} ordini, ${r.journal} note, ${r.snapshots} snapshot"
        }.getOrElse { "Ripristino non riuscito: ${it.message}" }
    }
}

@Composable
fun SettingsScreen(onBack: () -> Unit, onDataSources: () -> Unit, vm: SettingsViewModel = hiltViewModel()) {
    val st by vm.state.collectAsStateWithLifecycle()
    val msg by vm.message.collectAsStateWithLifecycle()
    val s = st ?: run { MpScreen("Impostazioni", onBack = onBack) { item { Text("Caricamento…") } }; return }
    val context = LocalContext.current
    var password by remember { mutableStateOf("") }
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        uri?.let { u -> vm.exportTo({ bytes -> context.contentResolver.openOutputStream(u)?.use { it.write(bytes) } }, password) }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { u -> vm.importFrom({ context.contentResolver.openInputStream(u)?.use { it.readBytes() } ?: ByteArray(0) }, password) }
    }
    MpScreen("Impostazioni", onBack = onBack, testTag = "settings") {
        msg?.let { item { Banner(it, MpColors.Info) } }
        item { OutlinedButton(onClick = onDataSources, modifier = Modifier.fillMaxWidth().testTag("open_datasources")) { Text("Fonti dati e chiavi API") } }
        item { RiskSection(s, vm) }
        item { WeightsSection(s, vm) }
        item { FeesSection(s, vm) }
        item { SimulationSection(s, vm) }
        item { GeneralSection(s, vm) }
        item {
            MpCard {
                SectionTitle("Esporta / importa dati")
                Text("Backup locale di portafogli, ordini, diario, watchlist, avvisi e storico decisioni. Le chiavi API non vengono mai esportate.", style = MaterialTheme.typography.bodySmall)
                OutlinedTextField(password, { password = it }, label = { Text("Password del backup (min. 8 caratteri, consigliata)") }, singleLine = true,
                    visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
                Row {
                    Button(onClick = { exportLauncher.launch("marketpilot-backup.mpx") }, modifier = Modifier.weight(1f).testTag("export")) { Text("Esporta") }
                    Spacer(Modifier.width(8.dp))
                    OutlinedButton(onClick = { importLauncher.launch(arrayOf("*/*")) }, modifier = Modifier.weight(1f)) { Text("Importa") }
                }
                Text("L'importazione sostituisce i dati attuali di portafoglio e ordini.", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning)
            }
        }
    }
}


@Composable
private fun RiskSection(s: AppSettings, vm: SettingsViewModel) {
    var risk by remember(s) { mutableStateOf((s.risk.riskPerTrade * 100).toString()) }
    var exposure by remember(s) { mutableStateOf((s.risk.maxPositionExposure * 100).toString()) }
    var positions by remember(s) { mutableStateOf(s.risk.maxOpenPositions.toString()) }
    var aggregate by remember(s) { mutableStateOf((s.risk.maxAggregateOpenRisk * 100).toString()) }
    var rr by remember(s) { mutableStateOf(s.risk.minRiskReward.toString()) }
    MpCard {
        SectionTitle("Parametri di rischio (conto Trading)")
        NumberField("Rischio per trade", risk, { risk = it }, suffix = "%", tag = "set_risk")
        NumberField("Esposizione massima per posizione", exposure, { exposure = it }, suffix = "%")
        NumberField("Posizioni simultanee massime", positions, { positions = it })
        NumberField("Rischio aggregato massimo", aggregate, { aggregate = it }, suffix = "%")
        NumberField("Rendimento/rischio minimo", rr, { rr = it })
        Text("Leva e vendite allo scoperto sono disabilitate nella versione 1.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        Button(onClick = {
            vm.save { it.copy(risk = it.risk.copy(
                riskPerTrade = (risk.toDoubleOrZero() / 100).coerceIn(0.0001, 0.05),
                maxPositionExposure = (exposure.toDoubleOrZero() / 100).coerceIn(0.01, 1.0),
                maxOpenPositions = positions.toDoubleOrZero().toInt().coerceIn(1, 50),
                maxAggregateOpenRisk = (aggregate.toDoubleOrZero() / 100).coerceIn(0.001, 0.2),
                minRiskReward = rr.toDoubleOrZero().coerceIn(0.5, 10.0),
            )) }
        }, modifier = Modifier.testTag("save_risk")) { Text("Salva rischio") }
    }
}

@Composable
private fun WeightsSection(s: AppSettings, vm: SettingsViewModel) {
    val w = s.weights
    val fields = remember(s) {
        mutableStateOf(listOf(w.momentum, w.technical, w.fundamental, w.insider, w.institutional, w.reddit, w.news, w.liquidity).map { (it * 100).toString() })
    }
    val labels = listOf("Momentum", "Struttura tecnica", "Qualità fondamentale", "Acquisti insider", "Attività istituzionale", "Sentiment Reddit", "Catalizzatori news", "Liquidità")
    MpCard {
        SectionTitle("Pesi del punteggio titoli")
        Text("Predefiniti dalla specifica, NON validati statisticamente. Vengono normalizzati a 100%.", style = MaterialTheme.typography.bodySmall, color = MpColors.Warning)
        labels.forEachIndexed { i, l -> NumberField(l, fields.value[i], { v -> fields.value = fields.value.toMutableList().also { it[i] = v } }, suffix = "%") }
        Row {
            Button(onClick = {
                val v = fields.value.map { it.toDoubleOrZero().coerceAtLeast(0.0) / 100 }
                vm.save { it.copy(weights = com.marketpilot.core.datastore.WeightSettings(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7])) }
            }) { Text("Salva pesi") }
            Spacer(Modifier.width(8.dp))
            TextButton(onClick = { vm.save { it.copy(weights = com.marketpilot.core.datastore.WeightSettings()) } }) { Text("Ripristina") }
        }
    }
}

@Composable
private fun FeesSection(s: AppSettings, vm: SettingsViewModel) {
    val f = s.fees
    var fixed by remember(s) { mutableStateOf(f.fixedPerOrder.toString()) }
    var pct by remember(s) { mutableStateOf((f.percentPerOrder * 100).toString()) }
    var min by remember(s) { mutableStateOf(f.minPerOrder.toString()) }
    var max by remember(s) { mutableStateOf(f.maxPerOrder?.toString() ?: "") }
    var fx by remember(s) { mutableStateOf((f.fxConversionCost * 100).toString()) }
    var spread by remember(s) { mutableStateOf((f.halfSpread * 100).toString()) }
    var slip by remember(s) { mutableStateOf((f.slippage * 100).toString()) }
    var stopSlip by remember(s) { mutableStateOf((f.stopExtraSlippage * 100).toString()) }
    MpCard {
        SectionTitle("Commissioni e costi (inserisci quelli del tuo broker)")
        NumberField("Commissione fissa per ordine", fixed, { fixed = it }, suffix = "€")
        NumberField("Commissione percentuale", pct, { pct = it }, suffix = "%")
        NumberField("Commissione minima", min, { min = it }, suffix = "€")
        NumberField("Commissione massima (vuoto = nessuna)", max, { max = it }, suffix = "€")
        NumberField("Costo di conversione valuta", fx, { fx = it }, suffix = "%")
        NumberField("Metà spread denaro/lettera", spread, { spread = it }, suffix = "%")
        NumberField("Slippage ordini a mercato/stop", slip, { slip = it }, suffix = "%")
        NumberField("Slippage aggiuntivo sugli stop", stopSlip, { stopSlip = it }, suffix = "%")
        Button(onClick = {
            vm.save { it.copy(fees = it.fees.copy(
                fixedPerOrder = fixed.toDoubleOrZero().coerceAtLeast(0.0), percentPerOrder = pct.toDoubleOrZero().coerceAtLeast(0.0) / 100,
                minPerOrder = min.toDoubleOrZero().coerceAtLeast(0.0), maxPerOrder = max.toDoubleOrNull()?.coerceAtLeast(0.0),
                fxConversionCost = fx.toDoubleOrZero().coerceAtLeast(0.0) / 100, halfSpread = spread.toDoubleOrZero().coerceAtLeast(0.0) / 100,
                slippage = slip.toDoubleOrZero().coerceAtLeast(0.0) / 100, stopExtraSlippage = stopSlip.toDoubleOrZero().coerceAtLeast(0.0) / 100,
            )) }
        }) { Text("Salva costi") }
    }
}

@Composable
private fun SimulationSection(s: AppSettings, vm: SettingsViewModel) {
    val policy = runCatching { SameBarExitPolicy.valueOf(s.simulation.sameBarExitPolicy) }.getOrDefault(SameBarExitPolicy.CONSERVATIVE)
    MpCard {
        SectionTitle("Ipotesi di esecuzione simulata")
        Text("Uscita nella stessa seduta dell'ingresso:", fontWeight = FontWeight.Medium)
        ChipRow(SameBarExitPolicy.entries, policy, { if (it == SameBarExitPolicy.CONSERVATIVE) "Prudente" else "Dalla seduta successiva" }, { p -> vm.save { it.copy(simulation = it.simulation.copy(sameBarExitPolicy = p.name)) } })
        Text(policy.label, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        Text("Se stop e target sono toccati nella stessa seduta e l'ordine è sconosciuto, viene sempre applicato lo stop (mai l'esito più favorevole) e l'esecuzione è marcata come ambigua.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Limite eseguito solo se il prezzo lo supera (non solo lo tocca)", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Switch(checked = s.simulation.limitRequiresPenetration, onCheckedChange = { c -> vm.save { it.copy(simulation = it.simulation.copy(limitRequiresPenetration = c)) } })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Esecuzioni parziali (max 10% del volume della seduta)", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Switch(checked = s.simulation.maxParticipationOfBarVolume != null, onCheckedChange = { c -> vm.save { it.copy(simulation = it.simulation.copy(maxParticipationOfBarVolume = if (c) 0.10 else null)) } })
        }
    }
}

@Composable
private fun GeneralSection(s: AppSettings, vm: SettingsViewModel) {
    var monthly by remember(s) { mutableStateOf(s.monthlyEtfContribution.toString()) }
    var years by remember(s) { mutableStateOf(s.cache.historyYears.toString()) }
    var newsDays by remember(s) { mutableStateOf(s.cache.newsRetentionDays.toString()) }
    var hour by remember(s) { mutableStateOf(s.notifications.dailyReminderHour.toString()) }
    MpCard {
        SectionTitle("Generali, cache e notifiche")
        NumberField("PAC mensile ETF", monthly, { monthly = it }, suffix = "€")
        NumberField("Anni di storico prezzi in cache", years, { years = it })
        NumberField("Giorni di conservazione notizie", newsDays, { newsDays = it })
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Aggiornamento automatico in background (WorkManager, non garantito all'orario esatto)", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Switch(checked = s.notifications.backgroundRefreshEnabled, onCheckedChange = { c -> vm.save { it.copy(notifications = it.notifications.copy(backgroundRefreshEnabled = c)) } })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Notifiche di avviso", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Switch(checked = s.notifications.alertsEnabled, onCheckedChange = { c -> vm.save { it.copy(notifications = it.notifications.copy(alertsEnabled = c)) } })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Promemoria giornaliero di analisi", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Switch(checked = s.notifications.dailyReminderEnabled, onCheckedChange = { c -> vm.save { it.copy(notifications = it.notifications.copy(dailyReminderEnabled = c)) } }, modifier = Modifier.testTag("reminder_switch"))
        }
        NumberField("Ora del promemoria (0-23, ora italiana)", hour, { hour = it })
        Text("Android può rinviare notifiche e aggiornamenti in background (Doze, risparmio energetico). Su Samsung disattiva l'ottimizzazione batteria per MarketPilot se vuoi maggiore regolarità.", style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
        Button(onClick = {
            vm.save { it.copy(
                monthlyEtfContribution = monthly.toDoubleOrZero().coerceAtLeast(0.0),
                cache = it.cache.copy(historyYears = years.toDoubleOrZero().toInt().coerceIn(1, 10), newsRetentionDays = newsDays.toDoubleOrZero().toInt().coerceIn(3, 365)),
                notifications = it.notifications.copy(dailyReminderHour = hour.toDoubleOrZero().toInt().coerceIn(0, 23)),
            ) }
        }) { Text("Salva") }
    }
}

// -------------------------------------------------------------------------------------------------
@HiltViewModel
class DataSourcesViewModel @Inject constructor(
    private val settings: SettingsRepository,
    market: MarketDataRepository,
    private val onDemand: OnDemandRepository,
) : ViewModel() {
    val testResults = MutableStateFlow<Map<String, String>>(emptyMap())
    val state: StateFlow<Triple<AppSettings?, List<ProviderStatus>, Int>> = combine(settings.settings, market.observeProviderStatus(), settings.secretsVersion) { s, p, v -> Triple(s, p, v) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), Triple(null, emptyList(), 0))

    fun setEnabled(id: String, enabled: Boolean) = viewModelScope.launch { settings.update { it.copy(providers = it.providers.copy(enabled = it.providers.enabled + (id to enabled))) } }
    fun setSecret(name: SecretKeyName, value: String) = settings.setSecret(name, value)
    fun hasSecret(name: SecretKeyName) = settings.hasSecret(name)
    fun setContact(v: String) = viewModelScope.launch { settings.update { it.copy(providers = it.providers.copy(secContactEmail = v.trim())) } }
    fun test(id: String) = viewModelScope.launch {
        testResults.value = testResults.value + (id to "Verifica in corso…")
        testResults.value = testResults.value + (id to onDemand.testProvider(id))
    }
}

@Composable
fun DataSourcesScreen(onBack: () -> Unit, vm: DataSourcesViewModel = hiltViewModel()) {
    val (settings, statuses, _) = vm.state.collectAsStateWithLifecycle().value
    val tests by vm.testResults.collectAsStateWithLifecycle()
    val uri = LocalUriHandler.current
    val s = settings ?: run { MpScreen("Fonti dati", onBack = onBack) { item { Text("Caricamento…") } }; return }
    MpScreen("Fonti dati", onBack = onBack, testTag = "datasources") {
        item { Banner("Una fonte è considerata operativa solo dopo una richiesta reale riuscita. Nessuna chiave condivisa è inclusa nell'app: le chiavi personali sono cifrate con Android Keystore.", MpColors.Info) }
        ProviderCatalog.all.forEach { d ->
            item(key = d.id) {
                val st = statuses.firstOrNull { it.providerId == d.id }
                val enabled = s.providers.enabled[d.id] ?: d.defaultEnabled
                MpCard(Modifier.testTag("provider_${d.id}")) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(d.displayName, fontWeight = FontWeight.SemiBold)
                            Row {
                                Pill(if (d.official) "Ufficiale" else "Non ufficiale", if (d.official) MpColors.Positive else MpColors.Warning)
                                Spacer(Modifier.width(6.dp))
                                Pill(stateLabel(st?.state, enabled), stateColor(st?.state, enabled))
                            }
                        }
                        Switch(checked = enabled, onCheckedChange = { vm.setEnabled(d.id, it) })
                    }
                    Text(d.termsNote, style = MaterialTheme.typography.bodySmall, color = MpColors.TextSecondary)
                    st?.let {
                        Text("Ultimo successo: ${it.lastSuccessAt?.let(Fmt::dateTime) ?: "mai"} · tentativi ok/ko ${it.successCount}/${it.failureCount}", style = MaterialTheme.typography.labelSmall, color = MpColors.TextSecondary)
                        it.lastError?.let { e ->
                            Text("Ultimo problema: ${ProviderCatalog.friendlyError(e)}", style = MaterialTheme.typography.labelSmall, color = MpColors.Warning)
                            if (d.id == ProviderIds.ECB) Text("I cambi EUR/USD ed EUR/GBP vengono presi dalla Federal Reserve (FRED) come riserva.", style = MaterialTheme.typography.labelSmall, color = MpColors.Info)
                        }
                    }
                    secretFor(d.id)?.let { name -> SecretField(name, vm) }
                    if (d.id == ProviderIds.SEC) ContactField(s.providers.secContactEmail, vm)
                    Row {
                        OutlinedButton(onClick = { vm.test(d.id) }, modifier = Modifier.testTag("test_${d.id}")) { Text("Verifica") }
                        Spacer(Modifier.width(8.dp))
                        TextButton(onClick = { runCatching { uri.openUri(d.homepage) } }) { Text("Sito") }
                    }
                    tests[d.id]?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                }
            }
        }
    }
}

private fun secretFor(id: String) = when (id) {
    ProviderIds.ALPHA_VANTAGE -> SecretKeyName.ALPHA_VANTAGE_API_KEY
    ProviderIds.FINNHUB -> SecretKeyName.FINNHUB_API_KEY
    ProviderIds.REDDIT -> SecretKeyName.REDDIT_CLIENT_ID
    else -> null
}

private fun stateLabel(s: ProviderOperationalState?, enabled: Boolean) = when {
    !enabled -> "Disattivata"
    s == null || s == ProviderOperationalState.UNTESTED -> "Non verificata"
    s == ProviderOperationalState.OPERATIONAL -> "Operativa"
    s == ProviderOperationalState.DEGRADED -> "Problemi"
    s == ProviderOperationalState.NEEDS_CONFIGURATION -> "Da configurare"
    s == ProviderOperationalState.UNSUPPORTED -> "Non supportata"
    else -> "Disattivata"
}

private fun stateColor(s: ProviderOperationalState?, enabled: Boolean) = when {
    !enabled -> MpColors.TextSecondary
    s == ProviderOperationalState.OPERATIONAL -> MpColors.Positive
    s == ProviderOperationalState.DEGRADED || s == ProviderOperationalState.NEEDS_CONFIGURATION -> MpColors.Warning
    s == ProviderOperationalState.UNSUPPORTED -> MpColors.Negative
    else -> MpColors.TextSecondary
}

@Composable
private fun SecretField(name: SecretKeyName, vm: DataSourcesViewModel) {
    var value by remember { mutableStateOf("") }
    val set = vm.hasSecret(name)
    Row(verticalAlignment = Alignment.CenterVertically) {
        OutlinedTextField(
            value, { value = it }, singleLine = true, visualTransformation = PasswordVisualTransformation(),
            label = { Text(if (set) "Chiave salvata (inserisci per sostituire)" else if (name == SecretKeyName.REDDIT_CLIENT_ID) "Client ID" else "Chiave API personale") },
            modifier = Modifier.weight(1f).testTag("secret_${name.name}"),
        )
        TextButton(onClick = { vm.setSecret(name, value); value = "" }) { Text(if (value.isBlank() && set) "Rimuovi" else "Salva") }
    }
}

@Composable
private fun ContactField(current: String, vm: DataSourcesViewModel) {
    var v by remember(current) { mutableStateOf(current) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        OutlinedTextField(v, { v = it }, singleLine = true, label = { Text("E-mail per User-Agent SEC") }, modifier = Modifier.weight(1f))
        TextButton(onClick = { vm.setContact(v) }) { Text("Salva") }
    }
}
