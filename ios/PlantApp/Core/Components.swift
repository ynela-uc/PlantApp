import SwiftUI

/// Labelled text input used by every form.
struct AppField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure = false
    var multiline = false
    var autocapitalize = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
            field
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .autocorrectionDisabled(!autocapitalize || secure)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
    }

    @ViewBuilder private var field: some View {
        if secure {
            SecureField("", text: $text)
        } else if multiline {
            TextField("", text: $text, axis: .vertical).lineLimit(3...6)
        } else {
            TextField("", text: $text)
        }
    }
}

/// Red message under a form.
struct ErrorText: View {
    let message: String?
    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Primary button content that shows a spinner while busy.
struct BusyLabel: View {
    let title: String
    let busy: Bool
    var body: some View {
        if busy {
            ProgressView().tint(.white)
        } else {
            Text(title)
        }
    }
}

/// Three-way language picker. Switching is instant and flips the layout direction.
struct LanguageSelector: View {
    @EnvironmentObject var lang: LanguageStore

    var body: some View {
        VStack(spacing: 10) {
            Text("🌐  " + lang.t("language_label"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { language in
                    let selected = language == lang.language
                    Button {
                        lang.language = language
                    } label: {
                        Text(language.nativeName)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? Color.white : Color(hex: 0x333333))
                            .background(selected ? Theme.green : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.green : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Plant photo from a public URL, with the plant's emoji while there is no photo (or it is loading).
struct PlantPicture: View {
    let url: URL?
    let emoji: String
    var emojiSize: CGFloat = 54

    init(url: URL?, emoji: String, emojiSize: CGFloat = 54) {
        self.url = url
        self.emoji = emoji
        self.emojiSize = emojiSize
    }

    /// The shop's photo of a product, or the product's emoji until a photo exists.
    init(listing: Listing, emojiSize: CGFloat = 54) {
        self.init(url: listing.imageURL, emoji: listing.placeholderEmoji, emojiSize: emojiSize)
    }

    // The photo sits in an overlay so it can never make the view bigger than the frame
    // it is given (a big photo used to spill over the back button and the text below).
    var body: some View {
        Theme.picture
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            // The photo is drawn larger than its frame and clipped; it must not catch taps
                            // meant for the controls around it (it used to swallow the back button).
                            image.resizable().scaledToFill().allowsHitTesting(false)
                        default:
                            Text(emoji).font(.system(size: emojiSize))
                        }
                    }
                } else {
                    Text(emoji).font(.system(size: emojiSize))
                }
            }
            .clipped()
    }
}

/// Image from a short-lived signed URL (private order photos).
struct SignedImage: View {
    let path: String
    @State private var url: URL?
    @State private var failed = false
    @State private var zoomed = false

    // Shows the WHOLE photo (fit, not crop) at its own proportions, so the customer
    // sees exactly what the shop prepared.
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Text("🪴").font(.system(size: 48)).frame(height: 160)
                    default:
                        ProgressView().frame(height: 160)
                    }
                }
            } else if failed {
                Text("🪴").font(.system(size: 48)).frame(height: 160)
            } else {
                ProgressView().frame(height: 160)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.picture)
        .contentShape(Rectangle())
        .onTapGesture { if url != nil { zoomed = true } }
        .fullScreenCover(isPresented: $zoomed) {
            if let url { ImageZoomView(url: url) { zoomed = false } }
        }
        .task(id: path) {
            do { url = try await OrdersService.signedPhotoURL(path: path) } catch { failed = true }
        }
    }
}

/// Full-screen centered message with an optional retry button.
struct MessageState: View {
    @EnvironmentObject var lang: LanguageStore
    let emoji: String
    let title: String
    var detail: String? = nil
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 52))
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            if let retry {
                Button(lang.t("retry"), action: retry)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 220)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Contact (call / WhatsApp)

/// A phone number in international digits for WhatsApp: 0770... and 770... become 964770... (Iraq).
func internationalDigits(_ phone: String) -> String? {
    let digits = phone.filter { $0.isNumber }
    if digits.isEmpty { return nil }
    if digits.hasPrefix("00") { return String(digits.dropFirst(2)) }
    if digits.hasPrefix("964") { return digits }
    if digits.hasPrefix("0") { return "964" + String(digits.dropFirst()) }
    if digits.count == 10 && digits.hasPrefix("7") { return "964" + digits }
    return digits
}

