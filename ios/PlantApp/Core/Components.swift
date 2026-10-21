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
