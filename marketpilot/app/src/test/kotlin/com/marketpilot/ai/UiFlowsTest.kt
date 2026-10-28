package com.marketpilot.ai

import android.content.Context
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.testing.WorkManagerTestInitHelper
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.core.database.CandleEntity
import com.marketpilot.core.database.FxRateEntity
import com.marketpilot.core.database.MacroObservationEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.data.repositories.MarketDataRepository
import com.marketpilot.data.repositories.PortfolioRepository
import com.marketpilot.data.repositories.RefreshEngine
import com.marketpilot.data.repositories.RefreshTrigger
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.domain.portfolio.AccountType
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import dagger.hilt.android.testing.HiltTestApplication
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject

/**
 * UI flows on Robolectric with the real screens, view models and repositories. The data module is
 * replaced (TestDataModule): offline network, in-memory database. Price bars used here are
 * deterministic synthetic test fixtures, never shown in the production app.
 */
@HiltAndroidTest
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class, sdk = [34], qualifiers = "w411dp-h891dp-xxhdpi")
class UiFlowsTest {
    @get:Rule(order = 0) val hilt = HiltAndroidRule(this)
    @get:Rule(order = 1) val compose = createAndroidComposeRule<MainActivity>()

    @Inject lateinit var db: MarketPilotDatabase
    @Inject lateinit var settings: SettingsRepository
    @Inject lateinit var market: MarketDataRepository
    @Inject lateinit var portfolio: PortfolioRepository
    @Inject lateinit var engine: RefreshEngine

    @Before fun setUp() {
        // WorkManager is initialised on demand in production (Configuration.Provider); tests use the test executor.
        WorkManagerTestInitHelper.initializeTestWorkManager(ApplicationProvider.getApplicationContext<Context>(), Configuration.Builder().build())
        hilt.inject()
    }

    private fun waitForTag(tag: String, timeout: Long = 15_000) =
        compose.waitUntil(timeout) { compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }

    private fun waitForText(text: String, timeout: Long = 15_000) =
        compose.waitUntil(timeout) { compose.onAllNodes(hasText(text, substring = true)).fetchSemanticsNodes().isNotEmpty() }

    /** Lazy lists only compose visible items: keep scrolling the container until the node exists. */
    private fun scrollUntil(container: String, matcher: SemanticsMatcher, timeout: Long = 15_000) =
        compose.waitUntil(timeout) { runCatching { compose.onNodeWithTag(container).performScrollToNode(matcher) }.isSuccess }

    private fun completeOnboardingDirectly() = runBlocking {
        market.ensureCatalog()
        settings.update { it.copy(onboardingCompleted = true) }
    }

    /** Recreates the activity (configuration-change style); persisted state must survive it. */
    private fun relaunch() {
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
    }

    private fun seed() = runBlocking {
        market.ensureCatalog()
        val end = MarketSessions.lastCompletedSession(Calendars.NYSE, Instant.now())
        fun series(id: String, exchange: String, drift: Double, base: Double): List<CandleEntity> {
            val cal = Calendars.forExchange(exchange)
            val dates = ArrayDeque<LocalDate>()
            var d = MarketSessions.lastCompletedSession(cal, Instant.now())
            while (dates.size < 320) { if (cal.isTradingDay(d)) dates.addFirst(d); d = d.minusDays(1) }
            return dates.mapIndexed { i, date ->
                val p = base * Math.pow(1 + drift, i.toDouble()) * (1 + 0.01 * kotlin.math.sin(i / 5.0))
                CandleEntity(id, date.toEpochDay(), p * 0.997, p * 1.01, p * 0.99, p, null, 3_000_000, "test", 0)
            }
        }
        val rows = mutableListOf<CandleEntity>()
        rows += series(InstrumentCatalog.SPY, "NYSEARCA", 0.0006, 500.0)
        rows += series(InstrumentCatalog.QQQ, "NASDAQ", 0.0008, 400.0)
        InstrumentCatalog.sectorEtfs.forEach { rows += series(it.id, it.exchange, 0.0005, 80.0) }
        InstrumentCatalog.stockUniverse.take(30).forEachIndexed { i, s -> rows += series(s.id, s.exchange, 0.0002 * (i % 7), 50.0 + i) }
        InstrumentCatalog.ucitsEtfs.forEach { rows += series(it.id, it.exchange, 0.0004, 100.0) }
        db.candleDao().upsert(rows)
        db.macroDao().upsertMacro((0 until 40).map { MacroObservationEntity("VIX", end.minusDays(39L - it).toEpochDay(), 15.0, "test") })
        db.macroDao().upsertFx((0 until 400).map { FxRateEntity("USD", end.minusDays(399L - it).toEpochDay(), 1.10, "test") })
        engine.refresh(RefreshTrigger.MANUAL)
    }

