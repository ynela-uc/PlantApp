import SwiftUI

/// Step 1: ask for the account email and send the reset link.
struct ResetPasswordView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    @Environment(\.layoutDirection) private var direction
    let role: Role

    @State private var email = ""

    private var accent: Color { role == .seller ? Theme.amber : Theme.green }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    app.backToSignIn(role)
                } label: {
                    Label(lang.t("back"), systemImage: direction == .rightToLeft ? "arrow.right" : "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accent)
                }

                Text(lang.t("reset_title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.greenDark)

                if app.resetLinkSent {
                    Text(lang.t("reset_link_sent", app.resetEmail))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.greenSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Text(lang.t("reset_intro"))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                }

                AppField(title: lang.t("field_email"), text: $email, keyboard: .emailAddress, autocapitalize: false)
                ErrorText(message: app.error.map { lang.t($0.key) })

                Button {
                    let trimmed = email.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { app.sendResetLink(email: trimmed) }
                } label: {
                    BusyLabel(title: lang.t(app.resetLinkSent ? "reset_resend" : "reset_send_link"), busy: app.busy)
                }
                .buttonStyle(PrimaryButtonStyle(color: accent))
                .disabled(app.busy || email.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: email) { _ in app.clearError() }
    }
}

/// Step 2: shown after the reset link opened the app.
struct SetNewPasswordView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel

    @State private var password = ""
    @State private var localError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("🔑").font(.system(size: 44)).padding(.top, 40)
                Text(lang.t("set_password_title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Text(lang.t("set_password_intro"))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)

                AppField(title: lang.t("field_new_password"), text: $password, secure: true, autocapitalize: false)
                ErrorText(message: localError ?? app.error.map { lang.t($0.key) })

                Button {
                    if password.count < 6 {
                        localError = lang.t("err_password_short")
                    } else {
                        localError = nil
                        app.setNewPassword(password)
                    }
                } label: {
                    BusyLabel(title: lang.t("set_password_action"), busy: app.busy)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(app.busy)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: password) { _ in app.clearError(); localError = nil }
    }
}
