import SwiftUI

/// The signed-in customer experience: browse, cart, orders and profile tabs, plus full-screen pages on top.
struct CustomerRoot: View {
    @EnvironmentObject var lang: LanguageStore
    @StateObject private var model: CustomerModel
    @StateObject private var assistant = AssistantModel()
    let profile: Profile

    init(profile: Profile) {
        self.profile = profile
        _model = StateObject(wrappedValue: CustomerModel(profile: profile))
    }

    var body: some View {
        ZStack {
            TabView(selection: Binding(get: { model.tab }, set: { model.setTab($0) })) {
                BrowseView(profile: profile)
                    .tabItem { Label(lang.t("nav_browse"), systemImage: "leaf") }
                    .tag(CustomerTab.browse)
                AssistantView()
                    .tabItem { Label(lang.t("nav_ai"), systemImage: "sparkles") }
                    .tag(CustomerTab.assistant)
                CartView()
                    .tabItem { Label(lang.t("nav_cart"), systemImage: "cart") }
                    .badge(model.cartCount)
                    .tag(CustomerTab.cart)
                OrdersTab()
                    .tabItem { Label(lang.t("nav_orders"), systemImage: "shippingbox") }
                    .tag(CustomerTab.orders)
                ProfileTab(profile: profile)
                    .tabItem { Label(lang.t("nav_profile"), systemImage: "person") }
                    .tag(CustomerTab.profile)
            }

            if let overlay = model.overlay {
                overlayView(overlay)
                    .background(Theme.background.ignoresSafeArea())
                    .transition(.opacity)
            }
        }
        .environmentObject(model)
        .environmentObject(assistant)
    }

    @ViewBuilder
    private func overlayView(_ overlay: Overlay) -> some View {
        switch overlay {
        case .detail(let id):
            if let listing = model.listing(id) {
                ListingDetailView(listing: listing)
            }
        case .checkout:
            CheckoutView(profile: profile)
        case .orderDetail(let id):
            if let order = model.order(id) {
                OrderDetailView(order: order)
            }
        case .placed:
            OrderPlacedView()
        }
    }
}
