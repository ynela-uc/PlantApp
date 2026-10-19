package com.plantapp.data

import com.plantapp.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.json.Json

const val AUTH_SCHEME = "plantapp"
const val AUTH_HOST = "auth-callback"
const val AUTH_REDIRECT_URL = "$AUTH_SCHEME://$AUTH_HOST"

/** Single shared Supabase client. URL and anon key come from gradle.properties (public by design). */
object Backend {
    val client: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY,
        ) {
            // Rows carry columns the app does not model (created_at, image_path, ...): ignore them.
            // encodeDefaults: inserts must send defaults too (e.g. payment_method has no DB default).
            defaultSerializer = KotlinXSerializer(Json { ignoreUnknownKeys = true; encodeDefaults = true })
            install(Auth) {
                // Deep link used by the password-reset email: plantapp://auth-callback
                scheme = AUTH_SCHEME
                host = AUTH_HOST
            }
            install(Postgrest)
            install(Storage)
        }
    }
}
