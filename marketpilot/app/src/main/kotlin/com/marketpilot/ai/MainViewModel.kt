package com.marketpilot.ai

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.ai.work.WorkScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
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
    private val _state = MutableStateFlow(StartState.LOADING)
    val state: StateFlow<StartState> = _state

    init {
        viewModelScope.launch {
            market.ensureCatalog()
            val s = settings.current()
            _state.value = if (s.onboardingCompleted) StartState.MAIN else StartState.ONBOARDING
            if (s.onboardingCompleted) startup()
        }
    }

    /** On every launch: reconcile pending paper orders with stored data (works offline, no look-ahead). */
    private fun startup() = viewModelScope.launch {
        runCatching { portfolio.reconcile() }
        scheduler.apply(settings.current())
    }

    fun onboardingDone() {
        _state.value = StartState.MAIN
        startup()
    }
}
