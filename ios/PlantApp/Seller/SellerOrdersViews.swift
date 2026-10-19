import SwiftUI

struct SellerOrdersTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("seller_orders_title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    if let shop = model.shop {
                        Text(shop.name).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                Button { model.refreshOrders() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if model.newOrderCount > 0 {
                Text(lang.t("seller_new_orders", model.newOrderCount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            if model.orders.isEmpty {
                MessageState(emoji: "📦", title: lang.t("seller_orders_empty"), detail: lang.t("seller_orders_empty_hint"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.orders) { order in
                            SellerOrderCard(order: order) { model.openOrder(order.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { model.refreshOrders() }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct SellerOrderCard: View {
    @EnvironmentObject var lang: LanguageStore
    let order: Order
    let action: () -> Void

    var body: some View {
        let needsAction = order.statusEnum == .placed || order.statusEnum == .approved
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(order.buyerName.isEmpty ? "#" + order.shortId : order.buyerName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Spacer()
                    StatusChip(status: order.statusEnum)
                }
                Text(order.items.map { "\(lang.localized($0.name)) × \($0.qty)" }.joined(separator: ", "))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text("\(lang.cityName(order.city))  ·  \(String(order.createdAt.prefix(10)))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    if order.totalIqd > 0 {
                        Text(lang.price(order.totalIqd))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(needsAction ? Theme.amber : Theme.border, lineWidth: needsAction ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SellerOrderDetailView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel
    @Environment(\.openURL) private var openURL
    let order: Order

    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        let status = order.statusEnum
        let busy = model.busyOrderId == order.id
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Split into Groups: this Mac's Xcode 14.2 (iOS 16.2 SDK) has the
                // pre-variadic-generics ViewBuilder, capped at 10 children per block.
                Group {
                    BackButton(accent: Theme.amber) { model.closeOverlay() }
                        .padding(.vertical, 8)

                    Text(lang.t("order_number", order.shortId))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    StatusChip(status: status).padding(.top, 6)

                    // Customer
                    SectionHeading(text: lang.t("seller_customer"))
                    Text(order.buyerName.isEmpty ? "—" : order.buyerName)
                        .font(.system(size: 16, weight: .semibold))
                    if !order.buyerPhone.isEmpty { callRow(order.buyerPhone) }

                    // Items
                    SectionHeading(text: lang.t("order_items"))
                    ForEach(Array(order.items.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text("\(lang.localized(item.name)) × \(item.qty)")
                            Spacer()
                            if item.unitPriceIqd > 0 { Text(lang.price(item.unitPriceIqd * item.qty)) }
                        }
                        .padding(.vertical, 3)
                    }
                    if order.totalIqd > 0 {
                        Text(lang.t("seller_collect", lang.price(order.totalIqd)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.amber)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.amberSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)
                    }
                }

                Group {
                    // Delivery
                    SectionHeading(text: lang.t("checkout_delivery"))
                    if order.isGift {
                        Text(lang.t("order_gift_for", order.recipientName ?? ""))
                            .font(.system(size: 16, weight: .semibold))
                        if let phone = order.recipientPhone, !phone.isEmpty { callRow(phone) }
                        if let note = order.giftNote, !note.isEmpty {
                            Text("“\(note)”").padding(.top, 6)
                        }
                        Spacer().frame(height: 6)
                    }
                    Text("\(lang.cityName(order.city)), \(order.address)")
                    if let date = order.deliveryDate {
                        Text("\(date)  ·  \(lang.t(windowLabelKey(order.deliveryWindow)))")
                            .foregroundStyle(Theme.muted)
                    }

                    // Photo
                    if let path = order.preparationPhotoPath, !path.isEmpty {
                        SectionHeading(text: lang.t("seller_photo_sent"))
                        SignedImage(path: path)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // What the customer asked to change
                    if status == .preparing, let request = order.changeRequest, !request.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.t("seller_change_requested"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.error)
                            Text(request)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.errorSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 16)
                    }

                    // Progress
                    if status != .cancelled {
                        let reached = OrderStatus.timeline.firstIndex(of: status) ?? 0
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(OrderStatus.timeline.enumerated()), id: \.offset) { index, step in
                                TimelineRow(
                                    label: lang.t(step.labelKey),
                                    done: index <= reached,
                                    current: index == reached,
                                    last: index == OrderStatus.timeline.count - 1
                                )
                            }
                        }
                        .padding(.top, 24)
                    }

                    // Actions
                    VStack(alignment: .leading, spacing: 8) {
                        if model.actionFailed {
                            Text(lang.t("seller_action_failed")).foregroundStyle(Theme.error)
                        }
                        actions(status: status, busy: busy)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 20)
        }
        .photoSheets(camera: $showCamera, library: $showLibrary) { data in
            model.sendPreparationPhoto(order.id, raw: data)
        }
    }

    @ViewBuilder
    private func actions(status: OrderStatus, busy: Bool) -> some View {
        switch status {
        case .placed:
            actionButton("act_accept", busy: busy) { model.changeStatus(order.id, .preparing) }
            dangerButton("act_decline", busy: busy) { model.changeStatus(order.id, .cancelled) }
        case .preparing:
            Text(lang.t("photo_prompt_title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.greenDark)
            Text(lang.t("photo_prompt_body")).foregroundStyle(Theme.muted)
            if busy {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.amber)
                    Text(lang.t("photo_uploading"))
                }
                .padding(.top, 6)
            } else {
                actionButton("photo_take", busy: false) { openCamera(camera: $showCamera, library: $showLibrary) }
                    .padding(.top, 6)
                Button(lang.t("photo_pick")) { showLibrary = true }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                dangerButton("act_cancel_order", busy: false) { model.changeStatus(order.id, .cancelled) }
            }
        case .photoSent:
            Text(lang.t("seller_waiting_approval"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.muted)
        case .approved:
            actionButton("act_out_for_delivery", busy: busy) { model.changeStatus(order.id, .outForDelivery) }
        case .outForDelivery:
            actionButton("act_mark_delivered", busy: busy) { model.changeStatus(order.id, .delivered) }
        case .delivered, .cancelled:
            EmptyView()
        }
    }

    private func callRow(_ number: String) -> some View {
        HStack {
            Text(number).foregroundStyle(Theme.muted)
            Spacer()
            Button {
                let digits = number.filter { $0.isNumber || $0 == "+" }
                if let url = URL(string: "tel:\(digits)") { openURL(url) }
            } label: {
                Text("📞  " + lang.t("seller_call"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
        }
    }

    private func actionButton(_ key: String, busy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BusyLabel(title: lang.t(key), busy: busy)
        }
        .buttonStyle(PrimaryButtonStyle(color: Theme.amber))
        .disabled(busy)
    }

    private func dangerButton(_ key: String, busy: Bool, action: @escaping () -> Void) -> some View {
        Button(lang.t(key), action: action)
            .buttonStyle(PrimaryButtonStyle(color: Theme.error, filled: false))
            .disabled(busy)
    }
}