func whatsappURL(phone: String, message: String?) -> URL? {
    guard let number = internationalDigits(phone), var parts = URLComponents(string: "https://wa.me/\(number)") else { return nil }
    if let message, !message.isEmpty { parts.queryItems = [URLQueryItem(name: "text", value: message)] }
    return parts.url
}

func callURL(phone: String) -> URL? {
    let number = phone.filter { $0.isNumber || $0 == "+" }
    return number.isEmpty ? nil : URL(string: "tel:\(number)")
}

/// Two buttons: call the number, or write on WhatsApp (with a ready message).
struct ContactButtons: View {
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.openURL) private var openURL
    let phone: String
    var whatsappMessage: String?

    var body: some View {
        HStack(spacing: 10) {
            Button("📞  " + lang.t("contact_call")) {
                if let url = callURL(phone: phone) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle(filled: false))
            Button("💬  " + lang.t("contact_whatsapp")) {
                if let url = whatsappURL(phone: phone, message: whatsappMessage) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle(filled: false))
        }
    }
}

// MARK: - Legal links and account deletion

/// Where the privacy policy and terms pages are published (generated by tools/build_legal.py into docs/legal).
let legalBaseURL = "https://ynela-uc.github.io/PlantApp/legal/"

/// Two small links: privacy policy and terms of use.
struct LegalLinks: View {
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.openURL) private var openURL
    var accent: Color = Theme.green

    var body: some View {
        HStack(spacing: 18) {
            Button(lang.t("legal_privacy")) { open("privacy") }
            Button(lang.t("legal_terms")) { open("terms") }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
    }

    private func open(_ kind: String) {
        if let url = URL(string: "\(legalBaseURL)\(kind)-\(lang.language.rawValue).html") { openURL(url) }
    }
}

/// The line under the sign-up button.
struct LegalAgreement: View {
    @EnvironmentObject var lang: LanguageStore
    var accent: Color = Theme.green

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lang.t("legal_agree"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            LegalLinks(accent: accent)
        }
    }
}

/// "Delete my account": asks to confirm, deletes on the server, then signs out.
struct DeleteAccountSection: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    @State private var confirm = false
    @State private var busy = false
    @State private var messageKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let key = messageKey {
                Text(lang.t(key))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.error)
            }
            Button(lang.t("delete_account")) { confirm = true }
                .buttonStyle(PrimaryButtonStyle(color: Theme.error, filled: false))
                .disabled(busy)
        }
        .alert(lang.t("delete_title"), isPresented: $confirm) {
            Button(lang.t("delete_yes"), role: .destructive) { delete() }
            Button(lang.t("delete_no"), role: .cancel) { }
        } message: {
            Text(lang.t("delete_body"))
        }
    }

    private func delete() {
        busy = true
        messageKey = nil
        Task {
            do {
                try await AuthService.deleteMyAccount()
                app.signOut()
            } catch {
                let reason = "\(error) \(error.localizedDescription)"
                messageKey = reason.contains("open_orders") ? "delete_blocked" : "delete_failed"
            }
            busy = false
        }
    }
}

// MARK: - Addresses

/// An address as the person types it. `city` is the governorate code (see Cities); `street` is the street or building.
/// Iraq has no dependable street names or postcodes, so the landmark counts as much as the street.
struct AddressDraft: Equatable {
    var city = ""
    var district = ""
    var neighborhood = ""
    var street = ""
    var landmark = ""
    var notes = ""

