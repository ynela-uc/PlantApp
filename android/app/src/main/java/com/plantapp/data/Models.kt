package com.plantapp.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Which app shell an account belongs to. [db] is the value stored in profiles.role. */
enum class Role(val db: String) {
    Customer("customer"),
    Seller("seller");

    companion object {
        fun fromDb(value: String?): Role = entries.firstOrNull { it.db == value } ?: Customer
    }
}

@Serializable
data class Profile(
    val id: String,
    val role: String = "customer",
    @SerialName("first_name") val firstName: String = "",
    @SerialName("last_name") val lastName: String = "",
    val phone: String = "",
    val city: String = "",
    val address: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    @SerialName("address_notes") val addressNotes: String = "",
) {
    val roleEnum: Role get() = Role.fromDb(role)
}

/** The fields a customer can change on their own profile. */
@Serializable
data class ProfileUpdate(
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    val phone: String,
    val city: String,
    val address: String,
    val district: String,
    val neighborhood: String,
    val landmark: String,
    @SerialName("address_notes") val addressNotes: String,
)

/** Row inserted into `sellers` when a seller creates an account. */
@Serializable
data class NewSeller(
    @SerialName("owner_id") val ownerId: String,
    val name: String,
    val city: String,
    val address: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    @SerialName("address_notes") val addressNotes: String = "",
    @SerialName("delivery_scope") val deliveryScope: String = "local",
    @SerialName("delivers_to") val deliversTo: List<String>,
    val phone: String,
    val bio: String = "",
    @SerialName("plants_offered") val plantsOffered: List<String> = emptyList(),
    @SerialName("shop_types") val shopTypes: List<String> = listOf(Catalog.PLANTS),
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 5000,
)

/** Everything collected by the create-account form (fields not used by a role stay blank). */
data class SignUpForm(
    val email: String,
    val password: String,
    val firstName: String,
    val lastName: String,
    val phone: String,
    val city: String,
    val address: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    val addressNotes: String = "",
    val shopName: String = "",
    /** Which kinds of shop this seller runs (Catalog section keys). */
    val shopTypes: List<String> = emptyList(),
)
