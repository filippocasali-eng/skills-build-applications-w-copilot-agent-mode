package com.marketpilot.core.datastore

import kotlinx.serialization.Serializable

/**
 * Non-secret user configuration. Capital defaults to zero: the app never assumes the user's wealth.
 * API keys are NOT stored here (see core/security).
 */
@Serializable
data class AppSettings(
    val onboardingCompleted: Boolean = false,
    val baseCurrency: String = "EUR",
    val monthlyEtfContribution: Double = 0.0,
    val preferredEtfIds: List<String> = emptyList(),
    val preferredStocks: List<String> = emptyList(),
    val risk: RiskSettings = RiskSettings(),
    val weights: WeightSettings = WeightSettings(),
    val fees: FeeSettings = FeeSettings(),
    val simulation: SimulationSettings = SimulationSettings(),
    val providers: ProviderPrefs = ProviderPrefs(),
    val cache: CacheSettings = CacheSettings(),
    val notifications: NotificationSettings = NotificationSettings(),
    val deviceId: String = "",
)

@Serializable
data class RiskSettings(
    val riskPerTrade: Double = 0.005,
    val maxPositionExposure: Double = 0.15,
    val maxOpenPositions: Int = 3,
    val maxAggregateOpenRisk: Double = 0.02,
    val minRiskReward: Double = 2.0,
)

@Serializable
data class WeightSettings(
    val momentum: Double = 0.25,
    val technical: Double = 0.20,
    val fundamental: Double = 0.15,
    val insider: Double = 0.10,
    val institutional: Double = 0.10,
    val reddit: Double = 0.10,
    val news: Double = 0.05,
    val liquidity: Double = 0.05,
)

/** Defaults are zero commissions and small spread/slippage assumptions; the user should set their broker's costs. */
@Serializable
data class FeeSettings(
    val fixedPerOrder: Double = 0.0,
    val percentPerOrder: Double = 0.0,
    val minPerOrder: Double = 0.0,
    val maxPerOrder: Double? = null,
    val fxConversionCost: Double = 0.0,
    val halfSpread: Double = 0.0005,
    val slippage: Double = 0.0005,
    val stopExtraSlippage: Double = 0.001,
)

@Serializable
data class SimulationSettings(
    val sameBarExitPolicy: String = "CONSERVATIVE",
    val limitRequiresPenetration: Boolean = true,
    val maxParticipationOfBarVolume: Double? = 0.10,
)

@Serializable
data class ProviderPrefs(
    val enabled: Map<String, Boolean> = emptyMap(),
    val secContactEmail: String = "",
    val trackedManagers: List<String> = emptyList(),
)

@Serializable
data class CacheSettings(
    val historyYears: Int = 3,
    val newsRetentionDays: Int = 30,
)

@Serializable
data class NotificationSettings(
    val dailyReminderEnabled: Boolean = false,
    val dailyReminderHour: Int = 18,
    val alertsEnabled: Boolean = true,
    val backgroundRefreshEnabled: Boolean = true,
)
