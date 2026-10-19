import SwiftUI

enum SellerTab: Hashable { case orders, plants, shop }

enum SellerOverlay: Equatable {
    case orderDetail(String)
    case shopEditor
}

/// The text fields of the plant editor that exist once per language.
enum EditorField { case name, description, water, light, fertilizer }

/// What happened the last time the AI ran, shown above the editor fields.
enum AiMessage {
    case filled, lowConfidence, notAPlant, notConfigured, limitReached, network, failed

    var key: String {
        switch self {
        case .filled: return "editor_ai_done"
        case .lowConfidence: return "editor_ai_low"
        case .notAPlant: return "editor_ai_not_plant"
        case .notConfigured: return "editor_ai_not_configured"
        case .limitReached: return "editor_ai_limit"
        case .network: return "err_network"
        case .failed: return "editor_ai_failed"
        }
    }
}

enum EditorError { case required, saveFailed }

/// Everything in the add/edit plant page. Texts are maps keyed by language code (en / ar / ckb).
struct EditorState {
    var listingId: String?
    var photoData: Data?
    var existingImagePath: String?
    var plantKey: String?
    var name: [String: String] = [:]
    var scientificName = ""
    var description: [String: String] = [:]
    var water: [String: String] = [:]
    var light: [String: String] = [:]
    var fertilizer: [String: String] = [:]
    var heightText = ""
    var priceText = ""
    var inStock = true
    var aiGenerated = false
    var aiBusy = false
    var aiMessage: AiMessage?
    var saving = false
    var error: EditorError?
}

@MainActor
final class SellerModel: ObservableObject {
    let profile: Profile

    @Published var loading = true
    @Published var failed = false
    @Published var shop: Shop?
    @Published var listings: [Listing] = []
    @Published var orders: [Order] = []
    @Published var tab: SellerTab = .orders
    @Published var overlay: SellerOverlay?
    @Published var editor: EditorState?
    /// Order currently being updated (buttons show a spinner).
    @Published var busyOrderId: String?
    @Published var actionFailed = false
    @Published var savingShop = false

    init(profile: Profile) {
        self.profile = profile
        load()
    }

    var newOrderCount: Int { orders.filter { $0.statusEnum == .placed }.count }
    func order(_ id: String) -> Order? { orders.first { $0.id == id } }

    // MARK: Loading

    func load() {
        loading = true
        failed = false
        Task {
            do {
                guard let shop = try await SellerService.fetchShop(ownerId: profile.id) else {
                    loading = false
                    failed = true
                    return
                }
                let listings = try await SellerService.fetchListings(shopId: shop.id)
                let orders = try await SellerService.fetchOrders(shopId: shop.id)
                self.shop = shop
                self.listings = listings
                self.orders = orders
                loading = false
            } catch {
                loading = false
                failed = true
            }
        }
    }

    func refreshOrders() {
        Task { await reloadOrders() }
    }

    private func reloadOrders() async {
        guard let shop else { return }
        if let fresh = try? await SellerService.fetchOrders(shopId: shop.id) { orders = fresh }
    }

    private func reloadListings() async {
        guard let shop else { return }
        if let fresh = try? await SellerService.fetchListings(shopId: shop.id) { listings = fresh }
    }

    func setTab(_ next: SellerTab) {
        tab = next
        if next == .orders { refreshOrders() }
    }

    func openOrder(_ id: String) { actionFailed = false; overlay = .orderDetail(id) }
    func openShopEditor() { overlay = .shopEditor }
    func closeOverlay() { overlay = nil }

    // MARK: Orders

    func changeStatus(_ orderId: String, _ status: OrderStatus) {
        busyOrderId = orderId
        actionFailed = false
        Task {
            do {
                try await SellerService.setOrderStatus(orderId: orderId, status: status)
                await reloadOrders()
                busyOrderId = nil
            } catch {
                busyOrderId = nil
                actionFailed = true
            }
        }
    }

    /// Uploads the photo of the prepared order and asks the customer to approve it.
    func sendPreparationPhoto(_ orderId: String, raw: Data) {
        busyOrderId = orderId
        actionFailed = false
        Task {
            do {
                let jpeg = await Task.detached { ImageUtils.prepareJpeg(raw) }.value
                let path = try await SellerService.uploadOrderPhoto(orderId: orderId, jpeg: jpeg)
                try await SellerService.setOrderStatus(orderId: orderId, status: .photoSent, photoPath: path)
                await reloadOrders()
                busyOrderId = nil
            } catch {
                busyOrderId = nil
                actionFailed = true
            }
        }
    }

    // MARK: Plants

    func toggleStock(_ listing: Listing) {
        Task {
            do {
                try await SellerService.setInStock(id: listing.id, inStock: !listing.inStock)
                await reloadListings()
            } catch { }
        }
    }

    func deleteListing(_ id: String) {
        Task {
            do {
                try await SellerService.deleteListing(id: id)
                await reloadListings()
            } catch { }
        }
    }

    func newPlant() { editor = EditorState() }

    func editPlant(_ listing: Listing) {
        var state = EditorState()
        state.listingId = listing.id
        state.existingImagePath = listing.imagePath
        state.plantKey = listing.plantKey
        state.name = listing.name
        state.scientificName = listing.scientificName ?? ""
        state.description = listing.description
        state.water = listing.care["water"] ?? [:]
        state.light = listing.care["light"] ?? [:]
        state.fertilizer = listing.care["fertilizer"] ?? [:]
        state.heightText = listing.heightCm.map(String.init) ?? ""
        state.priceText = String(listing.priceIqd)
        state.inStock = listing.inStock
        state.aiGenerated = listing.aiGenerated
        editor = state
    }

