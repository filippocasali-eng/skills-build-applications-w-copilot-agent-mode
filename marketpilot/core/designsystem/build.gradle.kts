plugins {
    id("marketpilot.android.library")
    id("marketpilot.android.compose")
}

android { namespace = "com.marketpilot.core.designsystem" }

dependencies {
    api(project(":core:model"))
    implementation(project(":core:common"))
}
