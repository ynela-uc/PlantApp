import SwiftUI

struct CartView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel

    var body: some View {
        let groups = model.cartGroups(model.city)
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.t("cart_title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if groups.isEmpty {
                MessageState(emoji: "🛒", title: lang.t("cart_empty"), detail: lang.t("cart_empty_hint"))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groups) { group in
                            Text(lang.t("sold_by", group.shop?.name ?? ""))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 6)
                            ForEach(group.lines) { line in
                                CartLineRow(line: line)
                            }
                            HStack {
                                Text(lang.t("delivery_to_city", lang.cityName(model.city)))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Text(group.fee == 0 ? lang.t("delivery_free") : lang.price(group.fee))
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 14))
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    TotalRow(label: lang.t("total_with_delivery"), value: lang.price(model.grandTotal(model.city)), bold: true)
                    Button(lang.t("cart_checkout")) { model.openCheckout() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
                .glassBar()
            }
        }
        .background(AppBackground())
    }
}

private struct CartLineRow: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let line: CartLine

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.openListing(line.listing.id)
            } label: {
                HStack(spacing: 12) {
                    PlantPicture(listing: line.listing, emojiSize: 28)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.localized(line.listing.name))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        if !line.options.isEmpty {
                            Text(line.options.keys.sorted().compactMap { line.options[$0] }.joined(separator: " · "))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        Text(lang.price(line.total))
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                StepButton(symbol: "minus") { model.changeQuantity(line.key, -1) }
                Text("\(line.qty)").font(.system(size: 16, weight: .bold))
                StepButton(symbol: "plus") { model.changeQuantity(line.key, 1) }
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
