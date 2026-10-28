package com.marketpilot.core.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import java.util.UUID

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "marketpilot_settings")

/** Settings persisted as one versionable JSON document in Preferences DataStore. */
class SettingsStore(private val dataStore: DataStore<Preferences>) {
    constructor(context: Context) : this(context.settingsDataStore)

    private val key = stringPreferencesKey("settings_json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    val settings: Flow<AppSettings> = dataStore.data.map { prefs ->
        prefs[key]?.let { runCatching { json.decodeFromString(AppSettings.serializer(), it) }.getOrNull() } ?: AppSettings()
    }

    suspend fun current(): AppSettings = settings.first()

    suspend fun update(transform: (AppSettings) -> AppSettings): AppSettings {
        var result = AppSettings()
        dataStore.edit { prefs ->
            val cur = prefs[key]?.let { runCatching { json.decodeFromString(AppSettings.serializer(), it) }.getOrNull() } ?: AppSettings()
            val withId = if (cur.deviceId.isBlank()) cur.copy(deviceId = UUID.randomUUID().toString()) else cur
            result = transform(withId)
            prefs[key] = json.encodeToString(AppSettings.serializer(), result)
        }
        return result
    }

    fun encode(s: AppSettings): String = json.encodeToString(AppSettings.serializer(), s)
    fun decode(s: String): AppSettings = json.decodeFromString(AppSettings.serializer(), s)
}
