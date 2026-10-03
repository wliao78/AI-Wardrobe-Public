import SwiftUI

struct ProfileView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var erase = false
    @State private var removePhotos = false
    @State private var height = ""
    @State private var heightInches = ""
    @State private var weight = ""
    @State private var weightPounds = ""
    @State private var selectedPose: String?
    private enum MeasurementField: Hashable { case height, inches, weight, pounds }
    @FocusState private var measurementFocus: MeasurementField?
    @Environment(\.locale) private var interfaceLocale
    private var locale: Locale { .current }
    private var units: BodyMeasurementUnits { BodyMeasurementUnits(locale: locale) }
    var body: some View {
        @Bindable var store = store
        Form {
            Section(L("basicDetails")) {
                Picker(L("gender"), selection: $store.data.gender) {
                    Text(L("male")).tag("male"); Text(L("female")).tag("female")
                }.onChange(of: store.data.gender) { _, _ in store.save() }
                HStack {
                    Text(L(units.heightLabel))
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        TextField(units.imperialHeight ? "—" : "175", text: $height)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).focused($measurementFocus, equals: .height)
                            .frame(width: units.imperialHeight ? 40 : 100).accessibilityIdentifier("profile.height")
                            .accessibilityLabel(L(units.heightLabel) + (units.imperialHeight ? " ft" : ""))
                        if units.imperialHeight {
                            Text("ft").font(.caption).foregroundStyle(.secondary)
                            TextField("—", text: $heightInches).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .autocorrectionDisabled().textInputAutocapitalization(.never).focused($measurementFocus, equals: .inches)
                                .frame(width: 48).accessibilityIdentifier("profile.heightInches").accessibilityLabel(L(units.heightLabel) + " in")
                            Text("in").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Text(L(units.weightLabel))
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        TextField(units == .metric ? "70" : units == .uk ? "—" : "155", text: $weight)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).focused($measurementFocus, equals: .weight)
                            .frame(width: units == .uk ? 40 : 100).accessibilityIdentifier("profile.weight").accessibilityLabel(L(units.weightLabel))
                        if units == .uk {
                            Text("st").font(.caption).foregroundStyle(.secondary)
                            TextField("—", text: $weightPounds).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .autocorrectionDisabled().textInputAutocapitalization(.never).focused($measurementFocus, equals: .pounds)
                                .frame(width: 48).accessibilityIdentifier("profile.weightPounds").accessibilityLabel(L(units.weightLabel) + " lb")
                            Text("lb").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button(L("saveDetails")) {
                    let heightEmpty = height.isEmpty && (!units.imperialHeight || heightInches.isEmpty)
                    let weightEmpty = weight.isEmpty && (units != .uk || weightPounds.isEmpty)
                    let newHeight = heightEmpty ? nil : units.heightCM(height, secondary: heightInches, locale: locale)
                    let newWeight = weightEmpty ? nil : units.weightKG(weight, secondary: weightPounds, locale: locale)
                    guard (heightEmpty || newHeight.map { $0 > 0 && $0 < 300 } == true),
                          (weightEmpty || newWeight.map { $0 > 0 && $0 < 700 } == true) else {
                        store.error = L("invalidMeasurements"); return
                    }
                    // Preserve exact stored measurements when merely saving
                    // their rounded display in another unit system.
                    let oldHeight = units.heightFields(store.data.heightCM, locale: locale)
                    let oldWeight = units.weightFields(store.data.weightKG, locale: locale)
                    if height != oldHeight.main || heightInches != oldHeight.secondary { store.data.heightCM = newHeight }
                    if weight != oldWeight.main || weightPounds != oldWeight.secondary { store.data.weightKG = newWeight }
                    store.save()
                    measurementFocus = nil
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                        print("QA synthetic measurements: \(units), \(locale.identifier), input=\(height)/\(heightInches)/\(weight)/\(weightPounds), cm=\(String(describing: store.data.heightCM)), kg=\(String(describing: store.data.weightKG))")
                    }
                    #endif
                }.accessibilityIdentifier("profile.saveDetails")
                Text(L("measurementsLocalOnly")).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.measurementSystem").accessibilityValue("\(units)")
            }
            Section(L("personPreview")) {
                Text(L("bodyPhotoNote")).font(.subheadline).foregroundStyle(.secondary)
                Picker(L("modelRegion"), selection: $store.data.modelRegion) {
                    ForEach(LocalizedModels.regions, id: \.self) { Text(L("region-\($0)")).tag($0) }
                }.onChange(of: store.data.modelRegion) { _, _ in store.save() }
                Text(L("localeNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("bodyPhotos")) {
                ForEach(["front", "left", "right", "back"], id: \.self) { pose in
                    Button { selectedPose = pose } label: {
                        HStack(spacing: 14) {
                            Group {
                                if let photo = store.data.bodyPhotos[pose], let image = UIImage(data: photo) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else { Image(systemName: "person.crop.rectangle").foregroundStyle(.indigo) }
                            }.frame(width: 58, height: 72).background(.indigo.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text(L(pose)).font(.headline)
                                Text(L("poseInstruction")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: store.data.bodyPhotos[pose] == nil ? "chevron.right" : "checkmark.circle.fill").foregroundStyle(.indigo)
                        }
                    }.foregroundStyle(.primary).accessibilityIdentifier("profile.photo." + pose)
                }
                Button(L("removeBodyPhotos"), role: .destructive) { removePhotos = true }
            }
            Section(L("dataAndPrivacy")) {
                NavigationLink(L("aiSettings")) { AISettingsView() }.accessibilityIdentifier("profile.aiSettings")
                NavigationLink(L("savedLooks")) { SavedLooksView() }.accessibilityIdentifier("profile.savedLooks")
                Button(L("restoreDemo")) { store.addDemo() }
            }
            Section(L("privacy")) {
                NavigationLink(L("privacyPolicy")) { LegalView(terms: false) }
                NavigationLink(L("terms")) { LegalView(terms: true) }
                Link(L("support"), destination: URL(string: "https://github.com/wliao78/AI-Wardrobe-Support/issues")!)
                Button(L("deleteAll"), role: .destructive) { erase = true }.accessibilityIdentifier("profile.erase")
                Text(L("localStorageNote")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { selectedPose != nil }, set: { if !$0 { selectedPose = nil } })) {
            if let pose = selectedPose { BodyPhotoEditor(pose: pose) }
        }
        .onAppear { loadMeasurements() }
        .onChange(of: interfaceLocale) { _, _ in loadMeasurements() }
        .onChange(of: units) { _, _ in loadMeasurements() }
        .onChange(of: store.epoch) { _, _ in height = ""; heightInches = ""; weight = ""; weightPounds = "" }
        .confirmationDialog(L("deleteAll"), isPresented: $erase, titleVisibility: .visible) {
            Button(L("deleteAll"), role: .destructive) { store.erase() }.accessibilityIdentifier("profile.confirmErase")
        } message: { Text(L("deleteAllWarning")) }
        .confirmationDialog(L("removeBodyPhotos"), isPresented: $removePhotos) {
            Button(L("delete"), role: .destructive) { store.data.bodyPhotos = [:]; store.save() }
        }
    }
    private func loadMeasurements() {
        let h = units.heightFields(store.data.heightCM, locale: locale)
        let w = units.weightFields(store.data.weightKG, locale: locale)
        height = h.main; heightInches = h.secondary; weight = w.main; weightPounds = w.secondary
    }
}

private struct BodyPhotoEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pose: String
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PhotoView(image: store.data.bodyPhotos[pose].flatMap(UIImage.init(data:)))
                        .frame(height: 400).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    Text(L("poseInstruction")).font(.title3.bold()).multilineTextAlignment(.center)
                    Text(L("bodyPhotoNote")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    PhotoInput(prominent: true) { data in
                        if let photo = ImageUtilities.compressedJPEG(from: data, maxDimension: 1536) {
                            store.data.bodyPhotos[pose] = photo; store.save(); dismiss()
                        }
                    }
                    if store.data.bodyPhotos[pose] != nil {
                        Button(L("delete"), role: .destructive) { store.data.bodyPhotos.removeValue(forKey: pose); store.save(); dismiss() }
                    }
                }.padding(16)
            }.navigationTitle(L(pose)).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(L("done")) { dismiss() }.accessibilityIdentifier("bodyPhoto.close") }
        }
    }
}

