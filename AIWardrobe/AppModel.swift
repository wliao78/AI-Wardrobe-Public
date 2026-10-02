import SwiftUI
import Observation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum Category: String, Codable, CaseIterable, Identifiable {
    case top, bottom, outerwear, shoes, accessory
    var id: String { rawValue }
    var title: String { L(rawValue) }
}

struct Garment: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var category: Category
    var color = ""
    var photo: Data?
    var catalog: Data?
    var asset: String?
    var demo = false
    var displayName: String { demo ? L(name) : name }
    var image: UIImage? { catalog.flatMap(UIImage.init(data:)) ?? asset.flatMap(UIImage.init(named:)) ?? photo.flatMap(UIImage.init(data:)) }
}

struct Look: Codable, Identifiable {
    var id = UUID()
    var title: String
    var items: [UUID]
    var image: Data?
    var demoAsset: String?
    var saved = false
    var displayTitle: String { demoAsset == nil ? title : L(title) }
}

struct Chat: Codable, Identifiable {
    var id = UUID()
    var user: Bool
    var text: String
}

struct WardrobeData: Codable {
    var garments: [Garment] = []
    var looks: [Look] = []
    var messages: [Chat] = []
    var bodyPhotos: [String: Data] = [:]
    var gender = "male"
    var modelRegion = "auto"
    var initialized = false
}

@MainActor @Observable
final class WardrobeStore {
    var data = WardrobeData()
    var error: String?
    var epoch = UUID()
    private let file: URL
    private var storageReadable = true

    init() {
        let folder = URL.applicationSupportDirectory.appending(path: "PublicWardrobe", directoryHint: .isDirectory)
        file = folder.appending(path: "wardrobe.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var excluded = folder
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            if FileManager.default.fileExists(atPath: file.path) {
                data = try JSONDecoder().decode(WardrobeData.self, from: Data(contentsOf: file))
            }
            if !data.initialized { addDemo(); data.initialized = true; save() }
        } catch { storageReadable = false; self.error = L("storageError") }
    }

    var avatar: UIImage? {
        if ["front", "left", "right", "back"].allSatisfy({ data.bodyPhotos[$0] != nil }),
           let front = data.bodyPhotos["front"] { return UIImage(data: front) }
        return LocalizedModels.image(gender: data.gender, region: data.modelRegion)
    }
    var usesDefaultAvatar: Bool { data.bodyPhotos.count < 4 }

    func save() {
        guard storageReadable else { self.error = L("storageError"); return }
        do {
            try JSONEncoder().encode(data).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = L("storageError") }
    }

    func addDemo() {
        guard !data.garments.contains(where: \.demo) else { return }
        let rows: [(String, Category)] = [
            ("white-oxford", .top), ("charcoal-trousers", .bottom), ("brown-leather-shoes", .shoes),
            ("navy-polo", .top), ("beige-chinos", .bottom), ("white-sneakers", .shoes),
            ("gray-performance-top", .top), ("black-hiking-pants", .bottom), ("gray-hiking-shoes", .shoes),
            ("navy-jacket", .outerwear)
        ]
        let garments = rows.map { Garment(name: $0.0, category: $0.1, asset: $0.0, demo: true) }
        data.garments += garments
        for (key, indices) in [("office", [0,1,2]), ("weekend", [3,4,5]), ("outdoor", [6,7,8,9])] {
            data.looks.append(Look(title: key, items: indices.map { garments[$0].id }, demoAsset: "demo-\(key)"))
        }
        save()
    }

    func remove(_ garment: Garment) {
        data.garments.removeAll { $0.id == garment.id }
        data.looks.removeAll { $0.items.contains(garment.id) }
        save()
    }

    func erase() {
        do { try AIConfiguration.eraseAll() }
        catch { self.error = error.localizedDescription; return }
        epoch = UUID()
        storageReadable = true
        data = WardrobeData(); data.initialized = true
        URLCache.shared.removeAllCachedResponses()
        save()
    }
}

@main
struct AIWardrobeApp: App {
    @State private var store = WardrobeStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Color(red: 0.36, green: 0.29, blue: 0.92))
                .alert(L("notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button(L("done")) { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
