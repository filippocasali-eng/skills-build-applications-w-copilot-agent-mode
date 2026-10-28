package com.marketpilot.ai

import android.Manifest
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.rule.GrantPermissionRule
import com.marketpilot.core.common.Calendars
import com.marketpilot.core.common.InstrumentCatalog
import com.marketpilot.core.common.MarketSessions
import com.marketpilot.data.repositories.toEntity
import com.marketpilot.domain.papertrading.OrderPlacement
import com.marketpilot.domain.papertrading.OrderRole
import com.marketpilot.domain.papertrading.OrderSide
import com.marketpilot.domain.papertrading.OrderStatus
import com.marketpilot.domain.papertrading.OrderType
import com.marketpilot.domain.papertrading.PaperOrder
import com.marketpilot.domain.portfolio.AccountType
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * Full journey on a real Android device/emulator with REAL network access (no mocks):
 * install → open → configure capital → fetch real data → analyse ETF → analyse stock →
 * create paper order → reconcile a pending order with eligible real bars → review portfolio →
 * recreate the activity → verify persistence → export data.
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class EndToEndTest {
    // Without this the system permission dialog pauses the activity right after onboarding.
    @get:Rule(order = 0) val notifications: GrantPermissionRule =
        if (Build.VERSION.SDK_INT >= 33) GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS) else GrantPermissionRule.grant()

    @get:Rule(order = 1) val compose = createAndroidComposeRule<MainActivity>()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val hooks: TestHooks by lazy { EntryPointAccessors.fromApplication(context, TestHooks::class.java) }

    private fun waitTag(tag: String, ms: Long = 30_000) = compose.waitUntil(ms) { compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }
    private fun waitText(text: String, ms: Long = 30_000) = compose.waitUntil(ms) { compose.onAllNodes(hasText(text, substring = true)).fetchSemanticsNodes().isNotEmpty() }
    /** Lazy lists only compose visible items: keep scrolling the container until the node exists. */
    private fun scrollUntil(container: String, matcher: SemanticsMatcher, ms: Long = 30_000) =
        compose.waitUntil(ms) { runCatching { compose.onNodeWithTag(container).performScrollToNode(matcher) }.isSuccess }

    private fun log(msg: String) = Log.i("MarketPilotE2E", msg)

    @Test fun fullJourneyWithRealData() {
        // 1-3. First launch and capital configuration
        waitTag("onboarding")
        compose.onNodeWithTag("onboarding_next").performClick()
        compose.onNodeWithTag("etf_capital").performTextInput("20000")
        compose.onNodeWithTag("trading_capital").performTextInput("10000")
        repeat(3) { compose.onNodeWithTag("onboarding_next").performClick() }
        compose.onNodeWithTag("onboarding_finish").performClick()
        waitTag("refresh_button")

        // 4. Real market refresh (all free providers, real network)
        compose.onNodeWithTag("refresh_button").performClick()
        compose.waitUntil(600_000) {
            compose.onAllNodes(hasText("Aggiornamento completato", substring = true)).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodes(hasText("Aggiornamento parziale", substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        val lastCompleted = MarketSessions.lastCompletedSession(Calendars.NYSE, Instant.now())
        runBlocking {
            val spy = hooks.market().candles(InstrumentCatalog.SPY)
            log("SPY bars=${spy.size} last=${spy.lastOrNull()?.date} expectedLastCompleted=$lastCompleted")
            assertTrue("Real SPY history downloaded", spy.size > 200)
            assertTrue("SPY data is recent", !spy.last().date.isBefore(lastCompleted.minusDays(5)))
            val a = hooks.db().analysisDao().latestAssessment()
            log("Assessment regime=${a?.regime} score=${a?.marketScore} coverage=${a?.coverage}")
            assertTrue(a != null)
            val statuses = hooks.db().providerStatusDao().observeAll().first()
            statuses.forEach { log("Provider ${it.providerId}: ${it.state} lastError=${it.lastError}") }
        }

        // 5. ETF analysis
        compose.onNodeWithTag("tab_etf").performClick()
        waitTag("etf_radar")
        scrollUntil("etf_radar", hasTestTag("etf_VWCE"))
        compose.onNodeWithTag("etf_VWCE").performClick()
        waitTag("etf_detail")
        compose.onNodeWithTag("back").performClick()

        // 6. Stock analysis (also exercises on-demand SEC fundamentals/insiders)
        compose.onNodeWithTag("tab_home").performClick()
        compose.onNodeWithTag("home_menu").performClick()
        compose.onNodeWithTag("menu_watchlist").performClick()
        waitTag("watch_input")
        compose.onNodeWithTag("watch_input").performTextInput("MSFT")
        compose.onNodeWithTag("watch_add").performClick()
        waitTag("watch_MSFT")
        compose.onNodeWithTag("watch_MSFT").performClick()
        waitTag("stock_detail")
        scrollUntil("stock_detail", hasTestTag("decision_card"))
        compose.onNodeWithTag("back").performClick()
        compose.onNodeWithTag("back").performClick()

        // 7. Paper order through the ticket UI
        compose.onNodeWithTag("tab_simulator").performClick()
        waitTag("new_order")
        compose.onNodeWithTag("new_order").performClick()
        compose.onNodeWithTag("ticket_search").performTextInput("SPY")
        waitTag("result_SPY")
        compose.onNodeWithTag("result_SPY").performClick()
        scrollUntil("ticket", hasTestTag("ticket_qty"))
        compose.onNodeWithTag("ticket_qty").performTextReplacement("1")
        scrollUntil("ticket", hasTestTag("ticket_place"))
        compose.onNodeWithTag("ticket_place").performClick()
        compose.waitUntil(30_000) { runBlocking { hooks.portfolio().orders().isNotEmpty() } }
        runBlocking {
            val placed = hooks.portfolio().orders().single()
            log("Ticket order status=${placed.status} limit=${placed.limitPrice} qty=${placed.quantity} reason=${placed.statusReason}")
            assertTrue("Ticket order accepted: ${placed.statusReason}", placed.status != OrderStatus.REJECTED)
        }

        // 8. Reconciliation of an order that was pending while the app was closed: an order created
        //    10 sessions ago must fill on the first session after its creation, from real bars only.
        runBlocking {
            val spyBars = hooks.market().candles(InstrumentCatalog.SPY)
            val createdDay = spyBars[spyBars.size - 11].date
            val createdAt = createdDay.atTime(21, 0).toInstant(ZoneOffset.UTC) // after the US close
            val expected = Calendars.NYSE.nextTradingDay(createdDay)
            val order = PaperOrder(
                id = "e2e-past-order", account = AccountType.TRADING, instrumentId = InstrumentCatalog.SPY, exchange = "NYSEARCA", currency = "USD",
                side = OrderSide.BUY, type = OrderType.MARKET, quantity = 1, createdAt = createdAt,
                firstEligibleSession = OrderPlacement.firstEligibleSession("NYSEARCA", createdAt), role = OrderRole.ENTRY, reservedCashEur = 1_000.0,
            )
            hooks.db().paperTradingDao().upsertOrders(listOf(order.toEntity(Instant.now())))
            hooks.portfolio().reconcile()
            val after = hooks.portfolio().orders().first { it.id == order.id }
            log("Past order status=${after.status} reason=${after.statusReason}")
            assertEquals(OrderStatus.FILLED, after.status)
            val fill = hooks.db().paperTradingDao().observeFills().first().first { it.orderId == order.id }
            assertEquals(expected.toEpochDay(), fill.sessionEpochDay)
            val bar = spyBars.first { it.date == expected }
            assertTrue("fill derived from that session's real open", fill.priceCcy >= bar.open)
        }

        // 9. Portfolio review
        compose.onNodeWithTag("tab_portfolio").performClick()
        waitTag("account_tabs")
        waitTag("equity_value")

        // 10. Restart (activity recreation) and persistence
        compose.activityRule.scenario.recreate()
        waitTag("bottom_bar")
        runBlocking {
            assertTrue(hooks.settings().current().onboardingCompleted)
            assertEquals(20_000.0, hooks.portfolio().snapshot(AccountType.ETF).cashEur, 0.001)
            assertTrue(hooks.portfolio().snapshot(AccountType.TRADING).positions.isNotEmpty())
        }

        // 11. Encrypted export
        runBlocking {
            val bytes = hooks.export().export("e2e-password".toCharArray())
            assertTrue(hooks.export().isEncrypted(bytes))
            File(context.filesDir, "e2e-export.mpx").writeBytes(bytes)
            log("Export size=${bytes.size}")
        }
    }
}
