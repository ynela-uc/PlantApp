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
    let plantKey: String?
    var emojiSize: CGFloat = 54

    // The photo sits in an overlay so it can never make the view bigger than the frame
    // it is given (a big photo used to spill over the back button and the text below).
    var body: some View {
        Theme.picture
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Text(plantEmoji(plantKey)).font(.system(size: emojiSize))
                        }
                    }
                } else {
                    Text(plantEmoji(plantKey)).font(.system(size: emojiSize))
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
