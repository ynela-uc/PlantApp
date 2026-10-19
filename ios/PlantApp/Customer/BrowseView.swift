import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let profile: Profile

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let visible = model.visible(lang)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(lang.t("home_greeting", profile.firstName.isEmpty ? profile.phone : profile.firstName))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.greenDark)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField(lang.t("browse_search_hint"), text: $model.query)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                Text(lang.t("browse_delivering_to"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Cities.codes, id: \.self) { code in
                            Pill(label: lang.cityName(code), selected: model.city == code) { model.setCity(code) }
                        }
                    }
                }
                let types = model.plantTypes
                if !types.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Pill(label: lang.t("browse_all"), selected: model.plantFilter == nil) { model.plantFilter = nil }
                            ForEach(types, id: \.key) { type in
                                Pill(
                                    label: "\(plantEmoji(type.key)) \(lang.localized(type.listing.name))",
                                    selected: model.plantFilter == type.key
                                ) { model.plantFilter = type.key }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if model.loading {
                ProgressView().tint(Theme.green).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.failed {
                MessageState(emoji: "📡", title: lang.t("browse_load_failed")) { model.load() }
            } else if visible.isEmpty {
                MessageState(emoji: "🪴", title: lang.t("browse_empty", lang.cityName(model.city)))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visible) { listing in
                            PlantCard(listing: listing) { model.openListing(listing.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct PlantCard: View {
    @EnvironmentObject var lang: LanguageStore
    let listing: Listing
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                PlantPicture(url: listing.imageURL, plantKey: listing.plantKey)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.25, contentMode: .fit)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.localized(listing.name))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .lineLimit(1)
                    Text(listing.sellers?.name ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    Text(lang.price(listing.priceIqd))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 4)
                    DeliveryBadge(shop: listing.sellers)
                        .padding(.top, 6)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card(radius: 18)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
