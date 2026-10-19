import SwiftUI

struct CartView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel

    var body: some View {
        let lines = model.cartLines
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.t("cart_title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if lines.isEmpty {
                MessageState(emoji: "🛒", title: lang.t("cart_empty"), detail: lang.t("cart_empty_hint"))
            } else {
                let shops = shopNames(lines)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(shops, id: \.self) { shop in
                            Text(lang.t("sold_by", shop))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 6)
                            ForEach(lines.filter { ($0.listing.sellers?.name ?? "") == shop }) { line in
                                CartLine(listing: line.listing, qty: line.qty)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    TotalRow(label: lang.t("cart_total"), value: lang.price(model.cartTotal), bold: true)
                    Button(lang.t("cart_checkout")) { model.openCheckout() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
                .glassBar()
            }
        }
        .background(AppBackground())
    }

    private func shopNames(_ lines: [CartEntry]) -> [String] {
        var seen: [String] = []
        for line in lines {
            let name = line.listing.sellers?.name ?? ""
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }
}

private struct CartLine: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let listing: Listing
    let qty: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.openListing(listing.id)
            } label: {
                HStack(spacing: 12) {
                    PlantPicture(url: listing.imageURL, plantKey: listing.plantKey, emojiSize: 28)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.localized(listing.name))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        Text(lang.price(listing.priceIqd * qty))
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                StepButton(symbol: "minus") { model.changeQuantity(listing.id, -1) }
                Text("\(qty)").font(.system(size: 16, weight: .bold))
                StepButton(symbol: "plus") { model.changeQuantity(listing.id, 1) }
            }
        }
        .padding(12)
        .card()
    }
}

private struct StepButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.green)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
