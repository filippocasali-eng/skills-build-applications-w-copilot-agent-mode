package com.marketpilot.ai

import android.Manifest
import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.rule.GrantPermissionRule
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Visual tour on a real emulator with real data: saves a PNG of every screen (and of the lower part
 * of long screens) so the UI can be reviewed. Run on a fresh install (it starts from onboarding).
 * Files: <app external files>/screens/NN_name.png
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class ScreenshotTour {
    @get:Rule(order = 0) val notifications: GrantPermissionRule =
        if (Build.VERSION.SDK_INT >= 33) GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS) else GrantPermissionRule.grant()

    @get:Rule(order = 1) val compose = createAndroidComposeRule<MainActivity>()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.getExternalFilesDir(null), "screens").apply { mkdirs() }
    private var n = 0

    private fun waitTag(tag: String, ms: Long = 30_000) = compose.waitUntil(ms) { compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }

    private fun scrollUntil(container: String, matcher: SemanticsMatcher, ms: Long = 30_000) =
        compose.waitUntil(ms) { runCatching { compose.onNodeWithTag(container).performScrollToNode(matcher) }.isSuccess }

    /** Never fails the tour: a missing screen is logged and skipped. */
    private fun step(name: String, block: () -> Unit) {
        runCatching(block).onFailure { Log.e("MarketPilotTour", "Step $name failed: ${it.message}") }
    }

    private fun shot(name: String) {
        compose.waitForIdle()
        runCatching {
            val bmp = compose.onAllNodes(isRoot()).onFirst().captureToImage().asAndroidBitmap()
            File(dir, "%02d_%s.png".format(++n, name)).outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            Log.i("MarketPilotTour", "Saved $name")
        }.onFailure { Log.e("MarketPilotTour", "Screenshot $name failed: ${it.message}") }
    }

    /** Screenshot, then scroll the list down by roughly one screen and screenshot again. */
    private fun shotScrolling(container: String, name: String, pages: Int = 2) {
        shot("${name}_1")
        for (p in 2..pages) {
            runCatching { compose.onNodeWithTag(container).performTouchInput { swipeUp(durationMillis = 400) } }
            shot("${name}_$p")
        }
    }

    private fun openMenu(route: String, screen: String) {
        compose.onNodeWithTag("tab_home").performClick()
        waitTag("home_menu")
        compose.onNodeWithTag("home_menu").performClick()
        compose.onNodeWithTag("menu_$route").performClick()
        waitTag(screen)
    }

    @Test fun tour() {
        dir.listFiles()?.forEach { it.delete() }
        // Onboarding, page by page
        waitTag("onboarding")
        shot("onboarding_welcome")
        compose.onNodeWithTag("onboarding_next").performClick()
        shot("onboarding_capital_empty")
        compose.onNodeWithTag("etf_capital").performTextInput("20000")
        compose.onNodeWithTag("trading_capital").performTextInput("10000")
        shot("onboarding_capital_filled")
        repeat(3) { i ->
            compose.onNodeWithTag("onboarding_next").performClick()
            shot("onboarding_step${i + 3}")
        }
        compose.onNodeWithTag("onboarding_finish").performClick()

        // Home before and after the first real refresh
        waitTag("refresh_button")
        shot("home_before_refresh")
        compose.onNodeWithTag("refresh_button").performClick()
        compose.waitUntil(10_000) { compose.onAllNodes(hasTestTag("refresh_cancel")).fetchSemanticsNodes().isNotEmpty() }
        shot("home_refreshing")
        compose.waitUntil(600_000) {
            compose.onAllNodes(hasText("Aggiornamento completato", substring = true)).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodes(hasText("Aggiornamento parziale", substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        shotScrolling("home", "home", pages = 4)

        step("etf") {
            compose.onNodeWithTag("tab_etf").performClick()
            waitTag("etf_radar")
            shotScrolling("etf_radar", "etf_radar", pages = 3)
            scrollUntil("etf_radar", hasTestTag("etf_VWCE"))
            compose.onNodeWithTag("etf_VWCE").performClick()
            waitTag("etf_detail")
            shotScrolling("etf_detail", "etf_detail_vwce", pages = 4)
            compose.onNodeWithTag("back").performClick()
        }
        step("toptrade") {
            compose.onNodeWithTag("tab_toptrade").performClick()
            waitTag("toptrade")
            shotScrolling("toptrade", "toptrade", pages = 3)
        }
        step("stock") {
            openMenu("watchlist", "watchlist")
            compose.onNodeWithTag("watch_input").performTextInput("AAPL")
            compose.onNodeWithTag("watch_add").performClick()
            waitTag("watch_AAPL")
            shot("watchlist")
            compose.onNodeWithTag("watch_AAPL").performClick()
            waitTag("stock_detail")
            compose.waitUntil(60_000) { compose.onAllNodes(hasText("Aggiornamento dati in corso", substring = true)).fetchSemanticsNodes().isEmpty() }
            shotScrolling("stock_detail", "stock_aapl", pages = 5)
            compose.onNodeWithTag("back").performClick()
            compose.onNodeWithTag("back").performClick()
        }
        step("simulator") {
            compose.onNodeWithTag("tab_simulator").performClick()
            waitTag("new_order")
            shot("simulator_empty")
            compose.onNodeWithTag("new_order").performClick()
            waitTag("ticket_search")
            shot("ticket_empty")
            compose.onNodeWithTag("ticket_search").performTextInput("MSFT")
            waitTag("result_MSFT")
            shot("ticket_search_results")
            compose.onNodeWithTag("result_MSFT").performClick()
            waitTag("ticket_size")
            shotScrolling("ticket", "ticket_msft", pages = 3)
            compose.onNodeWithTag("back").performClick()
        }
        step("portfolio") {
            compose.onNodeWithTag("tab_portfolio").performClick()
            waitTag("equity_value")
            shotScrolling("portfolio", "portfolio", pages = 3)
        }
        listOf(
            "news" to "news", "insiders" to "insiders", "reddit" to "reddit", "journal" to "journal",
            "tracker" to "tracker", "datasources" to "datasources", "settings" to "settings",
        ).forEach { (route, screen) ->
            step(route) {
                openMenu(route, screen)
                shotScrolling(screen, route, pages = if (route in setOf("settings", "datasources", "insiders", "news")) 3 else 2)
                compose.onNodeWithTag("back").performClick()
            }
        }
        Log.i("MarketPilotTour", "Done: $n screenshots in ${dir.absolutePath}")
    }
}
