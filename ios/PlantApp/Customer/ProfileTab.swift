import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    let profile: Profile
    var accent: Color = Theme.green

    @State private var editing = false

    var body: some View {
        Group {
            if editing {
                ProfileEditor(profile: profile) { editing = false }
            } else {
                summary
            }
        }
        .background(AppBackground())
        // A saved profile comes back as a new Profile: close the form.
        .onChange(of: profile) { _ in editing = false }
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(profile.fullName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.bottom, 16)

                InfoRow(label: lang.t("field_phone"), value: profile.phone)

                Button(lang.t("profile_edit")) { editing = true }
                    .buttonStyle(PrimaryButtonStyle(color: accent, filled: false))
                    .padding(.top, 16)

                AddressBookSection().padding(.top, 24)

                LanguageSelector().padding(.top, 28)

                Button(lang.t("action_signout")) { app.signOut() }
                    .buttonStyle(PrimaryButtonStyle(color: accent, filled: false))
                    .padding(.top, 28)

                LegalLinks(accent: accent).padding(.top, 16)
                DeleteAccountSection().padding(.top, 12)
            }
            .padding(20)
        }
    }
}

private struct ProfileEditor: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    let profile: Profile
    let onCancel: () -> Void

    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var missing = false

    init(profile: Profile, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onCancel = onCancel
        _firstName = State(initialValue: profile.firstName)
        _lastName = State(initialValue: profile.lastName)
        _phone = State(initialValue: profile.phone)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("profile_edit"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.bottom, 4)

                AppField(title: lang.t("field_first_name"), text: $firstName)
                AppField(title: lang.t("field_last_name"), text: $lastName)
                AppField(title: lang.t("field_phone"), text: $phone, keyboard: .phonePad)

                if missing {
                    ErrorText(message: lang.t("err_required"))
                } else if app.error != nil {
                    ErrorText(message: lang.t("err_generic"))
                }

                Button(action: save) {
                    BusyLabel(title: lang.t("action_save"), busy: app.busy)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(app.busy)
                .padding(.top, 8)

                Button(lang.t("action_cancel"), action: onCancel)
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                    .disabled(app.busy)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if blank(firstName) || blank(lastName) || blank(phone) {
            missing = true
            return
        }
        missing = false
        app.updateProfile(
            ProfileUpdate(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces)
            )
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).foregroundStyle(Theme.muted)
                Spacer(minLength: 16)
                Text(value)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 6)
        }
    }
}