struct SavedLooksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WardrobeStore.self) private var store
    @State private var selected: Look?
    private func image(for look: Look) -> UIImage? {
        look.image.flatMap(UIImage.init(data:)) ?? OfflineOutfitPreview.image(garments: store.data.garments.filter { look.items.contains($0.id) }, store: store)
    }
    var body: some View {
        List {
            if store.data.looks.filter(\.saved).isEmpty {
                ContentUnavailableView(L("emptyFavorites"), systemImage: "heart", description: Text(L("favoriteHelp")))
            }
            ForEach(store.data.looks.filter(\.saved)) { look in
                Button { selected = look } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(look.displayTitle).font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.data.garments.filter { look.items.contains($0.id) }) { garment in
                                    VStack {
                                        PhotoView(image: garment.image).frame(width: 68, height: 68)
                                        Text(garment.displayName).font(.caption2).lineLimit(1).frame(width: 68)
                                    }
                                }
                            }
                        }
                    }.padding(.vertical, 5).foregroundStyle(.primary)
                }.buttonStyle(.plain)
                .swipeActions { Button(L("delete"), role: .destructive) {
                    if let i = store.data.looks.firstIndex(where: { $0.id == look.id }) { store.data.looks[i].saved = false; store.save() }
                } }
            }
        }.navigationTitle(L("savedLooks")).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L("done")) { dismiss() }.accessibilityIdentifier("savedLooks.close") }
            .sheet(item: $selected) { look in
                if let image = image(for: look) { FullPhoto(image: image) }
                else { Text(look.displayTitle).padding() }
            }
    }
}

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = AIConfiguration.current
    @State private var key = KeyVault.read(AIConfiguration.current.provider)
    @State private var testing = false
    @State private var message: String?
    var body: some View {
        Form {
            Section(L("provider")) {
                Picker(L("provider"), selection: $configuration.provider) {
                    ForEach(AIProvider.allCases) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("ai.provider").onChange(of: configuration.provider) { _, provider in
                    configuration.endpoint = provider.endpoint; configuration.model = provider.model
                    configuration.imageModel = provider.imageModel
                    configuration.textConsent = false; configuration.photoConsent = false; configuration.approvedEndpoint = ""
                    key = KeyVault.read(provider)
                }
                SecureField("API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("ai.key")
                TextField(L("model"), text: $configuration.model).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("ai.model")
                if configuration.provider == .custom || configuration.provider == .qwen {
                    TextField("https://…/v1", text: $configuration.endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityIdentifier("ai.endpoint")
                        .onChange(of: configuration.endpoint) { _, _ in configuration.textConsent = false; configuration.photoConsent = false }
                    if configuration.provider == .qwen {
                        Text(L("qwenRegionNote")).font(.caption).foregroundStyle(.secondary)
                        Link(L("providerSetup"), destination: URL(string: "https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope")!)
                    }
                } else { Text(configuration.endpoint).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                if configuration.provider.supportsImages {
                    TextField(L("imageModel"), text: $configuration.imageModel).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("ai.imageModel")
                } else { Text(L("imageUnsupported")).font(.caption).foregroundStyle(.secondary) }
                Button(L("testConnection")) { Task { await test() } }.disabled(testing || key.isEmpty).accessibilityIdentifier("ai.testConnection")
                if testing { ProgressView() }
                Text(L("apiCostNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("dataConsent")) {
                Text(configuration.provider.title).font(.headline)
                Text(configuration.endpoint).font(.caption).textSelection(.enabled)
                Text(L("textConsentDetails")).font(.subheadline)
                Toggle(L("allowText"), isOn: $configuration.textConsent).accessibilityIdentifier("ai.textConsent")
                if configuration.provider.supportsImages {
                    Text(L("photoConsentDetails")).font(.subheadline)
                    Toggle(L("allowPhotos"), isOn: $configuration.photoConsent).disabled(!configuration.textConsent).accessibilityIdentifier("ai.photoConsent")
                }
                Link(L("providerPrivacy"), destination: configuration.provider.privacyURL)
                Text(L("revokeNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button(L("save")) { save() }.accessibilityIdentifier("ai.save")
                Button(L("revokeConsent"), role: .destructive) {
                    configuration.textConsent = false; configuration.photoConsent = false; configuration.approvedEndpoint = ""; configuration.save()
                    message = L("consentRevoked")
                }.accessibilityIdentifier("ai.revokeConsent")
                Button(L("deleteKey"), role: .destructive) {
                    do { try KeyVault.save("", provider: configuration.provider); key = ""; configuration.textConsent = false; configuration.photoConsent = false; configuration.save() }
                    catch { message = error.localizedDescription }
                }.accessibilityIdentifier("ai.deleteKey")
            }
        }.navigationTitle(L("aiSettings")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("done")) { dismiss() } } }
            .alert(L("notice"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("done")) { message = nil } } message: { Text(message ?? "") }
    }
    func save() {
        do {
            configuration.model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
            key = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { _ = try AIClient(configuration: configuration, key: key).validateEndpoint() }
            try KeyVault.save(key, provider: configuration.provider)
            configuration.approvedEndpoint = configuration.endpoint
            configuration.photoConsent = configuration.photoConsent && configuration.textConsent && configuration.provider.supportsImages
            configuration.save(); message = L("settingsSaved")
        } catch { message = error.localizedDescription }
    }
    func test() async {
        testing = true; defer { testing = false }
        do {
            _ = try await AIClient(configuration: configuration, key: key).text("", system: "", testOnly: true)
            message = L("connectionOK")
        } catch { message = error.localizedDescription }
    }
}

struct LegalView: View {
    let terms: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("appName")).font(.title2.bold())
                Text("2026-10-02").font(.caption).foregroundStyle(.secondary)
                Text(NSLocalizedString(terms ? "termsBody" : "privacyBody", tableName: "Legal", comment: "")).textSelection(.enabled)
                Link(L("support"), destination: URL(string: "https://github.com/wliao78/AI-Wardrobe-Support/issues")!)
                if !terms {
                    ForEach(AIProvider.allCases.filter { $0 != .custom }) { provider in
                        Link(provider.title, destination: provider.privacyURL)
                    }
                }
            }.padding(20)
        }.navigationTitle(L(terms ? "terms" : "privacyPolicy")).navigationBarTitleDisplayMode(.inline)
    }
}