    @Test fun firstLaunchOnboardingConfiguresCapital() {
        waitForTag("onboarding")
        compose.onNodeWithTag("onboarding_next").performClick()
        compose.onNodeWithTag("etf_capital").performTextInput("10000")
        compose.onNodeWithTag("trading_capital").performTextInput("5000")
        compose.onNodeWithTag("onboarding_next").performClick()
        compose.onNodeWithTag("onboarding_next").performClick()
        compose.onNodeWithTag("onboarding_next").performClick()
        compose.onNodeWithTag("onboarding_finish").performClick()
        waitForTag("bottom_bar")
        compose.onNodeWithTag("tab_portfolio").performClick()
        waitForTag("equity_value")
        waitForText("10.000,00")
        runBlocking {
            check(portfolio.snapshot(AccountType.TRADING).cashEur == 5_000.0)
            check(settings.current().onboardingCompleted)
        }
    }

    @Test fun navigationBetweenAllTabsAndSecondaryScreens() {
        completeOnboardingDirectly()
        relaunch()
        waitForTag("bottom_bar")
        listOf("etf" to "etf_radar", "toptrade" to "toptrade", "simulator" to "simulator", "portfolio" to "portfolio", "home" to "home").forEach { (tab, screen) ->
            compose.onNodeWithTag("tab_$tab").performClick()
            waitForTag(screen)
        }
        listOf("news", "insiders", "reddit", "watchlist", "journal", "tracker", "datasources", "settings").forEach { route ->
            compose.onNodeWithTag("home_menu").performClick()
            compose.onNodeWithTag("menu_$route").performClick()
            waitForTag(route)
            compose.onNodeWithTag("back").performClick()
            waitForTag("home")
        }
    }

    @Test fun manualRefreshOfflineKeepsCacheAndSaysSo() {
        completeOnboardingDirectly()
        relaunch()
        waitForTag("refresh_button")
        compose.onNodeWithTag("refresh_button").performClick()
        waitForText("Aggiornamento parziale", 30_000)
        compose.onNodeWithTag("regime_label", useUnmergedTree = true).assertExists()
    }

    @Test fun etfAndStockDetailWithCachedData() {
        completeOnboardingDirectly()
        seed()
        relaunch()
        compose.onNodeWithTag("tab_etf").performClick()
        waitForTag("etf_radar")
        scrollUntil("etf_radar", hasTestTag("etf_VWCE"))
        compose.onNodeWithTag("etf_VWCE").performClick()
        waitForTag("etf_detail")
        scrollUntil("etf_detail", hasTestTag("entry_comparison"))
        compose.onNodeWithTag("back").performClick()
        runBlocking { market.addToWatchlist(InstrumentCatalog.stockId("AAPL")) }
        compose.onNodeWithTag("tab_home").performClick()
        compose.onNodeWithTag("home_menu").performClick()
        compose.onNodeWithTag("menu_watchlist").performClick()
        waitForTag("watch_AAPL")
        compose.onNodeWithTag("watch_AAPL").performClick()
        waitForTag("stock_detail")
        scrollUntil("stock_detail", hasTestTag("decision_card"))
        compose.onNodeWithTag("decision_card").assertExists()
    }

    @Test fun paperOrderCreationAndCancellation() {
        completeOnboardingDirectly()
        seed()
        runBlocking { portfolio.deposit(AccountType.TRADING, 10_000.0) }
        relaunch()
        compose.onNodeWithTag("tab_simulator").performClick()
        waitForTag("new_order")
        compose.onNodeWithTag("new_order").performClick()
        waitForTag("ticket_search")
        compose.onNodeWithTag("ticket_search").performTextInput("AAPL")
        waitForTag("result_AAPL")
        compose.onNodeWithTag("result_AAPL").performClick()
        waitForTag("ticket_qty")
        scrollUntil("ticket", hasTestTag("ticket_qty"))
        compose.onNodeWithTag("ticket_qty").performTextReplacement("2")
        scrollUntil("ticket", hasTestTag("ticket_place"))
        compose.onNodeWithTag("ticket_place").performClick()
        scrollUntil("ticket", hasText("Ordine simulato registrato", substring = true))
        scrollUntil("ticket", hasTestTag("ticket_done"))
        compose.onNodeWithTag("ticket_done").performClick()
        scrollUntil("simulator", hasTestTag("order_card"))
        scrollUntil("simulator", hasTestTag("cancel_order"))
        compose.onNodeWithTag("cancel_order").performClick()
        scrollUntil("simulator", hasText("Ordine annullato"))
        runBlocking { check(portfolio.orders().single().status.name == "CANCELLED") }
    }

    @Test fun journalEntryIsSavedAndPersists() {
        completeOnboardingDirectly()
        relaunch()
        waitForTag("home_menu")
        compose.onNodeWithTag("home_menu").performClick()
        compose.onNodeWithTag("menu_journal").performClick()
        waitForTag("journal_new")
        compose.onNodeWithTag("journal_new").performClick()
        waitForTag("journal_editor")
        compose.onNodeWithTag("journal_title").performTextInput("Test SXR8")
        compose.onNodeWithTag("journal_body").performTextInput("Ingresso a tranche, nessuna fretta.")
        compose.onNodeWithTag("journal_save").performClick()
        waitForTag("journal_entry")
        relaunch()
        compose.onNodeWithTag("home_menu").performClick()
        compose.onNodeWithTag("menu_journal").performClick()
        waitForText("Test SXR8")
    }
}