    private static func filled(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Governorate, district and neighborhood are needed, plus a street/building or a landmark to find the door.
    var isComplete: Bool {
        !city.isEmpty && Self.filled(district) && Self.filled(neighborhood) && (Self.filled(street) || Self.filled(landmark))
    }

    var trimmed: AddressDraft {
        let clean: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return AddressDraft(city: city, district: clean(district), neighborhood: clean(neighborhood), street: clean(street), landmark: clean(landmark), notes: clean(notes))
    }
}

/// Governorate pills and the address fields, one below the other.
struct AddressFields: View {
    @EnvironmentObject var lang: LanguageStore
    @Binding var draft: AddressDraft
    var accent: Color = Theme.green

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The governorate as a drop-down list, sorted by name in the app language.
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t("field_city"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Menu {
                    ForEach(Cities.codes.sorted { lang.cityName($0).localizedCompare(lang.cityName($1)) == .orderedAscending }, id: \.self) { code in
                        Button(lang.cityName(code)) { draft.city = code }
                    }
                } label: {
                    HStack {
                        Text(draft.city.isEmpty ? " " : lang.cityName(draft.city))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
            }
            AppField(title: lang.t("field_district"), text: $draft.district)
            AppField(title: lang.t("field_neighborhood"), text: $draft.neighborhood)
            AppField(title: lang.t("field_address"), text: $draft.street)
            AppField(title: lang.t("field_landmark"), text: $draft.landmark)
            AppField(title: lang.t("field_address_notes"), text: $draft.notes, multiline: true)
        }
    }
}

extension LanguageStore {
    /// The address on one line, for lists and summaries: governorate, district, neighborhood, street, "near landmark".
    func addressText(city: String, district: String, neighborhood: String, street: String, landmark: String) -> String {
        var parts: [String] = []
        if !city.isEmpty { parts.append(cityName(city)) }
        for part in [district, neighborhood, street] where !part.isEmpty { parts.append(part) }
        if !landmark.isEmpty { parts.append(t("address_near", landmark)) }
        return parts.joined(separator: ", ")
    }

