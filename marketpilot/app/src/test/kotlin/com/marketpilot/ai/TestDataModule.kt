package com.marketpilot.ai

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.datastore.SettingsStore
import com.marketpilot.core.network.HostRateLimiter
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.core.security.SecretKeyName
import com.marketpilot.core.security.SecretStore
import com.marketpilot.data.providers.ProviderRegistry
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.data.repositories.di.DataModule
import com.marketpilot.data.repositories.di.NetworkMonitor
import dagger.Module
import dagger.Provides
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import java.io.File
import java.util.UUID
import javax.inject.Singleton

/** Test replacement for DataModule: in-memory DB, isolated settings, offline network, no real HTTP. */
@Module
@TestInstallIn(components = [SingletonComponent::class], replaces = [DataModule::class])
object TestDataModule {
    @Volatile var online: Boolean = false

    @Provides @Singleton
    fun db(@ApplicationContext c: Context): MarketPilotDatabase =
        Room.inMemoryDatabaseBuilder(c, MarketPilotDatabase::class.java).build()

    @Provides @Singleton
    fun settingsStore(@ApplicationContext c: Context): SettingsStore = SettingsStore(
        PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob())) { File(c.filesDir, "ui-${UUID.randomUUID()}.preferences_pb") },
    )

    @Provides @Singleton
    fun secrets(): SecretStore = object : SecretStore {
        private val m = mutableMapOf<SecretKeyName, String>()
        override fun get(name: SecretKeyName) = m[name]
        override fun put(name: SecretKeyName, value: String?) { if (value.isNullOrBlank()) m.remove(name) else m[name] = value }
    }

    @Provides @Singleton
    fun clock(): AppClock = AppClock.SYSTEM

    @Provides @Singleton
    fun network(): NetworkMonitor = NetworkMonitor { online }

    @Provides @Singleton
    fun registry(settings: SettingsRepository, clock: AppClock): ProviderRegistry {
        val offline = OkHttpClient.Builder().addInterceptor { chain ->
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(503).message("offline test").body("".toResponseBody()).build()
        }.build()
        return ProviderRegistry({ settings.providerSettings() }, { "ui-test" }, { emptyList() }, clock, HttpFetcher(offline, HostRateLimiter(emptyMap(), 0), maxAttempts = 1))
    }
}
