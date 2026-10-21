import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Push notifications need app/google-services.json from the Firebase console (see docs/push-setup.md).
// Without it the app still builds and runs, it just receives no pushes.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// The map needs a Google Maps key: put  MAPS_API_KEY=...  in android/local.properties (see docs/maps-setup.md).
// Without it the app still builds and runs; only the "choose on the map" screen is switched off.
val mapsApiKey: String = Properties().let { props ->
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { props.load(it) }
    props.getProperty("MAPS_API_KEY", "").trim()
}

android {
    namespace = "com.plantapp"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.plantapp.iraq"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.2.0"

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        buildConfigField("boolean", "MAPS_ENABLED", mapsApiKey.isNotEmpty().toString())
        buildConfigField("String", "SUPABASE_URL", "\"${providers.gradleProperty("SUPABASE_URL").get()}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${providers.gradleProperty("SUPABASE_ANON_KEY").get()}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)

    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.storage)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(libs.androidx.exifinterface)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.play.services.maps)
    implementation(libs.play.services.location)
    implementation(libs.maps.compose)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.kotlinx.serialization.json)

    debugImplementation(libs.androidx.compose.ui.tooling)
}
