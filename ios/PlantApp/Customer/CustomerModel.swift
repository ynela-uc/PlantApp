import SwiftUI

enum CustomerTab: Hashable { case browse, assistant, cart, orders, profile }

/// Full-screen pages shown on top of the tabs.
enum Overlay: Equatable {
    case detail(String)
    case shop(String)
    case checkout
    case orderDetail(String)
    case placed(Int)
}

enum CheckoutError: Equatable {
    case notDeliverable([String])
    case priceChanged
    case unavailable
    case network
    case generic
}

/// What is stored for one cart line: which product, the customer's option choices, how many.
struct CartItem {
    let listingId: String
    let options: [String: String]
    var qty: Int
}

/// Same product with different choices (blue vs black) is a different line.
func cartKey(_ listingId: String, _ options: [String: String]) -> String {
    listingId + options.keys.sorted().map { "|\($0)=\(options[$0] ?? "")" }.joined()
}

/// One line in the cart, with its product looked up.
struct CartLine: Identifiable {
    let key: String
    let listing: Listing
    let options: [String: String]
    let qty: Int
    var id: String { key }
    var total: Int { listing.priceIqd * qty }
}

/// The cart lines of one shop: they become one order and carry one delivery fee.
struct ShopGroup: Identifiable {
    let sellerId: String
    let shop: SellerInfo?
    let lines: [CartLine]
    let fee: Int
    var id: String { sellerId }
    var subtotal: Int { lines.reduce(0) { $0 + $1.total } }
    var total: Int { subtotal + fee }
}

@MainActor
final class CustomerModel: ObservableObject {
    /// The signed-in customer; replaced when they edit their profile.
    var profile: Profile

    @Published var loading = true
    @Published var failed = false
    @Published var listings: [Listing] = []
    @Published var city: String
    @Published var query = ""
    /// Home screen vs. browsing one section (flowers / plants / gifts), one category in it, or one occasion.
    @Published var section: String?
    @Published var category: String?
    @Published var occasion: String?
    /// The entry screen's "show everything": a plain product list with no section chosen.
    @Published var showAll = false
    /// False until the shopper picks what to look at on the entry screen; asked again at every app start.
    @Published var entered = false
    /// listing id -> quantity
    @Published var cart: [String: CartItem] = [:]
    @Published var tab: CustomerTab = .browse
    @Published var overlay: Overlay?
    @Published var orders: [Order] = []
    @Published var ordersLoading = false
    @Published var ordersFailed = false
    @Published var placing = false
    @Published var checkoutError: CheckoutError?
    /// True while the customer's answer to a preparation photo is being saved.
    @Published var reviewBusy = false

    init(profile: Profile) {
        self.profile = profile
        self.city = profile.city.isEmpty ? "Baghdad" : profile.city
        load()
        loadOrders()
    }

    // MARK: Derived

    var cartCount: Int { cart.values.reduce(0) { $0 + $1.qty } }

    /// Cart contents in the order they were added, skipping listings that no longer exist.
    private(set) var cartOrder: [String] = []

    var cartLines: [CartLine] {
        cartOrder.compactMap { key in
            guard let item = cart[key], let listing = listings.first(where: { $0.id == item.listingId }) else { return nil }
            return CartLine(key: key, listing: listing, options: item.options, qty: item.qty)
        }
    }

    /// The cart split by shop, each with the delivery fee for `city`.
    func cartGroups(_ city: String) -> [ShopGroup] {
        var order: [String] = []
        var byShop: [String: [CartLine]] = [:]
        for line in cartLines {
            let id = line.listing.sellerId
            if byShop[id] == nil { order.append(id) }
            byShop[id, default: []].append(line)
        }
        return order.map { id in
            let lines = byShop[id] ?? []
            let shop = lines.first?.listing.sellers
            return ShopGroup(sellerId: id, shop: shop, lines: lines, fee: shop?.feeFor(city) ?? 0)
        }
    }

    /// Everything to pay in cash: items plus every shop's delivery fee.
    func grandTotal(_ city: String) -> Int { cartGroups(city).reduce(0) { $0 + $1.total } }

    func listing(_ id: String) -> Listing? { listings.first { $0.id == id } }
    func order(_ id: String) -> Order? { orders.first { $0.id == id } }

    /// Listings that can be delivered to the chosen city and are in stock.
    var deliverable: [Listing] { listings.filter { $0.inStock && $0.delivers(to: city) } }

    /// Deliverable listings matching the search text and the plant-type chip.
    /// True when no section, occasion or search is active: the screen shows the home page instead of a product list.
    var isHome: Bool {
        section == nil && occasion == nil && !showAll && query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Deliverable listings matching the section, category, occasion and search text.
    func visible(_ lang: LanguageStore) -> [Listing] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return deliverable.filter { listing in
            (section == nil || listing.section == section)
                && (category == nil || listing.category == category)
                && (occasion == nil || listing.occasions.contains(occasion ?? ""))
                && (q.isEmpty
                    || listing.name.values.contains { $0.lowercased().contains(q) }
                    || lang.localized(listing.name).lowercased().contains(q)
                    || (listing.sellers?.name.lowercased().contains(q) ?? false))
        }
    }

    // MARK: Loading

    func load() {
        loading = true
        failed = false
        Task {
            do {
                listings = try await ListingsService.fetchAll()
                loading = false
            } catch {
                loading = false
                failed = true
            }
        }
    }

    func loadOrders() {
        ordersLoading = true
        ordersFailed = false
        Task {
            do {
                orders = try await OrdersService.fetchMine(buyerId: profile.id)
                ordersLoading = false
            } catch {
                ordersLoading = false
                ordersFailed = true
            }
        }
    }

