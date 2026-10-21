package com.plantapp.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class AuthRepository {
    private val auth get() = Backend.client.auth

    /** Waits until any saved session has been loaded from storage. */
    suspend fun awaitReady() = auth.awaitInitialization()

    fun hasSession(): Boolean = auth.currentSessionOrNull() != null

    suspend fun profile(): Profile? {
        val uid = auth.currentUserOrNull()?.id ?: return null
        return Backend.client.from("profiles")
            .select { filter { eq("id", uid) } }
            .decodeSingleOrNull<Profile>()
    }

    /** Saves the signed-in customer's profile and returns the fresh row. */
    suspend fun updateProfile(update: ProfileUpdate): Profile {
        val uid = auth.currentUserOrNull()?.id ?: error("No session")
        Backend.client.from("profiles").update(update) { filter { eq("id", uid) } }
        return profile() ?: error("Profile missing")
    }

    suspend fun signIn(email: String, password: String) {
        auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    suspend fun signUp(role: Role, form: SignUpForm) {
        auth.signUpWith(Email) {
            email = form.email
            password = form.password
            data = buildJsonObject {
                put("role", role.db)
                put("first_name", form.firstName)
                put("last_name", form.lastName)
                put("phone", form.phone)
                put("city", form.city)
                put("address", form.address)
                put("district", form.district)
                put("neighborhood", form.neighborhood)
                put("landmark", form.landmark)
                put("address_notes", form.addressNotes)
                form.lat?.let { put("lat", it) }
                form.lng?.let { put("lng", it) }
            }
        }
        if (role == Role.Seller) {
            val uid = auth.currentUserOrNull()?.id ?: error("No session after sign-up")
            Backend.client.from("sellers").insert(
                NewSeller(
                    ownerId = uid,
                    name = form.shopName,
                    city = form.city,
                    address = form.address,
                    district = form.district,
                    neighborhood = form.neighborhood,
                    landmark = form.landmark,
                    addressNotes = form.addressNotes,
                    lat = form.lat,
                    lng = form.lng,
                    deliversTo = listOf(form.city),
                    phone = form.phone,
                    shopTypes = form.shopTypes,
                )
            )
        }
    }

    /** Emails a reset link; opening it on the phone launches the app (plantapp://auth-callback). */
    suspend fun sendResetLink(email: String) {
        auth.resetPasswordForEmail(email = email, redirectUrl = AUTH_REDIRECT_URL)
    }

    /** Signs in with the tokens carried by a reset link (plantapp://auth-callback#access_token=...). */
    suspend fun importSession(accessToken: String, refreshToken: String) {
        auth.importAuthToken(accessToken = accessToken, refreshToken = refreshToken, retrieveUser = true)
    }

    /** Sets a new password for the user signed in through the reset link. */
    suspend fun setNewPassword(newPassword: String) {
        auth.updateUser { password = newPassword }
    }

    suspend fun signOut() = auth.signOut()
}
