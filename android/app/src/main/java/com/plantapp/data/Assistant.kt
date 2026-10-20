package com.plantapp.data

import android.util.Base64
import com.plantapp.BuildConfig
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** What the plant-assistant function returns for one question. Text is already in the user's language. */
@Serializable
data class AssistantReply(
    val identified: Boolean = false,
    val confidence: String = "low",
    @SerialName("plant_key") val plantKey: String = "Other",
    @SerialName("scientific_name") val scientificName: String = "",
    val names: Tri = Tri(),
    /** healthy / needs_attention / unhealthy / unknown */
    val health: String = "unknown",
    val answer: String = "",
    @SerialName("follow_ups") val followUps: List<String> = emptyList(),
    /** Part of the marketplace that matches the question (Catalog keys; empty when nothing fits). */
    @SerialName("browse_section") val browseSection: String = "",
    @SerialName("browse_category") val browseCategory: String = "",
    @SerialName("browse_occasion") val browseOccasion: String = "",
)

/** One line of the chat as sent to the function. */
data class ChatTurn(val fromUser: Boolean, val text: String)

class AssistantException(val kind: Kind) : Exception(kind.name) {
    enum class Kind { NotConfigured, DailyLimit, PhotoLimit, Network, Failed }
}

class AssistantRepository {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Sends the conversation (and the photo of the newest message, if any) to the plant-assistant edge function.
     * [language] is the app language code (en / ar / ckb); the reply comes back in it.
     */
    suspend fun ask(turns: List<ChatTurn>, jpeg: ByteArray?, language: String): AssistantReply =
        withContext(Dispatchers.IO) {
            val token = Backend.client.auth.currentAccessTokenOrNull()
                ?: throw AssistantException(AssistantException.Kind.Failed)
            val body = buildJsonObject {
                put("language", language)
                put("messages", buildJsonArray {
                    turns.forEach { turn ->
                        add(buildJsonObject {
                            put("role", if (turn.fromUser) "user" else "assistant")
                            put("text", turn.text)
                        })
                    }
                })
                if (jpeg != null) {
                    put("image_base64", Base64.encodeToString(jpeg, Base64.NO_WRAP))
                    put("media_type", "image/jpeg")
                }
            }.toString()

            val connection = URL("${BuildConfig.SUPABASE_URL}/functions/v1/plant-assistant").openConnection() as HttpURLConnection
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
                if (code in 200..299) return@withContext json.decodeFromString<AssistantReply>(text)

                val errorCode = runCatching { json.parseToJsonElement(text).jsonObject["error"]?.jsonPrimitive?.content }.getOrNull()
                throw AssistantException(
                    when {
                        errorCode == "ai_not_configured" || code == 404 -> AssistantException.Kind.NotConfigured
                        errorCode == "daily_limit" -> AssistantException.Kind.DailyLimit
                        errorCode == "photo_limit" -> AssistantException.Kind.PhotoLimit
                        else -> AssistantException.Kind.Failed
                    }
                )
            } catch (e: AssistantException) {
                throw e
            } catch (e: IOException) {
                throw AssistantException(AssistantException.Kind.Network)
            } catch (e: Exception) {
                throw AssistantException(AssistantException.Kind.Failed)
            } finally {
                connection.disconnect()
            }
        }
}

/** How close a shop is to the customer: same city first, then shops that deliver there, then the rest. */
enum class ShopReach { SameCity, Delivers, OtherCity }

/** A shop listing that sells the plant the assistant talked about. */
data class ShopMatch(val listing: Listing, val reach: ShopReach, val exact: Boolean)

/**
 * Finds the in-stock listings that match the plant in [reply]: an exact match (same species or a name that
 * matches in any language) ranks above a listing that only has the same plant type. Results are ordered by
 * how close the shop is to [city], then exact before similar, then cheapest first.
 */
fun findShops(reply: AssistantReply, listings: List<Listing>, city: String): List<ShopMatch> {
    if (!reply.identified) return emptyList()
    val wantedNames = listOf(reply.names.en, reply.names.ar, reply.names.ckb, reply.scientificName)
        .map { it.trim().lowercase() }
        .filter { it.length >= 3 }
    val genus = reply.scientificName.trim().lowercase().substringBefore(' ').takeIf { it.length >= 4 }

    fun exact(listing: Listing): Boolean {
        val have = listing.name.values.map { it.trim().lowercase() }.filter { it.length >= 3 } +
            listOfNotNull(listing.scientificName?.trim()?.lowercase()?.takeIf { it.length >= 3 })
        if (wantedNames.any { w -> have.any { h -> h == w || h.contains(w) || w.contains(h) } }) return true
        val listingGenus = listing.scientificName?.trim()?.lowercase()?.substringBefore(' ')
        return genus != null && listingGenus == genus
    }

    return listings
        .filter { it.inStock }
        .mapNotNull { listing ->
            val isExact = exact(listing)
            val sameType = reply.plantKey != "Other" && listing.plantKey == reply.plantKey
            if (!isExact && !sameType) return@mapNotNull null
            val shop = listing.sellers
            val reach = when {
                shop?.city == city -> ShopReach.SameCity
                listing.deliversTo(city) -> ShopReach.Delivers
                else -> ShopReach.OtherCity
            }
            ShopMatch(listing, reach, isExact)
        }
        .sortedWith(compareBy<ShopMatch> { it.reach.ordinal }.thenBy { !it.exact }.thenBy { it.listing.priceIqd })
}
