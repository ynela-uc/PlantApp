import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    let profile: Profile
    var accent: Color = Theme.green

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(profile.fullName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.bottom, 16)

                InfoRow(label: lang.t("field_phone"), value: profile.phone)
                InfoRow(label: lang.t("field_city"), value: profile.city.isEmpty ? "" : lang.cityName(profile.city))
                InfoRow(label: lang.t("field_address"), value: profile.address)

                LanguageSelector().padding(.top, 28)

                Button(lang.t("action_signout")) { app.signOut() }
                    .buttonStyle(PrimaryButtonStyle(color: accent, filled: false))
                    .padding(.top, 28)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
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
