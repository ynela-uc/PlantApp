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

// MARK: - Shop approvals (admin only)

/// Shown on the account page of the admin only: a button that opens the shop approvals.
/// Everyone else sees nothing (and the database refuses their calls anyway).
struct AdminEntry: View {
    @EnvironmentObject var lang: LanguageStore
    let accent: Color

    @State private var isAdmin = false
    @State private var waiting = 0
    @State private var open = false

    var body: some View {
        Group {
            if isAdmin {
                Button {
                    open = true
                } label: {
                    Text(waiting > 0 ? "\(lang.t("approvals_title")) (\(waiting))" : lang.t("approvals_title"))
                }
                .buttonStyle(PrimaryButtonStyle(color: accent))
                .padding(.top, 16)
            }
        }
        .task(id: open) {
            isAdmin = (try? await AdminService.isAdmin()) ?? false
            if isAdmin {
                waiting = ((try? await AdminService.shops()) ?? []).filter { $0.reviewStatus == "pending" }.count
            }
        }
        .fullScreenCover(isPresented: $open) { ApprovalsView { open = false } }
    }
}

private struct ReviewAsk: Identifiable {
    let shop: PendingShop
    let decision: ShopDecision
    var id: String { shop.id + decision.rawValue }
}

private struct ApprovalsView: View {
    @EnvironmentObject var lang: LanguageStore
    let onClose: () -> Void

    @State private var shops: [PendingShop]?
    @State private var failed = false
    @State private var busyId: String?
    @State private var ask: ReviewAsk?
    @State private var previewing: PendingShop?

    private let groups: [(status: String, titleKey: String)] = [
        ("pending", "approvals_section_waiting"),
        ("changes_requested", "approvals_section_changes"),
        ("rejected", "approvals_section_rejected"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.t("approvals_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Spacer()
                Button(lang.t("approvals_close"), action: onClose)
            }
            .padding(16)

            if let shops {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if failed { ErrorText(message: lang.t("approvals_failed")) }
                        if shops.isEmpty {
                            Text(lang.t("approvals_empty")).foregroundStyle(Theme.muted)
                        }
                        ForEach(groups, id: \.status) { group in
                            sectionView(group.titleKey, shops.filter { $0.reviewStatus == group.status })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            } else if failed {
                ErrorText(message: lang.t("approvals_failed")).padding(16)
            } else {
                ProgressView().tint(Theme.green).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .background(AppBackground())
        .task { await load() }
        .sheet(item: $ask) { item in
            ReviewNoteSheet(ask: item) { note in decide(item.shop, item.decision, note) }
        }
        .fullScreenCover(item: $previewing) { shop in
            ShopPreviewView(shop: shop, busy: busyId == shop.id, onClose: { previewing = nil }) { decision in
                previewing = nil
                choose(shop, decision)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ titleKey: String, _ group: [PendingShop]) -> some View {
        if !group.isEmpty {
            Text(lang.t(titleKey))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .padding(.top, 10)
            ForEach(group) { shop in card(shop) }
        }
    }

    private func card(_ shop: PendingShop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shop.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.greenDark)
            Text(lang.cityName(shop.city)).foregroundStyle(Theme.muted)
            Text(lang.t("approvals_owner", shop.ownerName.isEmpty ? "-" : shop.ownerName, shop.ownerEmail))
            if !shop.phone.isEmpty { Text(shop.phone) }
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
            if shop.reviewStatus == "pending" {
                DecisionButtons(busy: busyId == shop.id) { choose(shop, $0) }
            }
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

private struct ReviewNoteSheet: View {
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.dismiss) private var dismiss
    let ask: ReviewAsk
    let onSend: (String) -> Void

    @State private var note = ""

    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let changes = ask.decision == .changes
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t(changes ? "approvals_changes" : "approvals_reject"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.greenDark)
            AppField(title: lang.t(changes ? "approvals_changes_hint" : "approvals_reject_hint"), text: $note, multiline: true)
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
    let onDecide: (ShopDecision) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if busy {
                ProgressView().tint(Theme.green)
            } else {
                Button(lang.t("approvals_approve")) { onDecide(.approve) }
                    .buttonStyle(PrimaryButtonStyle())
                Button(lang.t("approvals_changes")) { onDecide(.changes) }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                Button(lang.t("approvals_reject")) { onDecide(.reject) }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.error, filled: false))
            }
        }
        .padding(.top, 8)
    }
}

/// Everything a customer would see about the shop, so the admin can decide: details, delivery and every product with its photo.
private struct ShopPreviewView: View {
    @EnvironmentObject var lang: LanguageStore
    let shop: PendingShop
    let busy: Bool
    let onClose: () -> Void
    let onDecide: (ShopDecision) -> Void

    @State private var products: [Listing]?
    @State private var failed = false

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
                    Text(lang.cityName(shop.city)).foregroundStyle(Theme.muted)
                    Text(lang.t("approvals_owner", shop.ownerName.isEmpty ? "-" : shop.ownerName, shop.ownerEmail)).padding(.top, 6)
                    if !shop.phone.isEmpty { Text(shop.phone) }
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
                if shop.reviewStatus == "pending" {
                    DecisionButtons(busy: busy, onDecide: onDecide).padding(.top, 12)
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .task {
            do { products = try await AdminService.listings(shopId: shop.id) } catch { failed = true }
        }
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
