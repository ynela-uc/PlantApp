import SwiftUI

enum CustomerTab: Hashable { case browse, assistant, cart, orders, profile }

/// Full-screen pages shown on top of the tabs.
enum Overlay: Equatable {
    case detail(String)
    case checkout
    case orderDetail(String)
    case placed(Int)
}

enum CheckoutError: Equatable {
    case notDeliverable([String])
    case network
    case generic
}

struct CartEntry: Identifiable {
    let listing: Listing
    let qty: Int
    var id: String { listing.id }
}

@MainActor
final class CustomerModel: ObservableObject {
    let profile: Profile

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
    @Published var cart: [String: Int] = [:]
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

    var cartCount: Int { cart.values.reduce(0, +) }

    /// Cart contents as (listing, quantity), skipping listings that no longer exist.
    var cartLines: [CartEntry] {
        cart.compactMap { id, qty in
            guard let listing = listings.first(where: { $0.id == id }) else { return nil }
            return CartEntry(listing: listing, qty: qty)
        }
        .sorted { $0.listing.id < $1.listing.id }
    }

    var cartTotal: Int { cartLines.reduce(0) { $0 + $1.listing.priceIqd * $1.qty } }

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
    func openCheckout() { checkoutError = nil; withAnimation(Theme.slide) { overlay = .checkout } }
    func openOrder(_ id: String) { withAnimation(Theme.slide) { overlay = .orderDetail(id) } }
    func closeOverlay() { withAnimation(Theme.slide) { overlay = nil } }

    /// Leaves the "order placed" page and shows the orders tab.
    func finishPlaced() { withAnimation(Theme.slide) { overlay = nil; tab = .orders } }

    func changeQuantity(_ listingId: String, _ delta: Int) {
        let next = (cart[listingId] ?? 0) + delta
        if next <= 0 { cart.removeValue(forKey: listingId) } else { cart[listingId] = next }
    }

    // MARK: Checkout

    /// Creates one order per shop in the cart (cash on delivery).
    func placeOrders(_ form: CheckoutForm) {
        let lines = cartLines
        if lines.isEmpty { return }

        var blocked: [String] = []
        for line in lines where !line.listing.delivers(to: form.city) {
            if let name = line.listing.sellers?.name, !blocked.contains(name) { blocked.append(name) }
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
            let groups = Dictionary(grouping: lines, by: { $0.listing.sellerId })
            for (sellerId, group) in groups {
                let items = group.map {
                    OrderItem(listingId: $0.listing.id, name: $0.listing.name, qty: $0.qty, unitPriceIqd: $0.listing.priceIqd)
                }
                let gift = form.isGift
                func optional(_ text: String) -> String? {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return gift && !trimmed.isEmpty ? trimmed : nil
                }
                let order = NewOrder(
                    buyerId: profile.id,
                    sellerId: sellerId,
                    sellerName: group.first?.listing.sellers?.name ?? "",
                    items: items,
                    city: form.city,
                    address: form.address,
                    totalIqd: items.reduce(0) { $0 + $1.qty * $1.unitPriceIqd },
                    buyerName: profile.fullName,
                    buyerPhone: profile.phone,
                    isGift: gift,
                    recipientName: optional(form.recipientName),
                    recipientPhone: optional(form.recipientPhone),
                    giftNote: optional(form.giftNote),
                    deliveryDate: form.deliveryDate,
                    deliveryWindow: form.window
                )
                do {
                    try await OrdersService.create(order)
                    for line in group { cart.removeValue(forKey: line.listing.id) }
                    created += 1
                } catch {
                    failure = (error is URLError) ? .network : .generic
                    break
                }
            }
            if created > 0 { loadOrders() }
            placing = false
            checkoutError = failure
            if failure == nil { withAnimation(Theme.slide) { overlay = .placed(created) } }
        }
    }
}
