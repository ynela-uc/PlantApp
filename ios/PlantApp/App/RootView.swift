import SwiftUI

/// Top-level switch: splash -> welcome -> sign in / create account -> the signed-in home.
struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch app.screen {
            case .loading:
                ProgressView().tint(Theme.green)
            case .welcome:
                WelcomeView()
            case .auth(let role):
                AuthView(role: role)
            case .resetPassword(let role):
                ResetPasswordView(role: role)
            case .setNewPassword:
                SetNewPasswordView()
            case .home(let profile):
                if profile.roleEnum == .customer {
                    CustomerRoot(profile: profile)
                } else {
                    SellerRoot(profile: profile)
                }
            }
        }
    }
}
