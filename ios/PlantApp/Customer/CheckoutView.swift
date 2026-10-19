import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let profile: Profile

    @State private var isGift = false
    @State private var recipientName = ""
    @State private var recipientPhone = ""
    @State private var city = ""
    @State private var address = ""
    @State private var note = ""
    @State private var dayOffset = 0
    @State private var window = "any"
    @State private var fieldsError = false

    private let windows = ["any", "morning", "afternoon", "evening"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Split into Groups: this Mac's Xcode 14.2 (iOS 16.2 SDK) has the
                    // pre-variadic-generics ViewBuilder, capped at 10 children per block.
                    Group {
                        BackButton { model.closeOverlay() }
                            .padding(.vertical, 8)
                        Text(lang.t("checkout_title"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.greenDark)

                        SectionHeading(text: lang.t("checkout_who"))
                        HStack(spacing: 10) {
                            Choice(label: lang.t("checkout_for_me"), selected: !isGift) { isGift = false }
                            Choice(label: "🎁  " + lang.t("checkout_gift"), selected: isGift) { isGift = true }
                        }
                        if isGift {
                            VStack(spacing: 10) {
                                AppField(title: lang.t("recipient_name"), text: $recipientName)
                                AppField(title: lang.t("recipient_phone"), text: $recipientPhone, keyboard: .phonePad)
                                AppField(title: lang.t("gift_note"), text: $note, multiline: true)
                            }
                            .padding(.top, 12)
                        }

                        SectionHeading(text: lang.t("checkout_delivery"))
                        Caption(lang.t("field_city"))
                        FlowLayout(spacing: 8) {
                            ForEach(Cities.codes, id: \.self) { code in
                                Pill(label: lang.cityName(code), selected: city == code) { city = code }
                            }
                        }
                        .padding(.top, 6)
                        AppField(title: lang.t("field_address"), text: $address, multiline: true)
                            .padding(.top, 12)

                        Caption(lang.t("delivery_date")).padding(.top, 12)
                    }

                    Group {
                        FlowLayout(spacing: 8) {
                            ForEach(0..<4, id: \.self) { offset in
                                Pill(label: dayLabel(offset), selected: dayOffset == offset) { dayOffset = offset }
                            }
                        }
                        .padding(.top, 6)

                        Caption(lang.t("delivery_window")).padding(.top, 12)
                        FlowLayout(spacing: 8) {
                            ForEach(windows, id: \.self) { key in
                                Pill(label: lang.t(windowLabelKey(key)), selected: window == key) { window = key }
                            }
                        }
                        .padding(.top, 6)

                        SectionHeading(text: lang.t("checkout_payment"))
                        HStack(spacing: 10) {
                            Choice(label: lang.t("pay_cod"), selected: true) { }
                            Text(lang.t("pay_card_soon"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x9E9E9E))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color(hex: 0xF0F0F0))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        SectionHeading(text: lang.t("checkout_summary"))
                        ForEach(model.cartLines) { line in
                            HStack {
                                Text("\(lang.localized(line.listing.name)) × \(line.qty)")
                                Spacer()
                                Text(lang.price(line.listing.priceIqd * line.qty))
                            }
                            .font(.system(size: 15))
                            .padding(.vertical, 3)
                        }
                        TotalRow(label: lang.t("cart_total"), value: lang.price(model.cartTotal), bold: true)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                ErrorText(message: errorMessage)
                Button {
                    submit()
                } label: {
                    BusyLabel(title: lang.t("place_order") + "  ·  " + lang.price(model.cartTotal), busy: model.placing)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.placing || model.cartLines.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.shadow(color: .black.opacity(0.08), radius: 6, y: -2))
        }
        .onAppear {
            if city.isEmpty { city = model.city }
            if address.isEmpty { address = profile.address }
        }
    }

    private var errorMessage: String? {
        switch model.checkoutError {
        case .notDeliverable(let shops):
            return lang.t("err_not_deliverable", shops.joined(separator: ", "), lang.cityName(city))
        case .network:
            return lang.t("err_network")
        case .generic:
            return lang.t("err_generic")
        case nil:
            return fieldsError ? lang.t("err_checkout_fields") : nil
        }
    }

    private func dayLabel(_ offset: Int) -> String {
        if offset == 0 { return lang.t("delivery_today") }
        if offset == 1 { return lang.t("delivery_tomorrow") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.language.rawValue)
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date(offset))
    }

    private func date(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    private func submit() {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let missing = blank(address) || (isGift && (blank(recipientName) || blank(recipientPhone)))
        if missing {
            fieldsError = true
            return
        }
        fieldsError = false
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        model.placeOrders(
            CheckoutForm(
                isGift: isGift,
                recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
                recipientPhone: recipientPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city,
                address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                giftNote: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)),
                deliveryDate: iso.string(from: date(dayOffset)),
                window: window
            )
        )
    }
}

/// Small grey caption above a group of pills.
private struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wide two-way choice button.
private struct Choice: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color.white : Color(hex: 0x333333))
                .background(selected ? Theme.green : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.green : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
