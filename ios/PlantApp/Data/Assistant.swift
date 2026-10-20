import Foundation

/// What the plant-assistant function returns for one question. Text is already in the user's language.
struct AssistantReply: Codable, Equatable {
    var identified = false
    var confidence = "low"
    var plantKey = "Other"
    var scientificName = ""
    var names = Tri()
    /// healthy / needs_attention / unhealthy / unknown
    var health = "unknown"
    var answer = ""
    var followUps: [String] = []
    /// Part of the marketplace that matches the question (Catalog keys; empty when nothing fits).
    var browseSection = ""
    var browseCategory = ""
    var browseOccasion = ""

    enum CodingKeys: String, CodingKey {
        case identified, confidence, names, health, answer
        case browseSection = "browse_section"
        case browseCategory = "browse_category"
        case browseOccasion = "browse_occasion"
        case plantKey = "plant_key"
        case scientificName = "scientific_name"
        case followUps = "follow_ups"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identified = try c.decodeIfPresent(Bool.self, forKey: .identified) ?? false
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence) ?? "low"
        plantKey = try c.decodeIfPresent(String.self, forKey: .plantKey) ?? "Other"
        scientificName = try c.decodeIfPresent(String.self, forKey: .scientificName) ?? ""
        names = try c.decodeIfPresent(Tri.self, forKey: .names) ?? Tri()
        health = try c.decodeIfPresent(String.self, forKey: .health) ?? "unknown"
        answer = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
        followUps = try c.decodeIfPresent([String].self, forKey: .followUps) ?? []
        browseSection = try c.decodeIfPresent(String.self, forKey: .browseSection) ?? ""
        browseCategory = try c.decodeIfPresent(String.self, forKey: .browseCategory) ?? ""
        browseOccasion = try c.decodeIfPresent(String.self, forKey: .browseOccasion) ?? ""
    }
}

/// One line of the chat as sent to the function.
struct ChatTurn {
    let fromUser: Bool
    let text: String
}

enum AssistantError: Error {
    case notConfigured, dailyLimit, photoLimit, network, failed

    var key: String {
        switch self {
        case .notConfigured: return "ai_unavailable"
        case .dailyLimit: return "ai_limit"
        case .photoLimit: return "ai_photo_limit"
        case .network: return "err_network"
        case .failed: return "err_generic"
        }
    }
}

enum AssistantService {
    private struct Turn: Encodable {
        let role: String
        let text: String
    }

    private struct Body: Encodable {
        let language: String
        let messages: [Turn]
        let imageBase64: String?
        let mediaType: String?

        enum CodingKeys: String, CodingKey {
            case language, messages
            case imageBase64 = "image_base64"
            case mediaType = "media_type"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(language, forKey: .language)
            try c.encode(messages, forKey: .messages)
            try c.encodeIfPresent(imageBase64, forKey: .imageBase64)
            try c.encodeIfPresent(mediaType, forKey: .mediaType)
        }
    }

    private struct ErrorBody: Decodable { let error: String? }

    /// Sends the conversation (and the photo of the newest message, if any) to the plant-assistant edge function.
    /// `language` is the app language code (en / ar / ckb); the reply comes back in it.
    static func ask(turns: [ChatTurn], jpeg: Data?, language: String) async throws -> AssistantReply {
        guard let token = try? await supabase.auth.session.accessToken else { throw AssistantError.failed }

        var request = URLRequest(url: Config.supabaseURL.appendingPathComponent("functions/v1/plant-assistant"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(
            Body(
                language: language,
                messages: turns.map { Turn(role: $0.fromUser ? "user" : "assistant", text: $0.text) },
                imageBase64: jpeg?.base64EncodedString(),
                mediaType: jpeg == nil ? nil : "image/jpeg"
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AssistantError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(code) {
            guard let reply = try? JSONDecoder().decode(AssistantReply.self, from: data) else { throw AssistantError.failed }
            return reply
        }
        let errorCode = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        if errorCode == "ai_not_configured" || code == 404 { throw AssistantError.notConfigured }
        if errorCode == "daily_limit" { throw AssistantError.dailyLimit }
        if errorCode == "photo_limit" { throw AssistantError.photoLimit }
        throw AssistantError.failed
    }
}

/// How close a shop is to the customer: same city first, then shops that deliver there, then the rest.
enum ShopReach: Int, CaseIterable {
    case sameCity, delivers, otherCity
}

/// A shop listing that sells the plant the assistant talked about.
struct ShopMatch: Identifiable {
    let listing: Listing
    let reach: ShopReach
    let exact: Bool
    var id: String { listing.id }
}

/// Finds the in-stock listings that match the plant in `reply`: an exact match (same species or a name that
/// matches in any language) ranks above a listing that only has the same plant type. Results are ordered by
/// how close the shop is to `city`, then exact before similar, then cheapest first.
func findShops(reply: AssistantReply, listings: [Listing], city: String) -> [ShopMatch] {
    guard reply.identified else { return [] }
    let wantedNames = [reply.names.en, reply.names.ar, reply.names.ckb, reply.scientificName]
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { $0.count >= 3 }
    let genusWord = reply.scientificName.trimmingCharacters(in: .whitespaces).lowercased()
        .split(separator: " ").first.map(String.init) ?? ""
    let genus: String? = genusWord.count >= 4 ? genusWord : nil

    func isExact(_ listing: Listing) -> Bool {
        var have = listing.name.values.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { $0.count >= 3 }
        let scientific = (listing.scientificName ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if scientific.count >= 3 { have.append(scientific) }
        for wanted in wantedNames {
            for candidate in have where candidate == wanted || candidate.contains(wanted) || wanted.contains(candidate) {
                return true
            }
        }
        let listingGenus = scientific.split(separator: " ").first.map(String.init)
        return genus != nil && listingGenus == genus
    }

    var matches: [ShopMatch] = []
    for listing in listings where listing.inStock {
        let exact = isExact(listing)
        let sameType = reply.plantKey != "Other" && listing.plantKey == reply.plantKey
        if !exact && !sameType { continue }
        let reach: ShopReach
        if listing.sellers?.city == city {
            reach = .sameCity
        } else if listing.delivers(to: city) {
            reach = .delivers
        } else {
            reach = .otherCity
        }
        matches.append(ShopMatch(listing: listing, reach: reach, exact: exact))
    }
    return matches.sorted { a, b in
        if a.reach.rawValue != b.reach.rawValue { return a.reach.rawValue < b.reach.rawValue }
        if a.exact != b.exact { return a.exact }
        return a.listing.priceIqd < b.listing.priceIqd
    }
}
