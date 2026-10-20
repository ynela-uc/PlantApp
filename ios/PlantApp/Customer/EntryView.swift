import SwiftUI

/// Shown every time the shopper opens the app: what are you looking for? Flowers, plants or gifts,
/// or one of the occasions. The answer opens the app already filtered to it.
struct EntryView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("home_greeting", profile.firstName.isEmpty ? profile.phone : profile.firstName))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                Text(lang.t("home_prompt"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.bottom, 8)

                ForEach(Catalog.sections) { entry in
                    SectionTile(
                        emoji: entry.emoji,
                        title: lang.t("sec_" + entry.key),
                        detail: lang.t("sec_" + entry.key + "_desc")
                    ) { model.enter(section: entry.key, occasion: nil) }
                }

                Text(lang.t("home_occasions"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.top, 12)
                FlowLayout(spacing: 8) {
                    ForEach(Catalog.occasions) { occasion in
                        Pill(label: "\(occasion.emoji) \(lang.t("occ_" + occasion.key))", selected: false) {
                            model.enter(section: nil, occasion: occasion.key)
                        }
                    }
                }

                Button(lang.t("home_all_products")) { model.enter(section: nil, occasion: nil) }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppBackground())
    }
}
