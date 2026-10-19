import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("🌿")
                        .font(.system(size: 44))
                        .frame(width: 88, height: 88)
                        .background(Theme.green)
                        .clipShape(Circle())
                        .padding(.top, 40)

                    Text(lang.t("welcome_title"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    Text(lang.t("welcome_tagline"))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text(lang.t("role_prompt"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x333333))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        .padding(.bottom, 12)

                    RoleCard(
                        emoji: "🛒",
                        iconBackground: Theme.greenSoft,
                        accent: Theme.green,
                        title: lang.t("role_customer_title"),
                        description: lang.t("role_customer_desc")
                    ) { app.chooseRole(.customer) }
                    .padding(.bottom, 14)

                    RoleCard(
                        emoji: "🏪",
                        iconBackground: Theme.amberSoft,
                        accent: Theme.amber,
                        title: lang.t("role_seller_title"),
                        description: lang.t("role_seller_desc")
                    ) { app.chooseRole(.seller) }
                }
                .padding(.horizontal, 24)
            }
            LanguageSelector()
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
    }
}

private struct RoleCard: View {
    @Environment(\.layoutDirection) private var direction
    let emoji: String
    let iconBackground: Color
    let accent: Color
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(iconBackground)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: direction == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(18)
            .card(radius: 20)
        }
        .buttonStyle(.plain)
    }
}
