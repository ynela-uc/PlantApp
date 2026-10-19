import SwiftUI

/// The signed-in seller experience: orders, plants and shop tabs, with full-screen pages on top.
struct SellerRoot: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
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
