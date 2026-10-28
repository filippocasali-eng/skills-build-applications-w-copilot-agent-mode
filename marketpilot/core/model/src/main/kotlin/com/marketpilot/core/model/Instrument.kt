package com.marketpilot.core.model

import kotlinx.serialization.Serializable

@Serializable
enum class AssetClass { ETF, STOCK, INDEX, VOLATILITY_INDEX }

@Serializable
enum class Domicile { US, IE, LU, DE, OTHER }

@Serializable
enum class DistributionPolicy { ACCUMULATING, DISTRIBUTING, NOT_APPLICABLE }

/** Role of an instrument inside the app (drives which screens and calculations use it). */
@Serializable
enum class InstrumentRole {
    /** Benchmarks used for the market regime (S&P 500 / Nasdaq 100 proxies, VIX). */
    MARKET_BENCHMARK,
    /** Sector ETFs used for sector conditions. */
    SECTOR,
    /** ETFs shown in ETF Radar. */
    ETF_RADAR,
    /** Stocks ranked by Top Trade USA. */
    STOCK_UNIVERSE,
}

/**
 * Canonical instrument identity. [id] is stable and provider independent
 * (e.g. "VWCE:XETRA"); [providerSymbols] maps provider ids to their own symbols.
 */
@Serializable
data class Instrument(
    val id: String,
    val symbol: String,
    val name: String,
    val assetClass: AssetClass,
    val exchange: String,
    val currency: String,
    val isin: String? = null,
    val trackedIndex: String? = null,
    val isUcits: Boolean = false,
    val domicile: Domicile = Domicile.US,
    val distribution: DistributionPolicy = DistributionPolicy.NOT_APPLICABLE,
    /** Total expense ratio in percent. Null when not verified from an official document. */
    val terPercent: Double? = null,
    val terVerifiedSource: String? = null,
    val providerSymbols: Map<String, String> = emptyMap(),
    val roles: Set<InstrumentRole> = emptySet(),
    val sector: String? = null,
    /** SEC Central Index Key (US issuers only). */
    val cik: String? = null,
    /** Index family used for overlap/concentration checks (e.g. "US_LARGE_CAP", "GLOBAL"). */
    val exposureFamily: String? = null,
) {
    val isUsListed: Boolean get() = exchange in US_EXCHANGES
    fun symbolFor(providerId: String): String? = providerSymbols[providerId]

    companion object {
        val US_EXCHANGES = setOf("US", "NYSE", "NASDAQ", "NYSEARCA", "CBOE", "INDEX_US")
    }
}
