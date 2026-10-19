package com.plantapp.data

import android.util.Base64
import com.plantapp.BuildConfig
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

@Serializable
data class Tri(val en: String = "", val ar: String = "", val ckb: String = "") {
    /** Language -> text, skipping empty ones. */
    fun toMap(): Map<String, String> =
        mapOf("en" to en, "ar" to ar, "ckb" to ckb).filterValues { it.isNotBlank() }
}

@Serializable
data class AiCare(val water: Tri = Tri(), val light: Tri = Tri(), val fertilizer: Tri = Tri())

/** What the identify-plant function returns for one photo. */
@Serializable
data class PlantSuggestion(
    val identified: Boolean = false,
    val confidence: String = "low",
    @SerialName("plant_key") val plantKey: String = "Other",
    @SerialName("scientific_name") val scientificName: String = "",
    val name: Tri = Tri(),
    val description: Tri = Tri(),
    val care: AiCare = AiCare(),
    @SerialName("height_cm") val heightCm: Int = 0,
)

/** Why the AI could not help (the editor then lets the seller type everything in). */
class AiException(val kind: Kind) : Exception(kind.name) {
    enum class Kind { NotConfigured, LimitReached, Network, Failed }
}

class AiRepository {
    private val json = Json { ignoreUnknownKeys = true }

    /** Sends one JPEG to the identify-plant edge function (which holds the AI key) and returns suggestions. */
    suspend fun identify(jpeg: ByteArray): PlantSuggestion = withContext(Dispatchers.IO) {
        val token = Backend.client.auth.currentAccessTokenOrNull() ?: throw AiException(AiException.Kind.Failed)
        val body = buildJsonObject {
            put("image_base64", Base64.encodeToString(jpeg, Base64.NO_WRAP))
            put("media_type", "image/jpeg")
        }.toString()

        val connection = (URL("${BuildConfig.SUPABASE_URL}/functions/v1/identify-plant").openConnection() as HttpURLConnection)
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 60_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("apikey", BuildConfig.SUPABASE_ANON_KEY)
            connection.outputStream.use { it.write(body.toByteArray()) }

            val code = connection.responseCode
            val text = (if (code in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code in 200..299) return@withContext json.decodeFromString<PlantSuggestion>(text)

            val errorCode = runCatching { json.parseToJsonElement(text).jsonObject["error"]?.jsonPrimitive?.content }.getOrNull()
            throw AiException(
                when {
                    errorCode == "ai_not_configured" || code == 404 -> AiException.Kind.NotConfigured
                    errorCode == "daily_limit" -> AiException.Kind.LimitReached
                    else -> AiException.Kind.Failed
                }
            )
        } catch (e: AiException) {
            throw e
        } catch (e: IOException) {
            throw AiException(AiException.Kind.Network)
        } catch (e: Exception) {
            throw AiException(AiException.Kind.Failed)
        } finally {
            connection.disconnect()
        }
    }
}
