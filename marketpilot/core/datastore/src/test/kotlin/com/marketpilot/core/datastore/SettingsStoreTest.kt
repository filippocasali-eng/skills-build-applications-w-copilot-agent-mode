package com.marketpilot.core.datastore

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SettingsStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test fun defaultsAreConservativeAndPersist() = runBlocking {
        val store = SettingsStore(PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob())) { tmp.newFile("s.preferences_pb") })
        val d = store.current()
        assertEquals(0.0, d.monthlyEtfContribution)
        assertEquals(0.005, d.risk.riskPerTrade)
        assertEquals(3, d.risk.maxOpenPositions)
        assertEquals(2.0, d.risk.minRiskReward)
        val updated = store.update { it.copy(onboardingCompleted = true, monthlyEtfContribution = 300.0) }
        assertTrue(updated.deviceId.isNotBlank())
        assertEquals(300.0, store.current().monthlyEtfContribution)
        assertTrue(store.current().onboardingCompleted)
        assertEquals(store.current(), store.decode(store.encode(store.current())))
    }
}
