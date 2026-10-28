plugins {
    id("marketpilot.android.feature")
}

android { namespace = "com.marketpilot.feature.settings" }

dependencies {
    implementation(libs.androidx.activity.compose)
}
