import SwiftUI

/// One shop's page: who they are, what they deliver and charge, and their products grouped by collection.
struct ShopPageView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let shop: SellerInfo

    @State private var collection: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var listings: [Listing] { model.listings.filter { $0.sellerId == shop.id && $0.inStock } }

    private var collections: [String] {
        var seen: [String] = []
        for listing in listings {
            if let name = listing.collection, !name.trimmingCharacters(in: .whitespaces).isEmpty, !seen.contains(name) {
                seen.append(name)
            }
        }
        return seen
    }

    var body: some View {
        let fee = shop.feeFor(model.city)
        let visible = listings.filter { collection == nil || $0.collection == collection }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                BackButton { model.closeOverlay() }
                    .padding(.top, 8)

                Text(shop.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Text("\(lang.cityName(shop.city))  ·  ★ \(String(format: "%.1f", shop.rating))")
                    .foregroundStyle(Theme.muted)

                if !shop.shopTypes.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(shop.shopTypes, id: \.self) { type in
                            Text("\(Catalog.section(type)?.emoji ?? "") \(lang.t("sec_" + type))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    if !shop.bio.isEmpty {
                        Text(shop.bio).font(.system(size: 15))
                    }
                    if !shop.phone.isEmpty {
                        ContactButtons(phone: shop.phone, whatsappMessage: lang.t("contact_shop_message"))
                    }
                }
                HStack(spacing: 10) {
                    DeliveryBadge(shop: shop)
                    Text(lang.t("delivery_to_city", lang.cityName(model.city)) + ": " + (fee == 0 ? lang.t("delivery_free") : lang.price(fee)))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }

                if !collections.isEmpty {
                    Text(lang.t("shop_collections"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.top, 8)
                    FlowLayout(spacing: 8) {
                        Pill(label: lang.t("browse_all"), selected: collection == nil) { collection = nil }
                        ForEach(collections, id: \.self) { name in
                            Pill(label: name, selected: collection == name) { collection = name }
                        }
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visible) { listing in
                        PlantCard(listing: listing) { model.openListing(listing.id) }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