    func closeEditor() { editor = nil }

    func text(_ field: EditorField, _ lang: String) -> String {
        guard let e = editor else { return "" }
        switch field {
        case .name: return e.name[lang] ?? ""
        case .description: return e.description[lang] ?? ""
        case .water: return e.water[lang] ?? ""
        case .light: return e.light[lang] ?? ""
        case .fertilizer: return e.fertilizer[lang] ?? ""
        }
    }

    func setText(_ field: EditorField, _ lang: String, _ value: String) {
        guard editor != nil else { return }
        switch field {
        case .name: editor?.name[lang] = value; editor?.error = nil
        case .description: editor?.description[lang] = value
        case .water: editor?.water[lang] = value
        case .light: editor?.light[lang] = value
        case .fertilizer: editor?.fertilizer[lang] = value
        }
    }

    func setScientificName(_ value: String) { editor?.scientificName = value }
    func setHeight(_ value: String) { editor?.heightText = String(value.filter(\.isNumber).prefix(3)) }
    func setPrice(_ value: String) { editor?.priceText = String(value.filter(\.isNumber).prefix(9)); editor?.error = nil }
    func setInStock(_ value: Bool) { editor?.inStock = value }

    /// A new photo was taken or picked. For a new plant the AI runs straight away.
    func onPlantPhoto(_ raw: Data, runAiNow: Bool) {
        Task {
            let jpeg = await Task.detached { ImageUtils.prepareJpeg(raw) }.value
            editor?.photoData = jpeg
            editor?.aiMessage = nil
            if runAiNow { runAi() }
        }
    }

    func runAi() {
        guard let photo = editor?.photoData else { return }
        editor?.aiBusy = true
        editor?.aiMessage = nil
        Task {
            do {
                let suggestion = try await AiService.identify(jpeg: photo)
                applySuggestion(suggestion)
            } catch let error as AppError {
                let message: AiMessage
                switch error {
                case .aiNotConfigured: message = .notConfigured
                case .aiLimitReached: message = .limitReached
                case .network: message = .network
                default: message = .failed
                }
                editor?.aiBusy = false
                editor?.aiMessage = message
            } catch {
                editor?.aiBusy = false
                editor?.aiMessage = .failed
            }
        }
    }

    private func applySuggestion(_ s: PlantSuggestion) {
        guard editor != nil else { return }
        editor?.aiBusy = false
        if !s.identified {
            editor?.aiMessage = .notAPlant
            return
        }
        editor?.aiGenerated = true
        editor?.aiMessage = s.confidence == "low" ? .lowConfidence : .filled
        editor?.plantKey = s.plantKey == "Other" ? nil : s.plantKey
        editor?.name = s.name.map
        editor?.scientificName = s.scientificName
        editor?.description = s.description.map
        editor?.water = s.care.water.map
        editor?.light = s.care.light.map
        editor?.fertilizer = s.care.fertilizer.map
        if s.heightCm > 0 { editor?.heightText = String(s.heightCm) }
    }

    func saveEditor() {
        guard let shop, let e = editor else { return }
        let price = Int(e.priceText)
        if !e.name.values.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) || (price ?? 0) <= 0 {
            editor?.error = .required
            return
        }
        editor?.saving = true
        editor?.error = nil
        Task {
            do {
                var imagePath = e.existingImagePath
                if let data = e.photoData {
                    imagePath = try await SellerService.uploadPlantPhoto(ownerId: profile.id, jpeg: data)
                }
                func clean(_ map: [String: String]) -> [String: String] {
                    map.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                }
                let name = clean(e.name)
                let description = clean(e.description)
                var care: [String: [String: String]] = [:]
                for (key, map) in [("water", e.water), ("light", e.light), ("fertilizer", e.fertilizer)] {
                    let cleaned = clean(map)
                    if !cleaned.isEmpty { care[key] = cleaned }
                }
                let height = Int(e.heightText).flatMap { $0 > 0 ? $0 : nil }
                let scientific = e.scientificName.trimmingCharacters(in: .whitespaces)
                let scientificName: String? = scientific.isEmpty ? nil : scientific

                if let id = e.listingId {
                    try await SellerService.updateListing(
                        id: id,
                        update: ListingUpdate(
                            plantKey: e.plantKey, name: name, scientificName: scientificName,
                            description: description, care: care, heightCm: height, priceIqd: price ?? 0,
                            imagePath: imagePath, inStock: e.inStock, aiGenerated: e.aiGenerated
                        )
                    )
                } else {
                    try await SellerService.createListing(
                        NewListing(
                            sellerId: shop.id, plantKey: e.plantKey, name: name, scientificName: scientificName,
                            description: description, care: care, heightCm: height, priceIqd: price ?? 0,
                            imagePath: imagePath, inStock: e.inStock, aiGenerated: e.aiGenerated
                        )
                    )
                }
                await reloadListings()
                editor = nil
            } catch {
                editor?.saving = false
                editor?.error = .saveFailed
            }
        }
    }

    // MARK: Shop

    func saveShop(_ update: ShopUpdate) {
        guard let shop else { return }
        savingShop = true
        Task {
            do {
                try await SellerService.updateShop(shopId: shop.id, update: update)
                if let fresh = try await SellerService.fetchShop(ownerId: profile.id) { self.shop = fresh }
                savingShop = false
                overlay = nil
            } catch {
                savingShop = false
            }
        }
    }
}
