import UIKit

@MainActor
enum LocalizedModels {
    static let regions = ["auto", "cn", "jp", "us", "gb", "fr", "de", "es"]
    private static var cache: [String: UIImage] = [:]
    static func region(language: String = Bundle.main.preferredLocalizations.first ?? "en", country: String = Locale.current.region?.identifier ?? "US") -> String {
        switch language {
        case let value where value.hasPrefix("zh"): return "cn"
        case "ja": return "jp"
        case "fr": return "fr"
        case "de": return "de"
        case "es": return "es"
        default: return ["GB", "IE"].contains(country) ? "gb" : "us"
        }
    }
    static func image(gender: String, region selected: String) -> UIImage? {
        let selectedRegion = selected == "auto" ? region() : selected
        let key = "\(selectedRegion)-\(gender)"
        if let image = cache[key] { return image }
        guard let pair = UIImage(named: "models-\(selectedRegion)")?.cgImage else { return nil }
        let width = pair.width / 2
        let rect = CGRect(x: gender == "female" ? width : 0, y: 0, width: width, height: pair.height)
        guard let crop = pair.cropping(to: rect) else { return nil }
        let image = UIImage(cgImage: crop)
        cache[key] = image
        return image
    }
}
