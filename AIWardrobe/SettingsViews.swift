import SwiftUI

struct ProfileView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var erase = false
    @State private var removePhotos = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                HStack {
                    PhotoView(image: store.avatar).frame(width: 90, height: 130)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("appName")).font(.title2.weight(.semibold))
                        Text(L(store.usesDefaultAvatar ? "defaultModel" : "personalModel")).font(.caption).foregroundStyle(.secondary)
                        Text(L("publicEdition")).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Picker(L("gender"), selection: $store.data.gender) {
                    Text(L("male")).tag("male"); Text(L("female")).tag("female")
                }.onChange(of: store.data.gender) { _, _ in store.save() }
                Picker(L("modelRegion"), selection: $store.data.modelRegion) {
                    ForEach(LocalizedModels.regions, id: \.self) { Text(L("region-\($0)")).tag($0) }
                }.onChange(of: store.data.modelRegion) { _, _ in store.save() }
                Text(L("localeNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("bodyPhotos")) {
                Text(L("bodyPhotoNote")).font(.caption).foregroundStyle(.secondary)
                ForEach(["front", "left", "right", "back"], id: \.self) { pose in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(L(pose))
                            Spacer()
                            if let photo = store.data.bodyPhotos[pose] {
                                PhotoView(image: UIImage(data: photo)).frame(width: 44, height: 66)
                                Button(role: .destructive) { store.data.bodyPhotos.removeValue(forKey: pose); store.save() } label: { Image(systemName: "trash") }.accessibilityLabel(L("delete"))
                            }
                        }
                        PhotoInput { data in
                            if let jpeg = ImageUtilities.compressedJPEG(from: data, maxDimension: 1536) { store.data.bodyPhotos[pose] = jpeg; store.save() }
                        }
                    }
                }
                Button(L("removeBodyPhotos"), role: .destructive) { removePhotos = true }
            }
            Section {
                NavigationLink(L("aiSettings")) { AISettingsView() }
                NavigationLink(L("savedLooks")) { SavedLooksView() }
                Button(L("restoreDemo")) { store.addDemo() }
            }
            Section(L("privacy")) {
                NavigationLink(L("privacyPolicy")) { LegalView(terms: false) }
                NavigationLink(L("terms")) { LegalView(terms: true) }
                Link(L("support"), destination: URL(string: "https://github.com/wliao78/AI-Wardrobe-Support/issues")!)
                Button(L("deleteAll"), role: .destructive) { erase = true }
                Text(L("localStorageNote")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L("profile")).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("deleteAll"), isPresented: $erase, titleVisibility: .visible) {
            Button(L("deleteAll"), role: .destructive) { store.erase() }
        } message: { Text(L("deleteAllWarning")) }
        .confirmationDialog(L("removeBodyPhotos"), isPresented: $removePhotos) {
            Button(L("delete"), role: .destructive) { store.data.bodyPhotos = [:]; store.save() }
        }
    }
}

struct SavedLooksView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var selected: Look?
    var body: some View {
        List {
            ForEach(store.data.looks.filter(\.saved)) { look in
                Button { selected = look } label: {
                    HStack {
                        PhotoView(image: look.image.flatMap(UIImage.init(data:)) ?? look.demoAsset.flatMap(UIImage.init(named:))).frame(width: 70, height: 90)
                        Text(look.displayTitle)
                    }
                }
                .swipeActions { Button(L("delete"), role: .destructive) {
                    if let i = store.data.looks.firstIndex(where: { $0.id == look.id }) { store.data.looks[i].saved = false; store.save() }
                } }
            }
        }.navigationTitle(L("savedLooks")).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { look in
                if let image = look.image.flatMap(UIImage.init(data:)) ?? look.demoAsset.flatMap(UIImage.init(named:)) { FullPhoto(image: image) }
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
                }.onChange(of: configuration.provider) { _, provider in
                    configuration.endpoint = provider.endpoint; configuration.model = provider.model
                    configuration.imageModel = provider.imageModel
                    configuration.textConsent = false; configuration.photoConsent = false; configuration.approvedEndpoint = ""
                    key = KeyVault.read(provider)
                }
                SecureField("API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(L("model"), text: $configuration.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                if configuration.provider == .custom || configuration.provider == .qwen {
                    TextField("https://…/v1", text: $configuration.endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .onChange(of: configuration.endpoint) { _, _ in configuration.textConsent = false; configuration.photoConsent = false }
                } else { Text(configuration.endpoint).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                if configuration.provider.supportsImages {
                    TextField(L("imageModel"), text: $configuration.imageModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                } else { Text(L("imageUnsupported")).font(.caption).foregroundStyle(.secondary) }
                Button(L("testConnection")) { Task { await test() } }.disabled(testing || key.isEmpty)
                if testing { ProgressView() }
                Text(L("apiCostNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("dataConsent")) {
                Text(configuration.provider.title).font(.headline)
                Text(configuration.endpoint).font(.caption).textSelection(.enabled)
                Text(L("textConsentDetails")).font(.subheadline)
                Toggle(L("allowText"), isOn: $configuration.textConsent)
                if configuration.provider.supportsImages {
                    Text(L("photoConsentDetails")).font(.subheadline)
                    Toggle(L("allowPhotos"), isOn: $configuration.photoConsent).disabled(!configuration.textConsent)
                }
                Link(L("providerPrivacy"), destination: configuration.provider.privacyURL)
                Text(L("revokeNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button(L("save")) { save() }
                Button(L("revokeConsent"), role: .destructive) {
                    configuration.textConsent = false; configuration.photoConsent = false; configuration.approvedEndpoint = ""; configuration.save()
                    message = L("consentRevoked")
                }
                Button(L("deleteKey"), role: .destructive) {
                    do { try KeyVault.save("", provider: configuration.provider); key = ""; configuration.textConsent = false; configuration.photoConsent = false; configuration.save() }
                    catch { message = error.localizedDescription }
                }
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
