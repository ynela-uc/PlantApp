import SwiftUI

struct AuthView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    @Environment(\.layoutDirection) private var direction
    let role: Role

    @State private var creating = false
    @State private var form = SignUpForm()
    @State private var addr = AddressDraft()
    @State private var localError: String?

    private var accent: Color { role == .seller ? Theme.amber : Theme.green }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    app.backToWelcome()
                } label: {
                    Label(lang.t("back"), systemImage: direction == .rightToLeft ? "arrow.right" : "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accent)
                }

                Text(lang.t(role == .seller ? "auth_title_seller" : "auth_title_customer"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.top, 4)

                HStack(spacing: 10) {
                    ModeTab(title: lang.t("auth_tab_signin"), selected: !creating, accent: accent) { setMode(false) }
                    ModeTab(title: lang.t("auth_tab_signup"), selected: creating, accent: accent) { setMode(true) }
                }
                .padding(.vertical, 8)

                if creating {
                    AppField(title: lang.t("field_first_name"), text: $form.firstName)
                    AppField(title: lang.t("field_last_name"), text: $form.lastName)
                    AppField(title: lang.t("field_phone"), text: $form.phone, keyboard: .phonePad)
                }
                AppField(title: lang.t("field_email"), text: $form.email, keyboard: .emailAddress, autocapitalize: false)
                AppField(title: lang.t("field_password"), text: $form.password, secure: true, autocapitalize: false)

                if !creating {
                    Button(lang.t("forgot_password")) { app.openPasswordReset(role) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }

                if creating {
                    if role == .seller {
                        AppField(title: lang.t("field_shop_name"), text: $form.shopName)
                        Text(lang.t("shop_types_title"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        FlowLayout(spacing: 8) {
                            ForEach(Catalog.sections) { entry in
                                let selected = form.shopTypes.contains(entry.key)
                                Pill(label: "\(entry.emoji) \(lang.t("sec_" + entry.key))", selected: selected, accent: accent) {
                                    if selected { form.shopTypes.removeAll { $0 == entry.key } } else { form.shopTypes.append(entry.key) }
                                    app.clearError()
                                }
                            }
                        }
                    }
                    AddressFields(draft: $addr, accent: accent)
                }

                ErrorText(message: localError ?? app.error.map { lang.t($0.key) })

                VStack(alignment: .leading, spacing: 12) {
                    Button(action: submit) {
                        BusyLabel(title: lang.t(creating ? "action_signup" : "action_signin"), busy: app.busy)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: accent))
                    .disabled(app.busy)
                    if creating { LegalAgreement(accent: accent) }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: form.email) { _ in app.clearError(); localError = nil }
        .onChange(of: form.password) { _ in app.clearError(); localError = nil }
    }

    private func setMode(_ signUp: Bool) {
        creating = signUp
        localError = nil
        app.clearError()
    }

    private func submit() {
        localError = nil
        let email = form.email.trimmingCharacters(in: .whitespaces)
        if !creating {
            if email.isEmpty || form.password.isEmpty { localError = lang.t("err_required"); return }
            app.signIn(role: role, email: email, password: form.password)
            return
        }
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        let missing = blank(email) || form.password.isEmpty || blank(form.firstName) || blank(form.lastName)
            || blank(form.phone) || !addr.isComplete
            || (role == .seller && blank(form.shopName))
        if missing { localError = lang.t("err_required"); return }
        if form.password.count < 6 { localError = lang.t("err_password_short"); return }
        if role == .seller && form.shopTypes.isEmpty { localError = lang.t("err_shop_types"); return }
        var clean = form
        clean.email = email
        clean.firstName = form.firstName.trimmingCharacters(in: .whitespaces)
        clean.lastName = form.lastName.trimmingCharacters(in: .whitespaces)
        clean.phone = form.phone.trimmingCharacters(in: .whitespaces)
        let place = addr.trimmed
        clean.city = place.city
        clean.address = place.street
        clean.district = place.district
        clean.neighborhood = place.neighborhood
        clean.landmark = place.landmark
        clean.addressNotes = place.notes
        clean.lat = place.lat
        clean.lng = place.lng
        clean.shopName = form.shopName.trimmingCharacters(in: .whitespaces)
        app.signUp(role: role, form: clean)
    }
}

private struct ModeTab: View {
    let title: String
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color.white : Color(hex: 0x333333))
                .background(selected ? accent : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(FullTapStyle())
    }
}
