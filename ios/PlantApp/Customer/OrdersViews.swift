import SwiftUI

struct OrdersTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.t("orders_title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if model.ordersLoading && model.orders.isEmpty {
                ProgressView().tint(Theme.green).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.ordersFailed && model.orders.isEmpty {
                MessageState(emoji: "📡", title: lang.t("orders_load_failed")) { model.loadOrders() }
            } else if model.orders.isEmpty {
                MessageState(emoji: "📦", title: lang.t("orders_empty"), detail: lang.t("orders_empty_hint"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.orders) { order in
                            OrderCard(order: order) { model.openOrder(order.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .refreshable { model.loadOrders() }
            }
        }
        .background(AppBackground())
    }
}

private struct OrderCard: View {
    @EnvironmentObject var lang: LanguageStore
    let order: Order
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(order.sellerName)
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
                    Text(String(order.createdAt.prefix(10)))
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
            .card()
        }
        .buttonStyle(FullTapStyle())
    }
}

struct OrderDetailView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel
    let order: Order

    @State private var askingChange = false
    @State private var changeNote = ""
    @State private var confirmCancel = false

    var body: some View {
        let status = order.statusEnum
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Split into Groups: this Mac's Xcode 14.2 (iOS 16.2 SDK) has the
                // pre-variadic-generics ViewBuilder, capped at 10 children per block.
                Group {
                    BackButton { model.closeOverlay() }
                        .padding(.vertical, 8)

                    Text(lang.t("order_number", order.shortId))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text(order.sellerName).foregroundStyle(Theme.muted)
                        .padding(.bottom, 20)

                    // The shop's photo of the prepared order, waiting for the customer's answer
                    if status == .photoSent {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("review_title"))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.greenDark)
                            Text(lang.t("review_body"))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                            Text(lang.t("review_timeout_note"))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                            if let path = order.preparationPhotoPath {
                                SignedImage(path: path)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button {
                                model.reviewPhoto(orderId: order.id, approve: true, note: nil)
                            } label: {
                                BusyLabel(title: lang.t("review_approve"), busy: model.reviewBusy)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(model.reviewBusy)
                            Button(lang.t("review_change")) { askingChange = true }
                                .buttonStyle(PrimaryButtonStyle(filled: false))
                                .disabled(model.reviewBusy)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.greenSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.bottom, 20)
                    }

                    if status == .preparing, let request = order.changeRequest, !request.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.t("review_you_asked"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(hex: 0x8A5A00))
                            Text(request)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amberSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 20)
                    }

                    // Timeline
                    if status == .cancelled {
                        VStack(alignment: .leading, spacing: 6) {
                            StatusChip(status: status)
                            if let reason = order.cancelReason {
                                Text(lang.t("order_cancelled_reason", lang.t(cancelReasonKey(reason))))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    } else {
                        let reached = order.timeline.firstIndex(of: status) ?? 0
                        ForEach(Array(order.timeline.enumerated()), id: \.offset) { index, step in
                            TimelineRow(
                                label: lang.t(step.labelKey),
                                done: index <= reached,
                                current: index == reached,
                                last: index == order.timeline.count - 1
                            )
                        }
                    }

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
                        TotalRow(label: lang.t("cart_total"), value: lang.price(order.totalIqd), bold: true)
                            .padding(.top, 8)
                    }
                }

                Group {
                    if status == .placed {
                        Button(lang.t("cancel_my_order")) { confirmCancel = true }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.error, filled: false))
                            .disabled(model.reviewBusy)
                            .padding(.top, 20)
                    }
                    if status == .delivered {
                        RateOrderSection(orderId: order.id)
                            .padding(.top, 20)
                    }
                    if let phone = model.listings.first(where: { $0.sellerId == order.sellerId })?.sellers?.phone, !phone.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeading(text: lang.t("contact_title"))
                            ContactButtons(phone: phone, whatsappMessage: lang.t("contact_order_message", order.shortId))
                        }
                    }
                    SectionHeading(text: lang.t("checkout_delivery"))
                    if order.isGift {
                        Text(lang.t("order_gift_for", order.recipientName ?? ""))
                            .font(.system(size: 16, weight: .semibold))
                        if let phone = order.recipientPhone { Text(phone).foregroundStyle(Theme.muted) }
                        if let giftNote = order.giftNote, !giftNote.isEmpty {
                            Text("“\(giftNote)”").padding(.top, 6)
                        }
                        Spacer().frame(height: 6)
                    }
                    Text(lang.addressText(city: order.city, district: order.district, neighborhood: order.neighborhood, street: order.address, landmark: order.landmark))
                    if !order.addressNotes.isEmpty { Text(order.addressNotes).foregroundStyle(Theme.muted) }
                    if let date = order.deliveryDate {
                        Text("\(date)  ·  \(lang.t(windowLabelKey(order.deliveryWindow)))")
                            .foregroundStyle(Theme.muted)
                    }

                    SectionHeading(text: lang.t("checkout_payment"))
                    Text(lang.t("pay_cod"))
                        .padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 20)
        }
        .alert(lang.t("review_change"), isPresented: $askingChange) {
            TextField(lang.t("review_change_hint"), text: $changeNote)
            Button(lang.t("review_change_send")) {
                let note = String(changeNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
                changeNote = ""
                if !note.isEmpty { model.reviewPhoto(orderId: order.id, approve: false, note: note) }
            }
            Button(lang.t("action_cancel"), role: .cancel) { changeNote = "" }
        }
        .alert(lang.t("cancel_confirm_title"), isPresented: $confirmCancel) {
            Button(lang.t("cancel_confirm_yes"), role: .destructive) { model.cancelOrder(order.id) }
            Button(lang.t("cancel_confirm_no"), role: .cancel) { }
        } message: {
            Text(lang.t("cancel_confirm_body"))
        }
    }
}

struct OrderPlacedView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: CustomerModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Theme.green)
                .clipShape(Circle())
            Text(lang.t("placed_title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.greenDark)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            Text(lang.t("placed_body"))
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Button(lang.t("placed_view_orders")) { model.finishPlaced() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 32)
            Button(lang.t("placed_keep_shopping")) { model.closeOverlay() }
                .buttonStyle(PrimaryButtonStyle(filled: false))
                .padding(.top, 10)
            Spacer()
        }
        .padding(28)
    }
}
