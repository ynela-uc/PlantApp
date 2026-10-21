import SwiftUI

/// The signed-in seller experience: orders, plants and shop tabs, with full-screen pages on top.
struct SellerRoot: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: SellerModel
    let profile: Profile

    init(profile: Profile) {
        self.profile = profile
        _model = StateObject(wrappedValue: SellerModel(profile: profile))
    }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().tint(Theme.amber)
            } else if model.failed || model.shop == nil {
                VStack(spacing: 12) {
                    Text(lang.t("seller_load_failed"))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    Button(lang.t("retry")) { model.load() }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.amber))
                    Button(lang.t("action_signout")) { app.signOut() }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                }
                .padding(24)
            } else if let shop = model.shop {
                content(shop)
            }
        }
        .environmentObject(model)
        .tint(Theme.amber)
    }

    @ViewBuilder
    private func content(_ shop: Shop) -> some View {
        ZStack {
            VStack(spacing: 0) {
                if !shop.approved { PendingApprovalNotice() }
            TabView(selection: Binding(get: { model.tab }, set: { model.setTab($0) })) {
                SellerOrdersTab()
                    .tabItem { Label(lang.t("nav_seller_orders"), systemImage: "shippingbox") }
                    .badge(model.newOrderCount)
                    .tag(SellerTab.orders)
                SellerPlantsTab()
                    .tabItem { Label(lang.t("nav_my_plants"), systemImage: "leaf") }
                    .tag(SellerTab.plants)
                ShopTab(shop: shop, profile: profile)
                    .tabItem { Label(lang.t("nav_shop"), systemImage: "storefront") }
                    .tag(SellerTab.shop)
            }
            .glassTabBar()
            }

            if let editor = model.editor {
                PlantEditorView(editor: editor)
                    .background(AppBackground())
                    .edgeSwipeBack { model.closeEditor() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
            } else if let overlay = model.overlay {
                overlayView(overlay, shop: shop)
                    .background(AppBackground())
                    .edgeSwipeBack { model.closeOverlay() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
            }

            if !model.alertOrders.isEmpty {
                NewOrderBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        // While the app is on screen, look for new orders every 30 seconds (pushes cover the app being closed).
        .task {
            while !Task.isCancelled {
                model.refreshOrders()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.refreshOrders() }
        }
    }

    @ViewBuilder
    private func overlayView(_ overlay: SellerOverlay, shop: Shop) -> some View {
        switch overlay {
        case .orderDetail(let id):
            if let order = model.order(id) {
                SellerOrderDetailView(order: order)
            }
        case .shopEditor:
            ShopEditorView(shop: shop)
        }
    }
}

/// A banner on top of every seller screen when a new order arrives while the app is open.
/// Tap to open it; it fades after 12 seconds.
struct NewOrderBanner: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel

    var body: some View {
        let orders = model.alertOrders
        let name = orders.first.map { $0.buyerName.isEmpty ? "#" + $0.shortId : $0.buyerName } ?? ""
        VStack {
            Button {
                model.openAlert()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🛍  " + (orders.count > 1 ? lang.t("banner_new_orders", orders.count) : lang.t("banner_new_order", name)))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text(lang.t("banner_tap_to_open"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.amber)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amberSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber, lineWidth: 2))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            Spacer()
        }
        .task(id: orders.map { $0.id }.joined()) {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            if !Task.isCancelled { model.dismissAlert() }
        }
    }
}

/// Shown at the top while the shop waits for the owner of the app to approve it.
struct PendingApprovalNotice: View {
    @EnvironmentObject var lang: LanguageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lang.t("shop_pending_title"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.amber)
            Text(lang.t("shop_pending_body"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft)
    }
}
