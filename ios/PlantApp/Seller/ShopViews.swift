import SwiftUI

struct ShopTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var model: SellerModel
    let shop: Shop
    let profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(shop.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Text(lang.cityName(shop.city)).foregroundStyle(Theme.muted)
                    .padding(.bottom, 16)

                InfoRow(label: lang.t("field_phone"), value: shop.phone)
                InfoRow(
                    label: lang.t("shop_delivery"),
                    value: shop.isNationwide
                        ? lang.t("delivers_nationwide")
                        : (shop.deliversTo ?? []).map { lang.cityName($0) }.joined(separator: ", ")
                )
                if !shop.bio.isEmpty {
                    Text(shop.bio).padding(.top, 8)
                }
                Text(lang.t("shop_owner", profile.fullName))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)

                Button(lang.t("shop_edit")) { model.openShopEditor() }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                    .padding(.top, 16)

                LanguageSelector().padding(.top, 28)

                Button(lang.t("action_signout")) { app.signOut() }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                    .padding(.top, 28)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

struct ShopEditorView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel
    let shop: Shop

    @State private var name: String
    @State private var phone: String
    @State private var bio: String
    @State private var nationwide: Bool
    @State private var cities: Set<String>
    @State private var showError = false

    init(shop: Shop) {
        self.shop = shop
        _name = State(initialValue: shop.name)
        _phone = State(initialValue: shop.phone)
        _bio = State(initialValue: shop.bio)
        _nationwide = State(initialValue: shop.isNationwide)
        _cities = State(initialValue: Set(shop.deliversTo ?? []))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    BackButton(accent: Theme.amber) { model.closeOverlay() }
                        .padding(.vertical, 8)
                    Text(lang.t("shop_edit"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.bottom, 4)

                    AppField(title: lang.t("field_shop_name"), text: $name)
                    AppField(title: lang.t("field_phone"), text: $phone, keyboard: .phonePad)
                    AppField(title: lang.t("field_bio"), text: $bio, multiline: true)

                    Text(lang.t("shop_delivery"))
                        .font(.system(size: 14, weight: .bold))
                        .padding(.top, 8)
                    HStack(spacing: 10) {
                        ScopeChoice(label: lang.t("shop_scope_local"), selected: !nationwide) { nationwide = false }
                        ScopeChoice(label: lang.t("shop_scope_nationwide"), selected: nationwide) { nationwide = true }
                    }
                    if !nationwide {
                        Text(lang.t("shop_delivers_to"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                        FlowLayout(spacing: 8) {
                            ForEach(Cities.codes, id: \.self) { code in
                                Pill(label: lang.cityName(code), selected: cities.contains(code), accent: Theme.amber) {
                                    if cities.contains(code) { cities.remove(code) } else { cities.insert(code) }
                                    showError = false
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                if showError { ErrorText(message: lang.t("err_required")) }
                Button(action: save) {
                    BusyLabel(title: lang.t("action_save"), busy: model.savingShop)
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.amber))
                .disabled(model.savingShop)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.shadow(color: .black.opacity(0.08), radius: 6, y: -2))
        }
    }

    private func save() {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        if blank(name) || blank(phone) || (!nationwide && cities.isEmpty) {
            showError = true
            return
        }
        showError = false
        model.saveShop(
            ShopUpdate(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                deliveryScope: nationwide ? "nationwide" : "local",
                deliversTo: nationwide ? nil : Cities.codes.filter { cities.contains($0) }
            )
        )
    }
}

private struct ScopeChoice: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color.white : Color(hex: 0x333333))
                .background(selected ? Theme.amber : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.amber : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
