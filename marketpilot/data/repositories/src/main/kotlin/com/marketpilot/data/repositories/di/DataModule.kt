package com.marketpilot.data.repositories.di

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.datastore.SettingsStore
import com.marketpilot.core.security.EncryptedSecretStore
import com.marketpilot.core.security.SecretStore
import com.marketpilot.data.providers.ProviderRegistry
import com.marketpilot.data.providers.impl.TickerMapParser
import com.marketpilot.data.repositories.SettingsRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/** Abstraction over connectivity so the refresh engine can be tested offline. */
fun interface NetworkMonitor {
    fun isOnline(): Boolean
}

@Module
@InstallIn(SingletonComponent::class)
object DataModule {
    @Provides @Singleton
    fun database(@ApplicationContext context: Context): MarketPilotDatabase = MarketPilotDatabase.build(context)

    @Provides @Singleton
    fun settingsStore(@ApplicationContext context: Context): SettingsStore = SettingsStore(context)

    @Provides @Singleton
    fun secretStore(@ApplicationContext context: Context): SecretStore = EncryptedSecretStore(context)

    @Provides @Singleton
    fun clock(): AppClock = AppClock.SYSTEM

    @Provides @Singleton
    fun networkMonitor(@ApplicationContext context: Context): NetworkMonitor = NetworkMonitor {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val caps = cm?.getNetworkCapabilities(cm.activeNetwork)
        caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
    }

    @Provides @Singleton
    fun providerRegistry(settings: SettingsRepository, db: MarketPilotDatabase, clock: AppClock): ProviderRegistry {
        // Ticker map cache: loaded lazily from Room on first use by the SEC provider.
        var cache: List<TickerMapParser.Entry>? = null
        return ProviderRegistry(
            settings = { settings.providerSettings() },
            deviceId = { settings.cachedSettings().deviceId.ifBlank { "DO_NOT_TRACK_THIS_DEVICE" } },
            tickerEntries = {
                cache ?: db.alternativeDataDao().tickers().map { TickerMapParser.Entry(it.cik, it.ticker, it.title) }.also { if (it.isNotEmpty()) cache = it }
            },
            clock = clock,
        )
    }
}