    /// Only the area (governorate and district): shown to a shop before it accepts the order.
    func areaText(city: String, district: String) -> String {
        [city.isEmpty ? "" : cityName(city), district].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Address book

let addressLabelKeys = ["home", "work", "apartment"]

extension SavedAddress {
    var draft: AddressDraft { AddressDraft(city: city, district: district, neighborhood: neighborhood, street: street, landmark: landmark, notes: notes) }
}

extension LanguageStore {
    /// The name of an address: home / work / apartment in the app language, or the customer's own text.
    func addressLabel(_ label: String) -> String {
        switch label {
        case "home": return t("addr_label_home")
        case "work": return t("addr_label_work")
        case "apartment": return t("addr_label_apartment")
        case "": return t("addr_label_other")
        default: return label
        }
    }
}

/// What the editor sheet opens for: a new address (`address` nil) or a saved one.
struct AddressEditTarget: Identifiable {
    let address: SavedAddress?
    var id: String { address?.id ?? "new" }
}

/// The saved addresses on the account page, with the buttons to add, edit and choose the default.
struct AddressBookSection: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    @State private var editing: AddressEditTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("addr_book_title"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.greenDark)
            if model.addresses.isEmpty { Text(lang.t("addr_empty")).foregroundStyle(Theme.muted) }
            ForEach(model.addresses) { address in card(address) }
            if model.addresses.count < maxAddresses {
                Button("+  " + lang.t("addr_add")) { editing = AddressEditTarget(address: nil) }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
            } else {
                Text(lang.t("addr_max")).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        .sheet(item: $editing) { target in
            AddressEditorSheet(initial: target.address, isFirst: model.addresses.isEmpty)
        }
    }

    private func card(_ address: SavedAddress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(lang.addressLabel(address.label)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.greenDark)
                if address.isDefault {
                    Text(lang.t("addr_default"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.greenSoft)
                        .clipShape(Capsule())
                }
            }
            Text(lang.addressText(city: address.city, district: address.district, neighborhood: address.neighborhood, street: address.street, landmark: address.landmark))
            if !address.notes.isEmpty { Text(address.notes).font(.system(size: 13)).foregroundStyle(Theme.muted) }
            HStack(spacing: 16) {
                Button(lang.t("addr_edit")) { editing = AddressEditTarget(address: address) }
                if !address.isDefault {
                    Button(lang.t("addr_set_default")) { model.setDefaultAddress(address.id) }.disabled(model.addressBusy)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.green)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Add a new address, or edit (and delete) a saved one.
struct AddressEditorSheet: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    @Environment(\.dismiss) private var dismiss
    let initial: SavedAddress?
    /// True when no address exists yet: the new one becomes the default.
    let isFirst: Bool

    @State private var labelKey: String
    @State private var custom: String
    @State private var addr: AddressDraft
    @State private var makeDefault: Bool
    @State private var missing = false
    @State private var confirmDelete = false

    init(initial: SavedAddress?, isFirst: Bool) {
        self.initial = initial
        self.isFirst = isFirst
        let startKey: String
        if let initial {
            startKey = addressLabelKeys.contains(initial.label) ? initial.label : "other"
        } else {
            startKey = isFirst ? "home" : "other"
        }
        _labelKey = State(initialValue: startKey)
        _custom = State(initialValue: (initial != nil && !addressLabelKeys.contains(initial?.label ?? "")) ? (initial?.label ?? "") : "")
        _addr = State(initialValue: initial?.draft ?? AddressDraft())
        _makeDefault = State(initialValue: initial?.isDefault ?? isFirst)
    }

    private var lockedDefault: Bool { isFirst || initial?.isDefault == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t(initial == nil ? "addr_new_title" : "addr_edit_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Group {
                    Text(lang.t("addr_label_title"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    FlowLayout(spacing: 8) {
                        ForEach(addressLabelKeys + ["other"], id: \.self) { key in
                            Pill(label: lang.addressLabel(key == "other" ? "" : key), selected: labelKey == key) { labelKey = key }
                        }
                    }
                    if labelKey == "other" {
                        AppField(title: lang.t("addr_label_custom_hint"), text: $custom)
                            .onChange(of: custom) { value in
                                if value.count > 40 { custom = String(value.prefix(40)) }
                            }
                    }
                }
                AddressFields(draft: $addr)
                Toggle(lang.t("addr_make_default"), isOn: $makeDefault)
                    .tint(Theme.green)
                    .disabled(lockedDefault)
                if missing {
                    ErrorText(message: lang.t("err_required"))
                } else if model.addressFailed {
                    ErrorText(message: lang.t("addr_save_failed"))
                }
                Button(action: save) {
                    BusyLabel(title: lang.t("action_save"), busy: model.addressBusy)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.addressBusy)
                Button(lang.t("action_cancel")) { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                    .disabled(model.addressBusy)
                if let initial {
                    Button(lang.t("addr_delete")) { confirmDelete = true }
                        .foregroundStyle(Theme.error)
                        .disabled(model.addressBusy)
                        .alert(lang.t("addr_delete_title"), isPresented: $confirmDelete) {
                            Button(lang.t("addr_delete"), role: .destructive) {
                                model.deleteAddress(id: initial.id) { dismiss() }
                            }
                            Button(lang.t("action_cancel"), role: .cancel) { }
                        } message: {
                            Text(lang.t("addr_delete_body"))
                        }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .onAppear { model.addressFailed = false }
    }

    private func save() {
        if !addr.isComplete {
            missing = true
            return
        }
        missing = false
        let label = labelKey == "other" ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : labelKey
        model.saveAddress(id: initial?.id, label: label, draft: addr.trimmed, makeDefault: makeDefault || lockedDefault) { dismiss() }
    }
}

/// Checkout: choose one of the saved addresses, or type another one for this order only.
struct AddressPicker: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    @Binding var selectedId: String?
    @Binding var choseOther: Bool
    @Binding var draft: AddressDraft
    @Binding var saveNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.addresses.isEmpty {
                ForEach(model.addresses) { address in
                    choice(
                        title: lang.addressLabel(address.label),
                        detail: lang.addressText(city: address.city, district: address.district, neighborhood: address.neighborhood, street: address.street, landmark: address.landmark),
                        selected: selectedId == address.id
                    ) {
                        selectedId = address.id
                        choseOther = false
                        draft = address.draft
                    }
                }
                choice(title: lang.t("checkout_use_other"), detail: nil, selected: selectedId == nil) {
                    selectedId = nil
                    choseOther = true
                }
            }
            if selectedId == nil {
                AddressFields(draft: $draft)
                    .padding(.top, 4)
                if model.addresses.count < maxAddresses {
                    Toggle(lang.t("checkout_save_address"), isOn: $saveNew).tint(Theme.green)
                }
            }
        }
    }

    private func choice(title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.greenDark)
                if let detail { Text(detail).font(.system(size: 14)).foregroundStyle(Color.primary).multilineTextAlignment(.leading) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.greenSoft : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.green : Theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ratings

/// A shop shows stars only after this many ratings; before that it is "New".
let ratingMinCount = 3

@MainActor
func ratingLabel(_ lang: LanguageStore, rating: Double, count: Int) -> String {
    count >= ratingMinCount ? "★ \(String(format: "%.1f", rating)) (\(count))" : lang.t("rating_new")
}

/// Five stars; tap one to choose when `onPick` is given.
struct StarsRow: View {
    let stars: Int
    var onPick: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Text(i <= stars ? "★" : "☆")
                    .font(.system(size: onPick != nil ? 34 : 18))
                    .foregroundStyle(Color(hex: 0xF2B544))
                    .onTapGesture { onPick?(i) }
            }
        }
    }
}

/// The latest reviews of a shop (shown on its page).
struct ShopReviewsSection: View {
    @EnvironmentObject var lang: LanguageStore
    let shopId: String
    @State private var ratings: [Rating]?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ratings {
                Text(lang.t("reviews_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                if ratings.isEmpty {
                    Text(lang.t("reviews_empty")).foregroundStyle(Theme.muted)
                }
                ForEach(ratings) { rating in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            StarsRow(stars: rating.stars)
                            Text(rating.reviewerName.isEmpty ? lang.t("reviewer_anonymous") : rating.reviewerName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(String(rating.createdAt.prefix(10)))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        if let comment = rating.comment, !comment.isEmpty {
                            Text(comment).font(.system(size: 14))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .task { ratings = (try? await RatingsService.forShop(shopId)) ?? [] }
    }
}

/// On a delivered order: the customer's rating, or the form to give one.
struct RateOrderSection: View {
    @EnvironmentObject var lang: LanguageStore
    let orderId: String

    @State private var mine: Rating?
    @State private var loaded = false
    @State private var stars = 0
    @State private var comment = ""
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if loaded {
                if let mine {
                    Text(lang.t("rate_yours"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    StarsRow(stars: mine.stars)
                    if let text = mine.comment, !text.isEmpty { Text(text) }
                } else {
                    Text(lang.t("rate_title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    StarsRow(stars: stars) { stars = $0 }
                    AppField(title: lang.t("rate_comment_hint"), text: $comment)
                        .onChange(of: comment) { value in
                            if value.count > 300 { comment = String(value.prefix(300)) }
                        }
                    if failed { ErrorText(message: lang.t("rate_failed")) }
                    Button {
                        Task { await send() }
                    } label: {
                        BusyLabel(title: lang.t("rate_send"), busy: busy)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(stars == 0 || busy)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.greenSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(loaded ? 1 : 0)
        .task {
            mine = try? await RatingsService.forOrder(orderId)
            loaded = true
        }
    }

    private func send() async {
        busy = true
        failed = false
        do {
            try await RatingsService.rate(orderId: orderId, stars: stars, comment: comment)
            mine = try? await RatingsService.forOrder(orderId)
        } catch {
            failed = true
        }
        busy = false
    }
}

// MARK: - Admin home

/// What the admin may decide for a shop in each state.
private func allowedDecisions(_ status: String) -> [ShopDecision] {
    switch status {
    case "pending": return [.approve, .changes, .reject]
    case "approved": return [.changes, .reject]
    case "changes_requested": return [.approve, .reject]
    default: return [.approve]
    }
}

private struct ReviewAsk: Identifiable {
    let shop: PendingShop
    let decision: ShopDecision
    var id: String { shop.id + decision.rawValue }
}

/// The home of the admin account: every shop, with the decisions and the moderation tools. No shop, cart or orders.
struct AdminRoot: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    let profile: Profile

    @State private var shops: [PendingShop]?
    @State private var failed = false
    @State private var busyId: String?
    @State private var filter = "pending"
    @State private var ask: ReviewAsk?
    @State private var previewing: PendingShop?

    private let filters: [(status: String, key: String)] = [
        ("pending", "approvals_filter_waiting"),
        ("approved", "approvals_filter_approved"),
        ("changes_requested", "approvals_filter_changes"),
        ("rejected", "approvals_filter_rejected"),
    ]

    private func count(_ status: String) -> Int { (shops ?? []).filter { $0.reviewStatus == status }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("admin_home_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Text(profile.fullName).foregroundStyle(Theme.muted)
            }
            .padding(16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.status) { item in
                        Pill(label: lang.t(item.key) + (shops == nil ? "" : " (\(count(item.status)))"), selected: filter == item.status) {
                            filter = item.status
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let shops {
                        if failed { ErrorText(message: lang.t("approvals_failed")) }
                        let shown = shops.filter { $0.reviewStatus == filter }
                        if shown.isEmpty { Text(lang.t("approvals_empty")).foregroundStyle(Theme.muted).padding(.top, 12) }
                        ForEach(shown) { shop in card(shop) }
                    } else if failed {
                        ErrorText(message: lang.t("approvals_failed")).padding(.top, 12)
                    } else {
                        ProgressView().tint(Theme.green).frame(maxWidth: .infinity).padding(24)
                    }
                    LanguageSelector().padding(.top, 24)
                    Button(lang.t("action_signout")) { app.signOut() }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable { await load() }
        }
        .background(AppBackground())
        .task { await load() }
        .sheet(item: $ask) { item in
            ReviewNoteSheet(
                title: lang.t(item.decision == .changes ? "approvals_changes" : "approvals_reject"),
                hint: lang.t(item.decision == .changes ? "approvals_changes_hint" : "approvals_reject_hint")
            ) { note in decide(item.shop, item.decision, note) }
        }
        .fullScreenCover(item: $previewing) { shop in
            ShopPreviewView(shop: shop, busy: busyId == shop.id, onClose: { previewing = nil }) { decision in
                previewing = nil
                choose(shop, decision)
            }
        }
    }

    private func card(_ shop: PendingShop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shop.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.greenDark)
            Text(lang.cityName(shop.city) + (shop.approved ? "  ·  " + ratingLabel(lang, rating: shop.rating, count: shop.ratingCount) : ""))
                .foregroundStyle(Theme.muted)
            Text(lang.t("approvals_owner", shop.ownerName.isEmpty ? "-" : shop.ownerName, shop.ownerEmail))
            if !shop.phone.isEmpty { Text(shop.phone) }
            Text(lang.addressText(city: shop.city, district: shop.district, neighborhood: shop.neighborhood, street: shop.address, landmark: shop.landmark))
                .foregroundStyle(Theme.muted)
            if !shop.shopTypes.isEmpty {
                Text(shop.shopTypes.map { lang.t("sec_" + $0) }.joined(separator: ", ")).foregroundStyle(Theme.muted)
            }
            if !shop.bio.isEmpty { Text(shop.bio).padding(.top, 2) }
            if let note = shop.reviewNote, !note.isEmpty {
                Text(lang.t("approvals_your_note", note)).font(.system(size: 13)).foregroundStyle(Theme.amber)
            }
            Button(lang.t("approvals_view", shop.productCount)) { previewing = shop }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            DecisionButtons(busy: busyId == shop.id, allowed: allowedDecisions(shop.reviewStatus)) { choose(shop, $0) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func load() async {
        do {
            shops = try await AdminService.shops()
            failed = false
        } catch {
            failed = true
        }
    }

    private func choose(_ shop: PendingShop, _ decision: ShopDecision) {
        if decision == .approve { decide(shop, decision, nil) } else { ask = ReviewAsk(shop: shop, decision: decision) }
    }

    private func decide(_ shop: PendingShop, _ decision: ShopDecision, _ note: String?) {
        busyId = shop.id
        Task {
            do {
                try await AdminService.review(shopId: shop.id, decision: decision, note: note)
                await load()
            } catch {
                failed = true
            }
            busyId = nil
        }
    }
}

/// A short reason typed by the admin (at least 3 characters).
private struct ReviewNoteSheet: View {
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let hint: String
    let onSend: (String) -> Void

    @State private var note = ""

    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.greenDark)
            AppField(title: hint, text: $note, multiline: true)
                .onChange(of: note) { value in
                    if value.count > 500 { note = String(value.prefix(500)) }
                }
            Button(lang.t("approvals_send")) {
                onSend(trimmed)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmed.count < 3)
            Button(lang.t("action_cancel")) { dismiss() }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            Spacer()
        }
        .padding(20)
        .background(AppBackground())
    }
}

private struct DecisionButtons: View {
    @EnvironmentObject var lang: LanguageStore
    let busy: Bool
    let allowed: [ShopDecision]
    let onDecide: (ShopDecision) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if busy {
                ProgressView().tint(Theme.green)
            } else {
                ForEach(allowed, id: \.rawValue) { decision in
                    switch decision {
                    case .approve:
                        Button(lang.t("approvals_approve")) { onDecide(decision) }
                            .buttonStyle(PrimaryButtonStyle())
                    case .changes:
                        Button(lang.t("approvals_changes")) { onDecide(decision) }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                    case .reject:
                        Button(lang.t("approvals_reject")) { onDecide(decision) }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.error, filled: false))
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Everything a customer would see about the shop, so the admin can decide: details, delivery, every product and the reviews.
private struct ShopPreviewView: View {
    @EnvironmentObject var lang: LanguageStore
    let shop: PendingShop
    let busy: Bool
    let onClose: () -> Void
    let onDecide: (ShopDecision) -> Void

    @State private var products: [Listing]?
    @State private var ratings: [Rating] = []
    @State private var failed = false
    @State private var removingProduct: Listing?
    @State private var removingRating: Rating?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    HStack(alignment: .top) {
                        Text(shop.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        Spacer()
                        Button(lang.t("approvals_close"), action: onClose)
                    }
                    Text(lang.cityName(shop.city) + (shop.approved ? "  ·  " + ratingLabel(lang, rating: shop.rating, count: shop.ratingCount) : ""))
                        .foregroundStyle(Theme.muted)
                    Text(lang.t("approvals_owner", shop.ownerName.isEmpty ? "-" : shop.ownerName, shop.ownerEmail)).padding(.top, 6)
                    if !shop.phone.isEmpty { Text(shop.phone) }
                    Text(lang.addressText(city: shop.city, district: shop.district, neighborhood: shop.neighborhood, street: shop.address, landmark: shop.landmark))
                    if !shop.addressNotes.isEmpty { Text(shop.addressNotes).foregroundStyle(Theme.muted) }
                    if !shop.shopTypes.isEmpty {
                        Text(shop.shopTypes.map { lang.t("sec_" + $0) }.joined(separator: ", ")).foregroundStyle(Theme.muted)
                    }
                    if !shop.bio.isEmpty { Text(shop.bio).padding(.top, 4) }
                }
                Group {
                    Text(lang.t("shop_delivery"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.top, 10)
                    Text(
                        shop.deliveryScope == "nationwide"
                            ? lang.t("delivers_nationwide")
                            : (shop.deliversTo.isEmpty ? lang.cityName(shop.city) : shop.deliversTo.map { lang.cityName($0) }.joined(separator: ", "))
                    )
                    Text(lang.t("shop_fee_title") + ": " + lang.price(shop.deliveryFeeIqd))
                    ForEach(shop.deliveryFees.sorted(by: { $0.key < $1.key }), id: \.key) { city, fee in
                        Text(lang.cityName(city) + ": " + lang.price(fee)).foregroundStyle(Theme.muted)
                    }
                    if let note = shop.reviewNote, !note.isEmpty {
                        Text(lang.t("approvals_your_note", note)).foregroundStyle(Theme.amber).padding(.top, 6)
                    }
                    Text(lang.t("approvals_products", products?.count ?? shop.productCount))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.top, 14)
                }
                if let products {
                    if products.isEmpty { Text(lang.t("approvals_no_products")).foregroundStyle(Theme.muted) }
                    ForEach(products) { listing in productCard(listing) }
                } else if failed {
                    ErrorText(message: lang.t("approvals_failed"))
                } else {
                    ProgressView().tint(Theme.green).padding()
                }
                Text(lang.t("approvals_reviews", ratings.count))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                    .padding(.top, 14)
                if ratings.isEmpty && products != nil { Text(lang.t("approvals_no_reviews")).foregroundStyle(Theme.muted) }
                ForEach(ratings) { rating in reviewRow(rating) }
                DecisionButtons(busy: busy, allowed: allowedDecisions(shop.reviewStatus), onDecide: onDecide).padding(.top, 12)
            }
            .padding(16)
        }
        .background(AppBackground())
        .task { await load() }
        .sheet(item: $removingProduct) { listing in
            ReviewNoteSheet(title: lang.t("approvals_delete_product"), hint: lang.t("approvals_delete_hint")) { note in
                Task {
                    do { try await AdminService.deleteListing(id: listing.id, reason: note); await load() } catch { failed = true }
                }
            }
        }
        .sheet(item: $removingRating) { rating in
            ReviewNoteSheet(title: lang.t("approvals_delete_review"), hint: lang.t("approvals_delete_review_hint")) { note in
                Task {
                    do { try await AdminService.deleteRating(id: rating.id, reason: note); await load() } catch { failed = true }
                }
            }
        }
    }

    private func load() async {
        do {
            products = try await AdminService.listings(shopId: shop.id)
            ratings = try await AdminService.ratings(shopId: shop.id)
            failed = false
        } catch {
            failed = true
        }
    }

    private func reviewRow(_ rating: Rating) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                StarsRow(stars: rating.stars)
                Text(rating.reviewerName.isEmpty ? lang.t("reviewer_anonymous") : rating.reviewerName)
                    .font(.system(size: 14, weight: .semibold))
                Text(String(rating.createdAt.prefix(10))).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            if let comment = rating.comment, !comment.isEmpty { Text(comment).font(.system(size: 14)) }
            Button(lang.t("approvals_delete_review")) { removingRating = rating }
                .font(.system(size: 14))
                .foregroundStyle(Theme.error)
        }
        .padding(.vertical, 4)
    }

    private func productCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ListingPhoto(listing: listing, emojiSize: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.localized(listing.name))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Text(productLine(listing))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    Text(lang.price(listing.priceIqd)).font(.system(size: 16, weight: .bold))
                    if let old = listing.oldPriceIqd, old > listing.priceIqd {
                        Text(lang.price(old)).strikethrough().foregroundStyle(Theme.muted)
                    }
                }
                if let pieces = listing.pieces { Text(lang.t("approvals_pieces", pieces)).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                if !listing.inStock { Text(lang.t("approvals_out_of_stock")).font(.system(size: 12)).foregroundStyle(Theme.error) }
                if !lang.localized(listing.description).isEmpty { Text(lang.localized(listing.description)).font(.system(size: 14)) }
                ForEach(Array(listing.options.enumerated()), id: \.offset) { _, option in
                    Text(option.name + ": " + option.values.joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Button(lang.t("approvals_delete_product")) { removingProduct = listing }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.error)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .padding(.vertical, 4)
    }

    private func productLine(_ listing: Listing) -> String {
        var parts = [lang.t("sec_" + listing.section)]
        if let category = listing.category { parts.append(lang.t("cat_" + category)) }
        if let collection = listing.collection, !collection.isEmpty { parts.append(collection) }
        return parts.joined(separator: "  ·  ")
    }
}

// MARK: - Photos shown whole, tap to open full screen

/// A product photo shown whole (never cropped), at its own proportions. Tap it to open it full screen.
/// Without a photo it shows the product's emoji.
struct ListingPhoto: View {
    let listing: Listing
    var emojiSize: CGFloat = 96
    var emptyHeight: CGFloat = 160
    @State private var zoomed = false

    var body: some View {
        if let url = listing.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Text(listing.placeholderEmoji).font(.system(size: emojiSize)).frame(height: emptyHeight)
                default:
                    ProgressView().frame(height: emptyHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 420)
            .background(Theme.picture)
            .contentShape(Rectangle())
            .onTapGesture { zoomed = true }
            .fullScreenCover(isPresented: $zoomed) { ImageZoomView(url: url) { zoomed = false } }
        } else {
            PlantPicture(listing: listing, emojiSize: emojiSize)
                .frame(maxWidth: .infinity)
                .frame(height: emptyHeight)
        }
    }
}

/// Full-screen viewer: pinch to zoom, drag to move, double tap to zoom in or out, tap to close.
struct ImageZoomView: View {
    let url: URL
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .onTapGesture(count: 2) { toggleZoom() }
                        .onTapGesture { if scale == 1 { onClose() } }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = max(1, min(5, baseScale * value)) }
                                .onEnded { _ in
                                    baseScale = scale
                                    if scale == 1 { resetOffset() }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(width: baseOffset.width + value.translation.width, height: baseOffset.height + value.translation.height)
                                    }
                                }
                                .onEnded { _ in baseOffset = offset }
                        )
                default:
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Button(action: onClose) {
                Text("✕")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .padding(16)
            }
        }
    }

    private func toggleZoom() {
        withAnimation {
            scale = scale > 1 ? 1 : 2.5
            baseScale = scale
            resetOffset()
        }
    }

    private func resetOffset() {
        offset = .zero
        baseOffset = .zero
    }
}
