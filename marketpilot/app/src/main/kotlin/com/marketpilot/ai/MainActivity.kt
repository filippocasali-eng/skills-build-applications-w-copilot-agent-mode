package com.marketpilot.ai

import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountBalanceWallet
import androidx.compose.material.icons.outlined.CandlestickChart
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.Today
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.marketpilot.core.designsystem.MarketPilotTheme
import com.marketpilot.core.designsystem.MpColors
import com.marketpilot.feature.etf.EtfDetailScreen
import com.marketpilot.feature.etf.EtfRadarScreen
import com.marketpilot.feature.home.HomeScreen
import com.marketpilot.feature.insiders.InsiderRadarScreen
import com.marketpilot.feature.journal.DecisionTrackerScreen
import com.marketpilot.feature.journal.JournalScreen
import com.marketpilot.feature.news.NewsScreen
import com.marketpilot.feature.onboarding.OnboardingScreen
import com.marketpilot.feature.portfolio.PortfolioScreen
import com.marketpilot.feature.reddit.RedditRadarScreen
import com.marketpilot.feature.settings.DataSourcesScreen
import com.marketpilot.feature.settings.SettingsScreen
import com.marketpilot.feature.simulator.SimulatorScreen
import com.marketpilot.feature.simulator.TicketScreen
import com.marketpilot.feature.stockdetail.StockDetailScreen
import com.marketpilot.feature.toptrade.TopTradeScreen
import com.marketpilot.feature.watchlist.WatchlistScreen
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { MarketPilotTheme { MarketPilotRoot() } }
    }
}

private data class Tab(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    Tab("home", "Oggi", Icons.Outlined.Today),
    Tab("etf", "ETF", Icons.Outlined.PieChart),
    Tab("toptrade", "Top Trade", Icons.Outlined.TrendingUp),
    Tab("simulator", "Simulatore", Icons.Outlined.CandlestickChart),
    Tab("portfolio", "Portafoglio", Icons.Outlined.AccountBalanceWallet),
)

/** Stock ids end with ":US"; everything else in the catalog is an ETF/index listing. */
fun detailRoute(instrumentId: String): String =
    if (instrumentId.endsWith(":US")) "stock/${Uri.encode(instrumentId)}" else "etf/${Uri.encode(instrumentId)}"

@Composable
fun MarketPilotRoot(vm: MainViewModel = hiltViewModel()) {
    val ready by vm.state.collectAsStateWithLifecycle()
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(ready) {
        if (ready == StartState.MAIN && Build.VERSION.SDK_INT >= 33) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
    when (ready) {
        StartState.LOADING -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = MpColors.Positive) }
        StartState.ONBOARDING -> OnboardingScreen(onFinished = vm::onboardingDone)
        StartState.MAIN -> MainNav()
    }
}

@Composable
private fun MainNav() {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val current = backStack?.destination?.route
    val showBar = tabs.any { it.route == current }
    Scaffold(
        containerColor = MpColors.Background,
        bottomBar = {
            if (showBar) {
                NavigationBar(containerColor = MpColors.Surface, modifier = Modifier.testTag("bottom_bar")) {
                    tabs.forEach { t ->
                        NavigationBarItem(
                            selected = current == t.route,
                            onClick = { nav.navigateTab(t.route) },
                            icon = { Icon(t.icon, contentDescription = t.label) },
                            label = { Text(t.label) },
                            modifier = Modifier.testTag("tab_${t.route}"),
                            colors = NavigationBarItemDefaults.colors(selectedIconColor = MpColors.Positive, selectedTextColor = MpColors.Positive, indicatorColor = MpColors.SurfaceHigh),
                        )
                    }
                }
            }
        },
    ) { pad ->
        NavHost(nav, startDestination = "home", modifier = Modifier.padding(pad)) {
            val back: () -> Unit = { nav.popBackStack() }
            composable("home") {
                HomeScreen(onOpenStock = { nav.navigate(detailRoute(it)) }, onOpenEtf = { nav.navigate(detailRoute(it)) }, onNavigate = { r ->
                    if (tabs.any { it.route == r }) nav.navigateTab(r) else nav.navigate(r)
                })
            }
            composable("etf") { EtfRadarScreen(onOpen = { nav.navigate(detailRoute(it)) }) }
            composable("toptrade") { TopTradeScreen(onOpen = { nav.navigate(detailRoute(it)) }) }
            composable("simulator") { SimulatorScreen(onNewOrder = { nav.navigate("ticket") }) }
            composable("portfolio") { PortfolioScreen(onOpenInstrument = { nav.navigate(detailRoute(it)) }) }
            composable("etf/{id}", arguments = listOf(navArgument("id") { type = NavType.StringType })) {
                EtfDetailScreen(onBack = back, onTrade = { id -> nav.navigate("ticket?instrumentId=${Uri.encode(id)}&account=ETF") })
            }
            composable("stock/{id}", arguments = listOf(navArgument("id") { type = NavType.StringType })) {
                StockDetailScreen(
                    onBack = back,
                    onTrade = { id -> nav.navigate("ticket?instrumentId=${Uri.encode(id)}&account=TRADING") },
                    onJournal = { id -> nav.navigate("journal?instrumentId=${Uri.encode(id)}") },
                )
            }
            composable(
                "ticket?instrumentId={instrumentId}&account={account}",
                arguments = listOf(
                    navArgument("instrumentId") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("account") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { TicketScreen(onBack = back, onDone = { nav.navigateTab("simulator") }) }
            composable(
                "journal?instrumentId={instrumentId}",
                arguments = listOf(navArgument("instrumentId") { type = NavType.StringType; nullable = true; defaultValue = null }),
            ) { JournalScreen(onBack = back, onTracker = { nav.navigate("tracker") }) }
            composable("tracker") { DecisionTrackerScreen(onBack = back) }
            composable("watchlist") { WatchlistScreen(onBack = back, onOpen = { nav.navigate(detailRoute(it.id)) }) }
            composable("news") { NewsScreen(onBack = back) }
            composable("insiders") { InsiderRadarScreen(onBack = back, onOpenStock = { nav.navigate(detailRoute(it)) }) }
            composable("reddit") { RedditRadarScreen(onBack = back, onOpenStock = { nav.navigate(detailRoute(it)) }, onConfigure = { nav.navigate("datasources") }) }
            composable("settings") { SettingsScreen(onBack = back, onDataSources = { nav.navigate("datasources") }) }
            composable("datasources") { DataSourcesScreen(onBack = back) }
        }
    }
}

private fun NavHostController.navigateTab(route: String) = navigate(route) {
    popUpTo(graph.findStartDestination().id) { saveState = true }
    launchSingleTop = true
    restoreState = true
}
