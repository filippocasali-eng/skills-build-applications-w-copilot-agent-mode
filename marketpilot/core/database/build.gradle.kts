plugins {
    id("marketpilot.android.library")
    alias(libs.plugins.ksp)
    alias(libs.plugins.room)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.marketpilot.core.database"
    sourceSets.getByName("test").assets.srcDir("$projectDir/schemas")
}

room {
    schemaDirectory("$projectDir/schemas")
}

dependencies {
    api(libs.androidx.room.runtime)
    api(libs.androidx.room.ktx)
    api(libs.kotlinx.serialization.json)
    ksp(libs.androidx.room.compiler)
    implementation(libs.kotlinx.coroutines.android)
    testImplementation(libs.androidx.room.testing)
}
