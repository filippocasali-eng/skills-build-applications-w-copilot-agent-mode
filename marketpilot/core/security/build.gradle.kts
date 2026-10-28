plugins {
    id("marketpilot.android.library")
}

android { namespace = "com.marketpilot.core.security" }

dependencies {
    implementation(libs.kotlinx.coroutines.android)
}
