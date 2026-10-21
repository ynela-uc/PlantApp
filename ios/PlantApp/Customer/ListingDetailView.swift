import SwiftUI

struct ListingDetailView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let listing: Listing
    @State private var justAdded = false
    @State private var chosen: [String: String] = [:]
    @State private var showOptionError = false

    private var optionsComplete: Bool { listing.options.allSatisfy { chosen[$0.name] != nil } }
    private var inCartCount: Int { model.cart.values.filter { $0.listingId == listing.id }.reduce(0) { $0 + $1.qty } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackButton { model.closeOverlay() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    PlantPicture(listing: listing, emojiSize: 96)
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

                        HStack(spacing: 10) {
                            Text(lang.price(listing.priceIqd))
                                .font(.system(size: 22, weight: .bold))
                            if let old = listing.oldPriceIqd, listing.discountPercent != nil {
                                Text(lang.price(old))
                                    .font(.system(size: 15))
                                    .strikethrough()
                                    .foregroundStyle(Theme.muted)
                            }
                            if let percent = listing.discountPercent {
                                Text(lang.t("discount_off", percent))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.error)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Theme.errorSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 8)

                        if let pieces = listing.pieces {
                            Text("📦  " + lang.t("pieces_count", pieces))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 4)
                        }

                        // The customer's choices (colour, scent, ...)
                        ForEach(listing.options, id: \.name) { option in
                            Text(option.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.greenDark)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            FlowLayout(spacing: 8) {
                                ForEach(option.values, id: \.self) { value in
                                    Pill(label: value, selected: chosen[option.name] == value) {
                                        chosen[option.name] = value
                                        showOptionError = false
                                    }
                                }
                            }
                        }

                        if let shop = listing.sellers {
                            shopCard(shop)
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

            VStack(spacing: 8) {
                if showOptionError {
                    ErrorText(message: lang.t("err_choose_options"))
                }
                HStack(spacing: 12) {
                    if inCartCount > 0 {
                        Text(lang.t("in_cart", inCartCount))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    Button {
                        guard optionsComplete else {
                            showOptionError = true
                            return
                        }
                        model.addToCart(listing.id, options: chosen)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeOut(duration: 0.15)) { justAdded = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_300_000_000)
                            withAnimation(.easeOut(duration: 0.2)) { justAdded = false }
                        }
                    } label: {
                        Text(justAdded ? "✓  " + lang.t("in_cart", inCartCount) : lang.t("add_to_cart"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBar()
        }
    }

    /// The shop (tap to visit it), where it delivers, and the real cost with delivery.
    private func shopCard(_ shop: SellerInfo) -> some View {
        let fee = shop.feeFor(model.city)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                model.openShop(shop.id)
            } label: {
                HStack {
                    Text(lang.t("sold_by", shop.name))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Spacer()
                    Text(lang.t("shop_visit") + "  ›")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
            }
            .buttonStyle(.plain)
            Text("\(lang.cityName(shop.city))  ·  \(ratingLabel(lang, rating: shop.rating, count: shop.ratingCount))")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
            DeliveryBadge(shop: shop).padding(.top, 4)
            if !shop.isNationwide, let cities = shop.deliversTo, !cities.isEmpty {
                Text(lang.t("delivers_to", cities.map { lang.cityName($0) }.joined(separator: ", ")))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
            VStack(spacing: 4) {
                HStack {
                    Text(lang.t("delivery_to_city", lang.cityName(model.city))).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(fee == 0 ? lang.t("delivery_free") : lang.price(fee)).fontWeight(.semibold)
                }
                HStack {
                    Text(lang.t("total_with_delivery")).fontWeight(.bold).foregroundStyle(Theme.greenDark)
                    Spacer()
                    Text(lang.price(listing.priceIqd + fee)).fontWeight(.bold).foregroundStyle(Theme.greenDark)
                }
            }
            .font(.system(size: 14))
            .padding(12)
            .background(Theme.greenSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
