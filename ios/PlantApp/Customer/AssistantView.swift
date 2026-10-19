import SwiftUI

/// The plant-help chat: photo or question in, answer plus "where to buy" out.
struct AssistantView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    @EnvironmentObject var assistant: AssistantModel

    @State private var input = ""
    @State private var showCamera = false
    @State private var showLibrary = false

    private var code: String { lang.language.rawValue }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(lang.t("ai_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Spacer()
                if !assistant.messages.isEmpty {
                    Button(lang.t("ai_new_chat")) { assistant.newChat() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.green)
                        .disabled(assistant.busy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if assistant.messages.isEmpty {
                emptyState
            } else {
                conversation
            }

            if let error = assistant.error {
                Text(lang.t(error.key))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.error)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.errorSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            inputBar
        }
        .background(AppBackground())
        .photoSheets(camera: $showCamera, library: $showLibrary) { data in
            assistant.sendPhoto(data, language: code)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🌿").font(.system(size: 64))
            Text(lang.t("ai_intro"))
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button {
                openCamera(camera: $showCamera, library: $showLibrary)
            } label: {
                Text("📷  " + lang.t("photo_take"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 12)
            Button(lang.t("photo_pick")) { showLibrary = true }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(assistant.messages) { message in
                        if message.fromUser {
                            UserBubble(message: message)
                        } else {
                            AssistantBubble(
                                message: message,
                                isLast: message.id == assistant.messages.last?.id && !assistant.busy
                            ) { question in
                                assistant.sendText(question, language: code)
                            }
                        }
                    }
                    if assistant.busy {
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.green)
                            Text(lang.t("ai_thinking")).foregroundStyle(Theme.muted)
                            Spacer()
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: assistant.messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: assistant.busy) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: Input

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button { openCamera(camera: $showCamera, library: $showLibrary) } label: {
                    Text("📷").font(.system(size: 24))
                }
                .disabled(assistant.busy)
                Button { showLibrary = true } label: {
                    Text("🖼").font(.system(size: 24))
                }
                .disabled(assistant.busy)

                TextField(lang.t("ai_input_hint"), text: $input, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                Button {
                    let text = input
                    input = ""
                    assistant.sendText(text, language: code)
                } label: {
                    Text(lang.t("ai_send"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(canSend ? 1 : 0.4)
                }
                .disabled(!canSend)
            }
            Text(lang.t("ai_disclaimer"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBar()
    }

    private var canSend: Bool {
        !assistant.busy && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct UserBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 40)
            VStack(alignment: .leading, spacing: 6) {
                if let data = message.photo, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if !message.text.isEmpty {
                    Text(message.text).foregroundStyle(.white)
                }
            }
            .padding(10)
            .background(Theme.green)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct AssistantBubble: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let message: ChatMessage
    let isLast: Bool
    let onFollowUp: (String) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                if let reply = message.reply, reply.identified {
                    HStack(spacing: 8) {
                        Text(lang.localized(reply.names.map))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        HealthChip(health: reply.health)
                    }
                    if !reply.scientificName.isEmpty {
                        Text(reply.scientificName)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer().frame(height: 8)
                }
                Text(message.text).font(.system(size: 15))

                if let reply = message.reply, reply.identified {
                    whereToBuy(reply)
                }

                if isLast, let reply = message.reply, !reply.followUps.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(reply.followUps.prefix(3).enumerated()), id: \.offset) { _, question in
                            Button { onFollowUp(question) } label: {
                                Text(question)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.greenDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.greenSoft)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(14)
            .card(radius: 18)
            Spacer(minLength: 24)
        }
    }

    @ViewBuilder
    private func whereToBuy(_ reply: AssistantReply) -> some View {
        let matches = Array(findShops(reply: reply, listings: model.listings, city: model.city).prefix(8))
        Text("🛒  " + lang.t("ai_where_to_buy"))
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.greenDark)
            .padding(.top, 14)
            .padding(.bottom, 6)
        if matches.isEmpty {
            Text(lang.t("ai_no_shops")).font(.system(size: 13)).foregroundStyle(Theme.muted)
        } else {
            ForEach(ShopReach.allCases, id: \.rawValue) { reach in
                let group = matches.filter { $0.reach == reach }
                if !group.isEmpty {
                    Text(header(for: reach))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    ForEach(group) { match in
                        ShopRow(match: match) { model.openListing(match.listing.id) }
                    }
                }
            }
        }
    }

    private func header(for reach: ShopReach) -> String {
        let city = lang.cityName(model.city)
        switch reach {
        case .sameCity: return lang.t("ai_group_city", city)
        case .delivers: return lang.t("ai_group_delivers", city)
        case .otherCity: return lang.t("ai_group_other", city)
        }
    }
}

private struct HealthChip: View {
    @EnvironmentObject var lang: LanguageStore
    let health: String

    var body: some View {
        switch health {
        case "healthy": chip("ai_health_healthy", Theme.greenSoft, Theme.greenDark)
        case "needs_attention": chip("ai_health_attention", Theme.amberSoft, Theme.amber)
        case "unhealthy": chip("ai_health_unhealthy", Theme.errorSoft, Theme.error)
        default: EmptyView()
        }
    }

    private func chip(_ key: String, _ background: Color, _ foreground: Color) -> some View {
        Text(lang.t(key))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}

private struct ShopRow: View {
    @EnvironmentObject var lang: LanguageStore
    let match: ShopMatch
    let action: () -> Void

    var body: some View {
        let listing = match.listing
        Button(action: action) {
            HStack(spacing: 10) {
                PlantPicture(url: listing.imageURL, plantKey: listing.plantKey, emojiSize: 24)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.localized(listing.name))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .lineLimit(1)
                    if let shop = listing.sellers {
                        Text("\(shop.name) · \(lang.cityName(shop.city))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lang.price(listing.priceIqd))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                    if !match.exact {
                        Text(lang.t("ai_similar")).font(.system(size: 11)).foregroundStyle(Theme.amber)
                    }
                }
            }
            .padding(8)
            .background(Color(hex: 0xF7FBF7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }
}
