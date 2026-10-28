pluginManagement {
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MarketPilotAI"

// Pure Kotlin/JVM modules (also built standalone by jvm-check/ for fast local verification).
val jvmModules = listOf(
    ":core:model",
    ":core:common",
    ":core:network",
    ":domain:indicators",
    ":domain:market",
    ":domain:scoring",
    ":domain:risk",
    ":domain:portfolio",
    ":domain:papertrading",
    ":domain:backtesting",
    ":data:providers",
)
jvmModules.forEach { include(it) }

include(
    ":app",
    ":core:database",
    ":core:datastore",
    ":core:security",
    ":core:designsystem",
    ":data:repositories",
    ":feature:onboarding",
    ":feature:home",
    ":feature:etf",
    ":feature:toptrade",
    ":feature:stockdetail",
    ":feature:reddit",
    ":feature:insiders",
    ":feature:news",
    ":feature:watchlist",
    ":feature:portfolio",
    ":feature:simulator",
    ":feature:journal",
    ":feature:settings",
)
