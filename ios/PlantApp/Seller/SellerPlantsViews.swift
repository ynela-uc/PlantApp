import SwiftUI

struct SellerPlantsTab: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel
    @State private var pendingDelete: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.t("plants_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.greenDark)
                Spacer()
                Button { model.newPlant() } label: {
                    Text("＋  " + lang.t("plants_add"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.amber)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if model.listings.isEmpty {
                MessageState(emoji: "🪴", title: lang.t("plants_empty"), detail: lang.t("plants_empty_hint"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.listings) { listing in
                            PlantRow(listing: listing, onDelete: { pendingDelete = listing.id })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(AppBackground())
        .alert(
            lang.t("plant_delete_title"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button(lang.t("action_delete"), role: .destructive) {
                if let id = pendingDelete { model.deleteListing(id) }
                pendingDelete = nil
            }
            Button(lang.t("action_cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(lang.t("plant_delete_text"))
        }
    }
}

private struct PlantRow: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel
    let listing: Listing
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { model.editPlant(listing) } label: {
                HStack(spacing: 12) {
                    PlantPicture(listing: listing, emojiSize: 30)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.localized(listing.name))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.greenDark)
                        Text(lang.price(listing.priceIqd))
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: Binding(get: { listing.inStock }, set: { _ in model.toggleStock(listing) }))
                    .labelsHidden()
                    .tint(Theme.green)
                Text(lang.t(listing.inStock ? "plant_in_stock" : "plant_out_of_stock"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(listing.inStock ? Theme.green : Theme.error)
            }
            Button(action: onDelete) {
                Image(systemName: "trash").foregroundStyle(Theme.error)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .card()
    }
}

struct PlantEditorView: View {
    @EnvironmentObject var lang: LanguageStore
    @EnvironmentObject var model: SellerModel
    let editor: EditorState

    @State private var showCamera = false
    @State private var showLibrary = false

    private var code: String { lang.language.rawValue }
    private var isPlant: Bool { editor.section == Catalog.plants }

    private func errorKey(_ error: EditorError) -> String {
        switch error {
        case .required: return "editor_error_required"
        case .categoryMissing: return "editor_error_category"
        case .saveFailed: return "editor_error_save"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackButton(accent: Theme.amber) { model.closeEditor() }
                        .padding(.vertical, 8)
                    Text(lang.t(editor.listingId == nil ? "editor_title_new" : "editor_title_edit"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.bottom, 16)

                    photoArea

                    HStack(spacing: 10) {
                        Button { openCamera(camera: $showCamera, library: $showLibrary) } label: {
                            Text("📷  " + lang.t("photo_take"))
                        }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.amber))
                        Button(lang.t("photo_pick")) { showLibrary = true }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                    }
                    .disabled(editor.aiBusy)
                    .padding(.top, 10)

                    Button { model.runAi() } label: {
                        Text("✨  " + lang.t("editor_ai_button"))
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.green))
                    .disabled(editor.photoData == nil || editor.aiBusy)
                    .padding(.top, 10)

                    if let message = editor.aiMessage {
                        let good = message == .filled
                        Text(lang.t(message.key))
                            .font(.system(size: 14))
                            .foregroundStyle(good ? Theme.greenDark : Color(hex: 0x8A5A00))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(good ? Theme.greenSoft : Theme.amberSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)
                    }

                    // Where the product is filed: section, category, occasions
                    PickerTitle(lang.t("field_section"))
                    FlowLayout(spacing: 8) {
                        ForEach(Catalog.sections) { entry in
                            Pill(label: "\(entry.emoji) \(lang.t("sec_" + entry.key))", selected: editor.section == entry.key, accent: Theme.amber) {
                                model.setSection(entry.key)
                            }
                        }
                    }
                    if let current = Catalog.section(editor.section) {
                        PickerTitle(lang.t("field_category"))
                        FlowLayout(spacing: 8) {
                            ForEach(current.categories) { category in
                                Pill(label: "\(category.emoji) \(lang.t("cat_" + category.key))", selected: editor.category == category.key, accent: Theme.amber) {
                                    model.setCategory(category.key)
                                }
                            }
                        }
                    }
                    PickerTitle(lang.t("field_occasions"))
                    FlowLayout(spacing: 8) {
                        ForEach(Catalog.occasions) { occasion in
                            Pill(label: "\(occasion.emoji) \(lang.t("occ_" + occasion.key))", selected: editor.occasions.contains(occasion.key), accent: Theme.amber) {
                                model.toggleOccasion(occasion.key)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        AppField(title: lang.t("field_plant_name"), text: textBinding(.name))
                        if isPlant {
                            AppField(title: lang.t("field_scientific"), text: Binding(get: { editor.scientificName }, set: { model.setScientificName($0) }), autocapitalize: false)
                        }
                        AppField(title: lang.t("field_description"), text: textBinding(.description), multiline: true)
                        if isPlant {
                            AppField(title: lang.t("field_water"), text: textBinding(.water), multiline: true)
                            AppField(title: lang.t("field_light"), text: textBinding(.light), multiline: true)
                            AppField(title: lang.t("field_fertilizer"), text: textBinding(.fertilizer), multiline: true)
                            AppField(title: lang.t("field_height"), text: Binding(get: { editor.heightText }, set: { model.setHeight($0) }), keyboard: .numberPad)
                        }
                        AppField(title: lang.t("field_price"), text: Binding(get: { editor.priceText }, set: { model.setPrice($0) }), keyboard: .numberPad)
                        AppField(
                            title: lang.t("field_old_price"),
                            text: Binding(get: { editor.oldPriceText }, set: { value in model.updateEditor { $0.oldPriceText = String(value.filter(\.isNumber).prefix(9)) } }),
                            keyboard: .numberPad
                        )
                        AppField(
                            title: lang.t("field_pieces"),
                            text: Binding(get: { editor.piecesText }, set: { value in model.updateEditor { $0.piecesText = String(value.filter(\.isNumber).prefix(3)) } }),
                            keyboard: .numberPad
                        )
                        AppField(
                            title: lang.t("field_collection"),
                            text: Binding(get: { editor.collection }, set: { value in model.updateEditor { $0.collection = String(value.prefix(40)) } })
                        )
                    }
                    .padding(.top, 20)

                    // Choices the customer makes (colour, scent, ...)
                    PickerTitle(lang.t("options_title"))
                    ForEach(Array(editor.options.enumerated()), id: \.offset) { index, draft in
                        VStack(spacing: 8) {
                            AppField(
                                title: lang.t("option_name_hint"),
                                text: Binding(get: { draft.name }, set: { value in model.updateEditor { if index < $0.options.count { $0.options[index].name = value } } })
                            )
                            AppField(
                                title: lang.t("option_values_hint"),
                                text: Binding(get: { draft.valuesText }, set: { value in model.updateEditor { if index < $0.options.count { $0.options[index].valuesText = value } } })
                            )
                            Button {
                                model.updateEditor { if index < $0.options.count { $0.options.remove(at: index) } }
                            } label: {
                                Text("🗑  " + lang.t("action_delete")).foregroundStyle(Theme.error)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 8)
                    }
                    if editor.options.count < 3 {
                        Button("＋  " + lang.t("option_add")) {
                            model.updateEditor { $0.options.append(OptionDraft()) }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.amber, filled: false))
                    }

                    Toggle(lang.t("plant_in_stock"), isOn: Binding(get: { editor.inStock }, set: { model.setInStock($0) }))
                        .font(.system(size: 16, weight: .semibold))
                        .tint(Theme.green)
                        .padding(.top, 12)

                    if editor.aiGenerated {
                        Text(lang.t("editor_ai_note"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 8)
                    }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                if let error = editor.error {
                    ErrorText(message: lang.t(errorKey(error)))
                }
                Button { model.saveEditor() } label: {
                    BusyLabel(title: lang.t("action_save"), busy: editor.saving)
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.amber))
                .disabled(editor.saving || editor.aiBusy)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBar()
        }
        .photoSheets(camera: $showCamera, library: $showLibrary) { data in
            model.onPlantPhoto(data, runAiNow: editor.listingId == nil)
        }
    }

    private func textBinding(_ field: EditorField) -> Binding<String> {
        Binding(get: { model.text(field, code) }, set: { model.setText(field, code, $0) })
    }

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            Theme.picture
            if let data = editor.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let path = editor.existingImagePath, !path.isEmpty,
                      let url = try? supabase.storage.from("plant-photos").getPublicURL(path: path) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { ProgressView() }
                }
            } else {
                VStack(spacing: 6) {
                    Text("📷").font(.system(size: 48))
                    Text(lang.t("editor_photo_hint"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            if editor.aiBusy {
                Color.black.opacity(0.6)
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(lang.t("editor_ai_busy"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct PickerTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.greenDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }
}
