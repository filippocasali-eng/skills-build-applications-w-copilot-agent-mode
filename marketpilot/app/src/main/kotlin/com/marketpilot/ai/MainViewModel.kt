package com.marketpilot.ai

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marketpilot.ai.work.WorkScheduler
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class StartState { LOADING, ONBOARDING, MAIN }

@HiltViewModel
class MainViewModel @Inject constructor(
    private val settings: SettingsRepository,
    private val market: MarketDataRepository,
    private val portfolio: PortfolioRepository,
    private val scheduler: WorkScheduler,
) : ViewModel() {
    private var started = false

    val state: StateFlow<StartState> = settings.settings
        .map { if (it.onboardingCompleted) StartState.MAIN else StartState.ONBOARDING }
        .distinctUntilChanged()
        .onStart { market.ensureCatalog() }
        .onEach { if (it == StartState.MAIN) startup() }
        .stateIn(viewModelScope, SharingStarted.Eagerly, StartState.LOADING)

    /** Once per process: reconcile pending paper orders with stored data (works offline, no look-ahead). */
    private fun startup() {
        if (started) return
        started = true
        viewModelScope.launch {
            runCatching { portfolio.reconcile() }
            scheduler.apply(settings.current())
        }
    }

    fun onboardingDone() = Unit // state follows the persisted settings
}
