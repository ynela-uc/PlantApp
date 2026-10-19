import SwiftUI
import Supabase

enum Screen: Equatable {
    case loading
    case welcome
    case auth(Role)
    case resetPassword(Role)
    /// Shown after the user opens the reset link from the email.
    case setNewPassword
    case home(Profile)
}

enum AuthError {
    case invalidCredentials, emailTaken, network, wrongRoleIsCustomer, wrongRoleIsSeller, linkExpired, generic

    var key: String {
        switch self {
        case .invalidCredentials: return "err_invalid_credentials"
        case .emailTaken: return "err_email_taken"
        case .network: return "err_network"
        case .wrongRoleIsCustomer: return "err_wrong_role_customer"
        case .wrongRoleIsSeller: return "err_wrong_role_seller"
        case .linkExpired: return "err_link_expired"
        case .generic: return "err_generic"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var screen: Screen = .loading
    @Published var busy = false
    @Published var error: AuthError?
    /// Password reset: true once the reset link email has been requested.
    @Published var resetLinkSent = false
    @Published var resetEmail = ""

    /// Set when the app was opened from a password-reset link, so the normal session restore does not skip it.
    private var recoveryPending = false
    /// Role last chosen on the welcome screen; used to return to the right sign-in page.
    private var lastRole: Role = .customer

    init() {
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        if await AuthService.hasSession(), !recoveryPending {
            if let profile = try? await AuthService.profile() {
                screen = .home(profile)
                return
            }
        }
        if !recoveryPending { screen = .welcome }
    }

    // MARK: Navigation

    func chooseRole(_ role: Role) { lastRole = role; reset(.auth(role)) }
    func backToWelcome() { reset(.welcome) }
    func backToSignIn(_ role: Role) { reset(.auth(role)) }
    func openPasswordReset(_ role: Role) { reset(.resetPassword(role)) }
    func clearError() { error = nil }

    private func reset(_ next: Screen) {
        screen = next
        busy = false
        error = nil
        resetLinkSent = false
        resetEmail = ""
    }

    // MARK: Reset-link handling

    /// Handles plantapp://auth-callback#access_token=...&refresh_token=...&type=recovery
    /// or plantapp://auth-callback#error=...&error_code=otp_expired
    func handleAuthLink(_ url: URL) {
        guard url.scheme == Config.authScheme, url.host == Config.authHost else { return }
        var params: [String: String] = [:]
        for raw in [url.fragment, url.query] {
            guard let raw else { continue }
            for pair in raw.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { continue }
                let key = String(parts[0])
                let value = String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }
        if params["error"] != nil || params["error_code"] != nil {
            onAuthLinkFailed()
        } else if let access = params["access_token"] {
            onRecoveryTokens(access: access, refresh: params["refresh_token"] ?? "")
        } else {
            onAuthLinkFailed()
        }
    }

    private func onRecoveryTokens(access: String, refresh: String) {
        recoveryPending = true
        Task {
            do {
                try await AuthService.importSession(accessToken: access, refreshToken: refresh)
                screen = .setNewPassword
                busy = false
                error = nil
            } catch {
                onAuthLinkFailed()
            }
        }
    }

    private func onAuthLinkFailed() {
        recoveryPending = false
        screen = .resetPassword(lastRole)
        busy = false
        error = .linkExpired
    }

    // MARK: Actions

    func signIn(role: Role, email: String, password: String) {
        runAuth(role) { try await AuthService.signIn(email: email, password: password) }
    }

    func signUp(role: Role, form: SignUpForm) {
        runAuth(role) { try await AuthService.signUp(role: role, form: form) }
    }

    private func runAuth(_ role: Role, _ action: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do {
                try await action()
                try await finishSignIn(role)
            } catch {
                busy = false
                self.error = classify(error)
                screen = .auth(role)
            }
        }
    }

    /// After any successful sign-in: load the profile and open the home that matches the chosen role.
    private func finishSignIn(_ role: Role) async throws {
        guard let profile = try await AuthService.profile() else { throw AppError.failed }
        if profile.roleEnum != role {
            try? await AuthService.signOut()
            busy = false
            error = profile.roleEnum == .customer ? .wrongRoleIsCustomer : .wrongRoleIsSeller
            screen = .auth(role)
        } else {
            busy = false
            error = nil
            screen = .home(profile)
        }
    }

    func sendResetLink(email: String) {
        busy = true
        error = nil
        Task {
            do {
                try await AuthService.sendResetLink(email: email)
                busy = false
                resetLinkSent = true
                resetEmail = email
            } catch {
                busy = false
                self.error = classify(error)
            }
        }
    }

    func setNewPassword(_ password: String) {
        busy = true
        error = nil
        Task {
            do {
                try await AuthService.setNewPassword(password)
                guard let profile = try await AuthService.profile() else { throw AppError.failed }
                recoveryPending = false
                busy = false
                screen = .home(profile)
            } catch {
                busy = false
                self.error = classify(error)
            }
        }
    }

    func signOut() {
        Task {
            try? await AuthService.signOut()
            reset(.welcome)
        }
    }

    private func classify(_ error: Error) -> AuthError {
        if error is URLError { return .network }
        let message = "\(error) \(error.localizedDescription)".lowercased()
        if message.contains("offline") || message.contains("timed out") || message.contains("could not connect") || message.contains("network") { return .network }
        if message.contains("invalid login credentials") || message.contains("invalid_credentials") { return .invalidCredentials }
        if message.contains("already registered") || message.contains("user_already_exists") || message.contains("already been registered") { return .emailTaken }
        return .generic
    }
}
