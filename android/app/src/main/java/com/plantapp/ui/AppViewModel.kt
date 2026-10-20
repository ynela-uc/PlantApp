package com.plantapp.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.plantapp.data.AuthRepository
import com.plantapp.data.Profile
import com.plantapp.data.ProfileUpdate
import com.plantapp.data.Role
import com.plantapp.data.SignUpForm
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.IOException

sealed interface Screen {
    data object Loading : Screen
    data object Welcome : Screen
    data class Auth(val role: Role) : Screen
    data class ResetPassword(val role: Role) : Screen
    /** Shown after the user opens the reset link from the email. */
    data object SetNewPassword : Screen
    data class Home(val profile: Profile) : Screen
}

enum class AuthError {
    InvalidCredentials, EmailTaken, Network, WrongRoleIsCustomer, WrongRoleIsSeller, InvalidCode, LinkExpired, Generic
}

data class UiState(
    val screen: Screen = Screen.Loading,
    val busy: Boolean = false,
    val error: AuthError? = null,
    /** Password reset: true once the reset link email has been requested. */
    val resetLinkSent: Boolean = false,
    val resetEmail: String = "",
)

class AppViewModel : ViewModel() {
    private val repo = AuthRepository()
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    /** Set when the app was opened from a password-reset link, so the normal session restore does not skip it. */
    @Volatile
    private var recoveryPending = false

    init {
        viewModelScope.launch { restoreSession() }
    }

    /** Role last chosen on the welcome screen; used to return to the right sign-in page. */
    private var lastRole: Role = Role.Customer

    /** The reset link carried a valid session: import it, then ask for the new password. */
    fun onRecoveryTokens(accessToken: String, refreshToken: String) {
        recoveryPending = true
        viewModelScope.launch {
            try {
                repo.importSession(accessToken, refreshToken)
                _state.value = UiState(Screen.SetNewPassword)
            } catch (e: Exception) {
                recoveryPending = false
                _state.value = UiState(Screen.ResetPassword(lastRole), error = AuthError.LinkExpired)
            }
        }
    }

    /** The link was expired, already used, or malformed. */
    fun onAuthLinkFailed() {
        recoveryPending = false
        _state.value = UiState(Screen.ResetPassword(lastRole), error = AuthError.LinkExpired)
    }

    private suspend fun restoreSession() {
        try {
            repo.awaitReady()
            if (recoveryPending) return
            if (repo.hasSession()) {
                val profile = repo.profile()
                if (profile != null) {
                    _state.value = UiState(Screen.Home(profile))
                    return
                }
            }
        } catch (_: Exception) {
            // Offline or backend problem: fall through to the welcome screen.
        }
        _state.value = UiState(Screen.Welcome)
    }

    fun chooseRole(role: Role) {
        lastRole = role
        _state.value = UiState(Screen.Auth(role))
    }

    fun backToWelcome() {
        _state.value = UiState(Screen.Welcome)
    }

    fun backToSignIn(role: Role) {
        _state.value = UiState(Screen.Auth(role))
    }

    fun clearError() {
        _state.value = _state.value.copy(error = null)
    }

    fun openPasswordReset(role: Role) {
        _state.value = UiState(Screen.ResetPassword(role))
    }

    fun signIn(role: Role, email: String, password: String) = launchAuth(role) {
        repo.signIn(email, password)
    }

    fun signUp(role: Role, form: SignUpForm) = launchAuth(role) {
        repo.signUp(role, form)
    }

    /** Step 1 of password reset: email the reset link. */
    fun sendResetLink(email: String) {
        _state.value = _state.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                repo.sendResetLink(email)
                _state.value = _state.value.copy(busy = false, resetLinkSent = true, resetEmail = email)
            } catch (e: Exception) {
                _state.value = _state.value.copy(busy = false, error = classify(e))
            }
        }
    }

    /** Step 2 (after the link opened the app): save the new password and go in. */
    fun setNewPassword(newPassword: String) {
        _state.value = _state.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                repo.setNewPassword(newPassword)
                val profile = repo.profile() ?: throw IllegalStateException("Profile missing")
                recoveryPending = false
                _state.value = UiState(Screen.Home(profile))
            } catch (e: Exception) {
                _state.value = _state.value.copy(busy = false, error = classify(e))
            }
        }
    }

    /** Customer edits their own profile: save, then show the app again with the fresh profile. */
    fun updateProfile(update: ProfileUpdate) {
        _state.value = _state.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                val fresh = repo.updateProfile(update)
                _state.value = UiState(Screen.Home(fresh))
            } catch (e: Exception) {
                _state.value = _state.value.copy(busy = false, error = classify(e))
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            try { repo.signOut() } catch (_: Exception) { }
            _state.value = UiState(Screen.Welcome)
        }
    }

    private fun launchAuth(role: Role, action: suspend () -> Unit) {
        _state.value = _state.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                action()
                finishSignIn(role)
            } catch (e: Exception) {
                _state.value = UiState(Screen.Auth(role), error = classify(e))
            }
        }
    }

    /** After any successful sign-in: load the profile and open the home that matches the chosen role. */
    private suspend fun finishSignIn(role: Role) {
        val profile = repo.profile() ?: throw IllegalStateException("Profile missing after sign-in")
        if (profile.roleEnum != role) {
            repo.signOut()
            _state.value = UiState(
                screen = Screen.Auth(role),
                error = if (profile.roleEnum == Role.Customer) AuthError.WrongRoleIsCustomer
                else AuthError.WrongRoleIsSeller,
            )
        } else {
            _state.value = UiState(Screen.Home(profile))
        }
    }

    private fun classify(e: Exception): AuthError {
        val message = (e.message ?: "").lowercase()
        return when {
            e is IOException || "unable to resolve host" in message || "timeout" in message -> AuthError.Network
            "invalid login credentials" in message || "invalid_credentials" in message -> AuthError.InvalidCredentials
            "already registered" in message || "user_already_exists" in message -> AuthError.EmailTaken
            else -> AuthError.Generic
        }
    }
}
