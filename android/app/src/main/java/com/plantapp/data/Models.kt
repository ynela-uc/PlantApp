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
) {
    val roleEnum: Role get() = Role.fromDb(role)
}

/** Row inserted into `sellers` when a seller creates an account. */
@Serializable
data class NewSeller(
    @SerialName("owner_id") val ownerId: String,
    val name: String,
    val city: String,
    @SerialName("delivery_scope") val deliveryScope: String = "local",
    @SerialName("delivers_to") val deliversTo: List<String>,
    val phone: String,
    val bio: String = "",
    @SerialName("plants_offered") val plantsOffered: List<String> = emptyList(),
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
    val shopName: String = "",
)
