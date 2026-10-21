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
        .background(AppBackground())
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
                Text(order.items.map { $0.label(lang.localized($0.name)) }.joined(separator: ", "))
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
    @State private var showReasons = false
    /// Which list of reasons the dialog shows: "shop" (decline / cancel) or "failed" (could not deliver).
    @State private var reasonKind = "shop"

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
                    if status == .placed {
                        Text(lang.t("cancel_no_phone_yet"))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    } else if !order.buyerPhone.isEmpty {
                        callRow(order.buyerPhone)
                    }

                    // Items
                    SectionHeading(text: lang.t("order_items"))
                    ForEach(Array(order.items.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.label(lang.localized(item.name)))
                            Spacer()
                            if item.unitPriceIqd > 0 { Text(lang.price(item.unitPriceIqd * item.qty)) }
                        }
                        .padding(.vertical, 3)
                    }
                    if order.deliveryFeeIqd > 0 {
                        HStack {
                            Text(lang.t("delivery_fee_label")).foregroundStyle(Theme.muted)
                            Spacer()
                            Text(lang.price(order.deliveryFeeIqd))
                        }
                        .padding(.top, 6)
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
                        if status != .placed, let phone = order.recipientPhone, !phone.isEmpty { callRow(phone) }
                        if let note = order.giftNote, !note.isEmpty {
                            Text("“\(note)”").padding(.top, 6)
                        }
                        Spacer().frame(height: 6)
                    }
                    if status == .placed {
                        Text(lang.areaText(city: order.city, district: order.district))
                        Text(lang.t("address_after_accept")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    } else {
                        Text(lang.addressText(city: order.city, district: order.district, neighborhood: order.neighborhood, street: order.address, landmark: order.landmark))
                        if !order.addressNotes.isEmpty { Text(order.addressNotes).foregroundStyle(Theme.muted) }
                    }
                    if let date = order.deliveryDate {
                        Text("\(date)  ·  \(lang.t(windowLabelKey(order.deliveryWindow)))")
                            .foregroundStyle(Theme.muted)
                    }

                    // Photo
                    if let path = order.preparationPhotoPath, !path.isEmpty {
                        SectionHeading(text: lang.t("seller_photo_sent"))
                        SignedImage(path: path)
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
                        let reached = order.timeline.firstIndex(of: status) ?? 0
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(order.timeline.enumerated()), id: \.offset) { index, step in
                                TimelineRow(
                                    label: lang.t(step.labelKey),
                                    done: index <= reached,
                                    current: index == reached,
                                    last: index == order.timeline.count - 1
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
        .confirmationDialog(lang.t("reason_title"), isPresented: $showReasons, titleVisibility: .visible) {
            ForEach(reasonKind == "failed" ? failedDeliveryReasons : shopCancelReasons, id: \.self) { key in
                Button(lang.t(cancelReasonKey(key))) { model.changeStatus(order.id, .cancelled, reason: key) }
            }
            Button(lang.t("action_cancel"), role: .cancel) { }
        }
    }

    @ViewBuilder
    private func actions(status: OrderStatus, busy: Bool) -> some View {
        switch status {
        case .placed:
            actionButton("act_accept", busy: busy) { model.changeStatus(order.id, .preparing) }
            dangerButton("act_decline", busy: busy) { askReason("shop") }
        case .preparing where !order.photoRequired:
            actionButton("act_out_for_delivery", busy: busy) { model.changeStatus(order.id, .outForDelivery) }
            dangerButton("act_cancel_order", busy: busy) { askReason("shop") }
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
                dangerButton("act_cancel_order", busy: false) { askReason("shop") }
            }
        case .photoSent:
            if order.photoAnswerOverdue {
                Text(lang.t("seller_waiting_approval_timeout"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                actionButton("act_continue_no_answer", busy: busy) { model.changeStatus(order.id, .approved) }
            } else {
                Text(lang.t("seller_waiting_approval"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                dangerButton("act_cancel_order", busy: busy) { askReason("shop") }
            }
        case .approved:
            actionButton("act_out_for_delivery", busy: busy) { model.changeStatus(order.id, .outForDelivery) }
            dangerButton("act_cancel_order", busy: busy) { askReason("shop") }
        case .outForDelivery:
            actionButton("act_mark_delivered", busy: busy) { model.changeStatus(order.id, .delivered) }
            dangerButton("act_delivery_failed", busy: busy) { askReason("failed") }
        case .delivered, .cancelled:
            EmptyView()
        }
    }

    private func askReason(_ kind: String) {
        reasonKind = kind
        showReasons = true
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
            Button {
                let message = lang.t("contact_customer_message", order.shortId, order.sellerName)
                if let url = whatsappURL(phone: number, message: message) { openURL(url) }
            } label: {
                Text("💬  " + lang.t("contact_whatsapp"))
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
