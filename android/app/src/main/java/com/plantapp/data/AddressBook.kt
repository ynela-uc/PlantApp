package com.plantapp.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** One address saved by a customer. [label] is home / work / apartment (shown in the app language) or the customer's own text. */
@Serializable
data class SavedAddress(
    val id: String,
    val label: String = "",
    val city: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val street: String = "",
    val landmark: String = "",
    val notes: String = "",
    val lat: Double? = null,
    val lng: Double? = null,
    @SerialName("is_default") val isDefault: Boolean = false,
)

/** What is sent to the database when an address is saved. */
@Serializable
data class AddressInput(
    @SerialName("user_id") val userId: String,
    val label: String,
    val city: String,
    val district: String,
    val neighborhood: String,
    val street: String,
    val landmark: String,
    val notes: String,
    // No defaults: removing the pin must send null so the database clears it.
    val lat: Double?,
    val lng: Double?,
    @SerialName("is_default") val isDefault: Boolean,
)

/** A customer can save this many addresses (the database enforces it too). */
const val MAX_ADDRESSES = 10

class AddressRepository {
    /** The customer's addresses, the default first. */
    suspend fun list(): List<SavedAddress> =
        Backend.client.from("addresses")
            .select {
                order("is_default", Order.DESCENDING)
                order("created_at", Order.ASCENDING)
            }
            .decodeList<SavedAddress>()

    suspend fun add(input: AddressInput) {
        Backend.client.from("addresses").insert(input)
    }

    suspend fun update(id: String, input: AddressInput) {
        Backend.client.from("addresses").update(input) { filter { eq("id", id) } }
    }

    /** Making an address the default clears the old default (the database does that). */
    suspend fun makeDefault(id: String) {
        Backend.client.from("addresses").update({ set("is_default", true) }) { filter { eq("id", id) } }
    }

    suspend fun delete(id: String) {
        Backend.client.from("addresses").delete { filter { eq("id", id) } }
    }
}
