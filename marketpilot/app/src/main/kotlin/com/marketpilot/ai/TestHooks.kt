package com.marketpilot.ai

import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.data.repositories.ExportRepository
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.RefreshEngine
import com.marketpilot.data.repositories.SettingsRepository
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/** Entry point used by the on-device end-to-end tests to verify persisted state (read-mostly). */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface TestHooks {
    fun db(): MarketPilotDatabase
    fun portfolio(): PortfolioRepository
    fun market(): MarketDataRepository
    fun export(): ExportRepository
    fun engine(): RefreshEngine
    fun settings(): SettingsRepository
}
