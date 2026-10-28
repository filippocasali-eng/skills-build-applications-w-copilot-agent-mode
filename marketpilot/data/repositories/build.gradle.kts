plugins {
    id("marketpilot.android.library")
    id("marketpilot.android.hilt")
    alias(libs.plugins.kotlin.serialization)
}

android { namespace = "com.marketpilot.data.repositories" }

dependencies {
    api(project(":core:model"))
    api(project(":core:common"))
    api(project(":core:database"))
    api(project(":core:datastore"))
    api(project(":core:security"))
    api(project(":data:providers"))
    api(project(":domain:backtesting"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    testImplementation(libs.okhttp.mockwebserver)
}
