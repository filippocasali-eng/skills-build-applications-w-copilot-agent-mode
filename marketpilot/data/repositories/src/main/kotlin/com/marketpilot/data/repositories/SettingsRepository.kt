package com.marketpilot.data.repositories

import com.marketpilot.core.datastore.AppSettings
import com.marketpilot.core.datastore.SettingsStore
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.core.security.SecretStore
import com.marketpilot.data.providers.ProviderSettings
import com.marketpilot.domain.papertrading.SameBarExitPolicy
import com.marketpilot.domain.papertrading.SimulationConfig
import com.marketpilot.domain.risk.FeeModel
import com.marketpilot.domain.risk.RiskParameters
import com.marketpilot.domain.scoring.ScoringWeights
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(
    private val store: SettingsStore,
    private val secrets: SecretStore,
) {
    val settings: Flow<AppSettings> = store.settings

    /** Latest settings snapshot for synchronous provider callbacks (refreshed on every read/update). */
    @Volatile private var cached: AppSettings = AppSettings()

    private val _secretsVersion = MutableStateFlow(0)
    val secretsVersion: StateFlow<Int> = _secretsVersion.asStateFlow()

    suspend fun current(): AppSettings = store.current().also { cached = it }

    suspend fun update(transform: (AppSettings) -> AppSettings): AppSettings = store.update(transform).also { cached = it }

    fun cachedSettings(): AppSettings = cached

    fun secret(name: SecretKeyName): String? = secrets.get(name)
    fun hasSecret(name: SecretKeyName): Boolean = secrets.isSet(name)
    fun setSecret(name: SecretKeyName, value: String?) {
        secrets.put(name, value)
        _secretsVersion.value++
    }

    fun providerSettings(s: AppSettings = cached): ProviderSettings = ProviderSettings(
        enabled = s.providers.enabled,
        alphaVantageKey = secrets.get(SecretKeyName.ALPHA_VANTAGE_API_KEY),
        finnhubKey = secrets.get(SecretKeyName.FINNHUB_API_KEY),
        redditClientId = secrets.get(SecretKeyName.REDDIT_CLIENT_ID),
        secContact = s.providers.secContactEmail.takeIf { it.isNotBlank() },
    )

    companion object {
        fun risk(s: AppSettings) = RiskParameters(
            riskPerTrade = s.risk.riskPerTrade, maxPositionExposure = s.risk.maxPositionExposure, maxOpenPositions = s.risk.maxOpenPositions,
            maxAggregateOpenRisk = s.risk.maxAggregateOpenRisk, minRiskReward = s.risk.minRiskReward,
        )

        fun weights(s: AppSettings) = ScoringWeights(
            s.weights.momentum, s.weights.technical, s.weights.fundamental, s.weights.insider, s.weights.institutional,
            s.weights.reddit, s.weights.news, s.weights.liquidity,
        )

        fun fees(s: AppSettings) = FeeModel(
            fixedPerOrder = s.fees.fixedPerOrder, percentPerOrder = s.fees.percentPerOrder, minPerOrder = s.fees.minPerOrder,
            maxPerOrder = s.fees.maxPerOrder, fxConversionCost = s.fees.fxConversionCost, halfSpread = s.fees.halfSpread,
            slippage = s.fees.slippage, stopExtraSlippage = s.fees.stopExtraSlippage,
        )

        fun simulation(s: AppSettings) = SimulationConfig(
            fees = fees(s),
            sameBarExitPolicy = runCatching { SameBarExitPolicy.valueOf(s.simulation.sameBarExitPolicy) }.getOrDefault(SameBarExitPolicy.CONSERVATIVE),
            limitRequiresPenetration = s.simulation.limitRequiresPenetration,
            maxParticipationOfBarVolume = s.simulation.maxParticipationOfBarVolume,
        )
    }
}
