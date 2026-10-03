import SwiftUI
import Observation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum BodyMeasurementUnits: Equatable {
    case metric, us, uk
    init(locale: Locale) {
        switch locale.measurementSystem {
        case .us: self = .us
        case .uk: self = .uk
        default: self = .metric
        }
    }
    var imperialHeight: Bool { self != .metric }
    var heightLabel: String { imperialHeight ? "heightFeetInches" : "heightCM" }
    var weightLabel: String { self == .metric ? "weightKG" : self == .uk ? "weightStonePounds" : "weightPounds" }

    func heightFields(_ cm: Double?, locale: Locale) -> (main: String, secondary: String) {
        guard let cm else { return ("", "") }
        guard imperialHeight else { return (number(cm, locale: locale), "") }
        let inches = (cm / 2.54 * 10).rounded() / 10
        let feet = floor(inches / 12)
        return (number(feet, locale: locale), number(inches - feet * 12, locale: locale))
    }
    func weightFields(_ kg: Double?, locale: Locale) -> (main: String, secondary: String) {
        guard let kg else { return ("", "") }
        guard self != .metric else { return (number(kg, locale: locale), "") }
        let pounds = (kg / 0.45359237 * 10).rounded() / 10
        guard self == .uk else { return (number(pounds, locale: locale), "") }
        let stones = floor(pounds / 14)
        return (number(stones, locale: locale), number(pounds - stones * 14, locale: locale))
    }
    func heightCM(_ main: String, secondary: String, locale: Locale) -> Double? {
        guard let primary = parse(main, locale: locale) else { return nil }
        if !imperialHeight { return primary }
        guard primary == floor(primary), let inches = parse(secondary, locale: locale), inches < 12 else { return nil }
        return (primary * 12 + inches) * 2.54
    }
    func weightKG(_ main: String, secondary: String, locale: Locale) -> Double? {
        guard let primary = parse(main, locale: locale) else { return nil }
        if self == .metric { return primary }
        if self == .us { return primary * 0.45359237 }
        guard primary == floor(primary), let pounds = parse(secondary, locale: locale), pounds < 14 else { return nil }
        return (primary * 14 + pounds) * 0.45359237
    }
    private func number(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)).locale(locale))
    }
    private func parse(_ text: String, locale: Locale) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        let parser = NumberFormatter(); parser.locale = locale; parser.numberStyle = .decimal
        let separator = NSRegularExpression.escapedPattern(for: parser.decimalSeparator ?? ".")
        guard value.range(of: "^[0-9]+(?:\(separator)[0-9]+)?$", options: .regularExpression) != nil else { return nil }
        return parser.number(from: value)?.doubleValue
    }
}

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
    var style: String?
    var quickOverlay: Data?
    var displayName: String { demo ? L(name) : name }
    var displayStyle: String {
        if let style, !style.isEmpty { return style }
        guard demo else { return "" }
        if ["white-oxford", "charcoal-trousers", "brown-leather-shoes"].contains(asset ?? "") { return L("styleFormal") }
        if ["gray-performance-top", "black-hiking-pants", "gray-hiking-shoes"].contains(asset ?? "") { return L("outdoor") }
        return L("styleCasual")
    }
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
    var heightCM: Double?
    var weightKG: Double?
    var recommendationSelection: [UUID]?
    var initialized = false
}

@MainActor @Observable
final class WardrobeStore {
    var data = WardrobeData()
    var error: String?
    var epoch = UUID()
    private let file: URL
    private let resetAI: () throws -> Void
    private var storageReadable = true

    init(folder suppliedFolder: URL? = nil, resetAI: @escaping () throws -> Void = { try AIConfiguration.eraseAll() }) {
        self.resetAI = resetAI
        let folder = suppliedFolder ?? URL.applicationSupportDirectory.appending(path: "PublicWardrobe", directoryHint: .isDirectory)
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
        data.recommendationSelection?.removeAll { $0 == garment.id }
        data.looks.removeAll { $0.items.contains(garment.id) }
        save()
    }

    func erase() {
        do { try resetAI() }
        catch { self.error = error.localizedDescription; return }
        epoch = UUID()
        OfflineOutfitPreview.clearCache()
        storageReadable = true
        data = WardrobeData(); data.initialized = true
        URLCache.shared.removeAllCachedResponses()
        save()
    }
}

@main
struct AIWardrobeApp: App {
    @State private var store: WardrobeStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return WardrobeStore(folder: URL.temporaryDirectory.appending(path: "WardrobeUITests-" + UUID().uuidString), resetAI: {})
        }
        #endif
        return WardrobeStore()
    }()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Color(red: 0.36, green: 0.29, blue: 0.92))
                .alert(L("notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button(L("done")) { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