    /// Approve the shop's photo, or send the shop a change request.
    func reviewPhoto(orderId: String, approve: Bool, note: String?) {
        reviewBusy = true
        Task {
            do {
                try await OrdersService.reviewPhoto(orderId: orderId, approve: approve, note: note)
                loadOrders()
            } catch { }
            reviewBusy = false
        }
    }

    // MARK: Navigation and cart

    func setCity(_ code: String) { city = code; category = nil }

    /// Jump from the Smart Assistant to the products it suggested: a section (and category) or an occasion.
    func browse(section: String?, category: String?, occasion: String?) {
        let useSection = Catalog.section(section)?.key
        withAnimation(Theme.slide) {
            overlay = nil
            entered = true
            tab = .browse
            query = ""
            showAll = false
            self.section = useSection
            if let useSection, let found = Catalog.section(useSection), found.categories.contains(where: { $0.key == category }) {
                self.category = category
            } else {
                self.category = nil
            }
            self.occasion = (useSection == nil && Catalog.occasions.contains(where: { $0.key == occasion })) ? occasion : nil
        }
    }

    /// Entry screen answer: open this section or occasion (both nil = show everything) and show the app.
    func enter(section: String?, occasion: String?) {
        self.section = section
        self.occasion = occasion
        category = nil
        query = ""
        showAll = section == nil && occasion == nil
        tab = .browse
        withAnimation(Theme.slide) { entered = true }
    }

    /// Opens one section (or goes back to the home page with nil).
    func openSection(_ key: String?) {
        withAnimation(Theme.slide) {
            section = key
            category = nil
            occasion = nil
            query = ""
            showAll = false
        }
    }

    /// Opens everything for one occasion across all sections (or goes back home with nil).
    func openOccasion(_ key: String?) {
        withAnimation(Theme.slide) {
            occasion = key
            section = nil
            category = nil
            query = ""
            showAll = false
        }
    }

    func setTab(_ next: CustomerTab) {
        tab = next
        if next == .orders { loadOrders() }
    }

    func openListing(_ id: String) { withAnimation(Theme.slide) { overlay = .detail(id) } }
    func openShop(_ sellerId: String) { withAnimation(Theme.slide) { overlay = .shop(sellerId) } }
    func openCheckout() { checkoutError = nil; withAnimation(Theme.slide) { overlay = .checkout } }
    func openOrder(_ id: String) { withAnimation(Theme.slide) { overlay = .orderDetail(id) } }
    func closeOverlay() { withAnimation(Theme.slide) { overlay = nil } }

    /// Leaves the "order placed" page and shows the orders tab.
    func finishPlaced() { withAnimation(Theme.slide) { overlay = nil; tab = .orders } }

    func addToCart(_ listingId: String, options: [String: String]) {
        let key = cartKey(listingId, options)
        if var item = cart[key] {
            item.qty += 1
            cart[key] = item
        } else {
            cart[key] = CartItem(listingId: listingId, options: options, qty: 1)
            cartOrder.append(key)
        }
    }

    func changeQuantity(_ key: String, _ delta: Int) {
        guard var item = cart[key] else { return }
        item.qty += delta
        if item.qty <= 0 {
            cart.removeValue(forKey: key)
            cartOrder.removeAll { $0 == key }
        } else {
            cart[key] = item
        }
    }

    // MARK: Checkout

    /// Creates one order per shop in the cart (cash on delivery); each carries that shop's delivery fee.
    func placeOrders(_ form: CheckoutForm) {
        let groups = cartGroups(form.city)
        if groups.isEmpty { return }

        var blocked: [String] = []
        for group in groups where group.lines.contains(where: { !$0.listing.delivers(to: form.city) }) {
            if let name = group.shop?.name, !blocked.contains(name) { blocked.append(name) }
        }
        if !blocked.isEmpty {
            checkoutError = .notDeliverable(blocked)
            return
        }

        placing = true
        checkoutError = nil
        Task {
            var created = 0
            var failure: CheckoutError?
            for group in groups {
                let items = group.lines.map {
                    OrderItem(listingId: $0.listing.id, name: $0.listing.name, qty: $0.qty, unitPriceIqd: $0.listing.priceIqd, options: $0.options)
                }
                let gift = form.isGift
                func optional(_ text: String) -> String? {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return gift && !trimmed.isEmpty ? trimmed : nil
                }
                let order = NewOrder(
                    buyerId: profile.id,
                    sellerId: group.sellerId,
                    sellerName: group.shop?.name ?? "",
                    items: items,
                    city: form.city,
                    address: form.address,
                    totalIqd: group.total,
                    deliveryFeeIqd: group.fee,
                    buyerName: profile.fullName,
                    buyerPhone: profile.phone,
                    isGift: gift,
                    recipientName: optional(form.recipientName),
                    recipientPhone: optional(form.recipientPhone),
                    giftNote: optional(form.giftNote),
                    deliveryDate: form.deliveryDate,
                    deliveryWindow: form.window,
                    photoRequested: form.photoRequested
                )
                do {
                    try await OrdersService.create(order)
                    for line in group.lines {
                        cart.removeValue(forKey: line.key)
                        cartOrder.removeAll { $0 == line.key }
                    }
                    created += 1
                } catch {
                    let reason = error.localizedDescription
                    if error is URLError {
                        failure = .network
                    } else if reason.contains("price_changed") {
                        failure = .priceChanged
                    } else if reason.contains("unavailable") {
                        failure = .unavailable
                    } else {
                        failure = .generic
                    }
                    break
                }
            }
            if created > 0 { loadOrders() }
            // Prices or stock changed: reload the products so the cart shows what the shop charges now.
            if failure == .priceChanged || failure == .unavailable { load() }
            placing = false
            checkoutError = failure
            if failure == nil { withAnimation(Theme.slide) { overlay = .placed(created) } }
        }
    }
}
