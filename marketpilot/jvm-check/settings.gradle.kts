// Local, Android-SDK-free verification build: compiles and tests only the pure Kotlin/JVM
// modules of MarketPilot AI. The full Android build uses ../settings.gradle.kts.
pluginManagement {
    repositories {
        maven("https://maven-central.storage-download.googleapis.com/maven2")
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        maven("https://maven-central.storage-download.googleapis.com/maven2")
        mavenCentral()
    }
    versionCatalogs {
        create("libs") { from(files("../gradle/libs.versions.toml")) }
    }
}
rootProject.name = "MarketPilotAI-jvm-check"
listOf(
    ":core:model", ":core:common", ":core:network",
    ":domain:indicators", ":domain:market", ":domain:scoring", ":domain:risk",
    ":domain:portfolio", ":domain:papertrading", ":domain:backtesting",
    ":data:providers",
).forEach { path ->
    include(path)
    project(path).projectDir = file("../" + path.removePrefix(":").replace(':', '/'))
}
