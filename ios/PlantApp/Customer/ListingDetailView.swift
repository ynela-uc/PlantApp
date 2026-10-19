import SwiftUI

struct ListingDetailView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let listing: Listing
    @State private var justAdded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackButton { model.closeOverlay() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    PlantPicture(url: listing.imageURL, plantKey: listing.plantKey, emojiSize: 96)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(lang.localized(listing.name))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        if let scientific = listing.scientificName, !scientific.isEmpty {
                            Text(scientific)
                                .font(.system(size: 15))
                                .italic()
                                .foregroundStyle(Theme.muted)
                        }
                        Text(lang.price(listing.priceIqd))
                            .font(.system(size: 22, weight: .bold))
                            .padding(.top, 8)

                        if let shop = listing.sellers {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lang.t("sold_by", shop.name))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.greenDark)
                                Text("\(lang.cityName(shop.city))  ·  ★ \(String(format: "%.1f", shop.rating))")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                                DeliveryBadge(shop: shop).padding(.top, 4)
                                if !shop.isNationwide, let cities = shop.deliversTo, !cities.isEmpty {
                                    Text(lang.t("delivers_to", cities.map { lang.cityName($0) }.joined(separator: ", ")))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                            .padding(.top, 16)
                        }

                        let description = lang.localized(listing.description)
                        if !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .padding(.top, 20)
                        }

                        if !listing.care.isEmpty {
                            Text(lang.t("detail_care"))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.greenDark)
                                .padding(.top, 24)
                                .padding(.bottom, 10)
                            CareRow(emoji: "💧", title: lang.t("care_water"), text: careText("water"))
                            CareRow(emoji: "☀️", title: lang.t("care_light"), text: careText("light"))
                            CareRow(emoji: "🌱", title: lang.t("care_fertilizer"), text: careText("fertilizer"))
                        }

                        if let height = listing.heightCm {
                            CareRow(emoji: "📏", title: lang.t("detail_size"), text: lang.t("size_height", height))
                                .padding(.top, 16)
                        }
                    }
                    .padding(20)
                }
            }

            HStack(spacing: 12) {
                let inCart = model.cart[listing.id] ?? 0
                if inCart > 0 {
                    Text(lang.t("in_cart", inCart))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Button {
                    model.changeQuantity(listing.id, 1)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeOut(duration: 0.15)) { justAdded = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_300_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { justAdded = false }
                    }
                } label: {
                    Text(justAdded ? "✓  " + lang.t("in_cart", model.cart[listing.id] ?? 1) : lang.t("add_to_cart"))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBar()
        }
    }

    private func careText(_ key: String) -> String {
        guard let map = listing.care[key] else { return "" }
        return lang.localized(map)
    }
}

private struct CareRow: View {
    let emoji: String
    let title: String
    let text: String

    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Text(emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text(text).font(.system(size: 15))
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
    }
}
