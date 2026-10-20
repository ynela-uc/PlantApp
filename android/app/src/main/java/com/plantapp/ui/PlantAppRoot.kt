package com.plantapp.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.plantapp.data.Role
import com.plantapp.ui.customer.CustomerApp
import com.plantapp.ui.seller.SellerApp
import com.plantapp.ui.theme.PlantGreen

/** Top-level switch: splash -> welcome -> sign in / create account -> the signed-in home. */
@Composable
fun PlantAppRoot(viewModel: AppViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    when (val screen = state.screen) {
        Screen.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = PlantGreen)
        }
        Screen.Welcome -> WelcomeScreen(onRoleChosen = viewModel::chooseRole)
        is Screen.Auth -> {
            BackHandler { viewModel.backToWelcome() }
            AuthScreen(
                role = screen.role,
                busy = state.busy,
                error = state.error,
                onBack = viewModel::backToWelcome,
                onSignIn = { email, password -> viewModel.signIn(screen.role, email, password) },
                onSignUp = { form -> viewModel.signUp(screen.role, form) },
                onEdit = viewModel::clearError,
                onForgotPassword = { viewModel.openPasswordReset(screen.role) },
            )
        }
        is Screen.ResetPassword -> {
            BackHandler { viewModel.backToSignIn(screen.role) }
            ResetPasswordScreen(
                role = screen.role,
                busy = state.busy,
                error = state.error,
                linkSent = state.resetLinkSent,
                sentTo = state.resetEmail,
                onBack = { viewModel.backToSignIn(screen.role) },
                onSendLink = viewModel::sendResetLink,
                onEdit = viewModel::clearError,
            )
        }
        Screen.SetNewPassword -> SetNewPasswordScreen(
            busy = state.busy,
            error = state.error,
            onSubmit = viewModel::setNewPassword,
            onEdit = viewModel::clearError,
        )
        is Screen.Home -> {
            PushSetup(screen.profile.id)
            if (screen.profile.roleEnum == Role.Customer) {
                CustomerApp(
                    profile = screen.profile,
                    saving = state.busy,
                    saveFailed = state.error != null,
                    onSaveProfile = viewModel::updateProfile,
                    onSignOut = viewModel::signOut,
                )
            } else {
                SellerApp(profile = screen.profile, onSignOut = viewModel::signOut)
            }
        }
    }
}
