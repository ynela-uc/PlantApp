import SwiftUI

/// The shopper's front door. With nothing chosen it shows the three sections (flowers, plants, gifts)
/// and the occasions; picking one shows its categories and products. Search works from anywhere.
struct BrowseView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    @Environment(\.layoutDirection) private var direction
    let profile: Profile

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let visible = model.visible(lang)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header

                if model.loading {
                    ProgressView().tint(Theme.green).frame(maxWidth: .infinity).frame(height: 200)
                } else if model.failed {
                    MessageState(emoji: "📡", title: lang.t("browse_load_failed")) { model.load() }
                        .frame(height: 260)
                } else {
                    if model.isHome {
                        homeContent
                    } else {
                        filterContent
                        if visible.isEmpty {
                            Text(lang.t("browse_empty", lang.cityName(model.city)))
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(32)
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visible) { listing in
                            PlantCard(listing: listing) { model.openListing(listing.id) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
    }

    // MARK: Pieces

    private var header: some View {
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
        }
        .padding(.top, 12)
    }

    /// The three sections, the occasions, then every product.
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(lang.t("home_prompt"))
            ForEach(Catalog.sections) { entry in
                SectionTile(
                    emoji: entry.emoji,
                    title: lang.t("sec_" + entry.key),
                    detail: lang.t("sec_" + entry.key + "_desc")
                ) { model.openSection(entry.key) }
            }
            heading(lang.t("home_occasions"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Catalog.occasions) { occasion in
                        Pill(label: "\(occasion.emoji) \(lang.t("occ_" + occasion.key))", selected: false) {
                            model.openOccasion(occasion.key)
                        }
                    }
                }
            }
            heading(lang.t("home_all_products"))
        }
    }

    /// Breadcrumb and category chips while a section or occasion is open.
    private var filterContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    model.openSection(nil)
                } label: {
                    Label(lang.t("home_back"), systemImage: direction == .rightToLeft ? "arrow.right" : "arrow.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
            }
            if let section = Catalog.section(model.section) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Pill(label: lang.t("browse_all"), selected: model.category == nil) { model.category = nil }
                        ForEach(section.categories) { category in
                            Pill(
                                label: "\(category.emoji) \(lang.t("cat_" + category.key))",
                                selected: model.category == category.key
                            ) { model.category = category.key }
                        }
                    }
                }
            }
        }
    }

    private var title: String {
        if let section = Catalog.section(model.section) { return "\(section.emoji) \(lang.t("sec_" + section.key))" }
        if let occasion = model.occasion { return "\(Catalog.occasionEmoji(occasion)) \(lang.t("occ_" + occasion))" }
        return lang.t("home_all_products")
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.greenDark)
            .padding(.top, 8)
    }
}

/// Big tile for one section: emoji, name, short description.
struct SectionTile: View {
    @Environment(\.layoutDirection) private var direction
    let emoji: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(Theme.greenSoft)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: direction == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
            .padding(16)
            .card(radius: 20)
        }
        .buttonStyle(.plain)
    }
}

private struct PlantCard: View {
    @EnvironmentObject var lang: LanguageStore
    let listing: Listing
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                PlantPicture(listing: listing)
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
