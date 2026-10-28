plugins {
    id("marketpilot.android.library")
    alias(libs.plugins.kotlin.serialization)
}

android { namespace = "com.marketpilot.core.datastore" }

dependencies {
    api(libs.androidx.datastore.preferences)
    api(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
}
