import UIKit

enum GarmentCatalogImageService {
    /// The closet's product image is independent of the quick try-on overlay.
    /// Keeping the full source frame avoids cutting off sleeves or shirt hems.
    static func catalogJPEG(from data: Data) -> Data? {
        guard let prepared = ImageUtilities.preparedGarmentJPEG(from: data),
              let original = UIImage(data: prepared) else { return nil }
        let candidate: UIImage
        if let png = GarmentCutoutService.transparentPNG(from: prepared),
           let cutout = UIImage(data: png) {
            candidate = cutout
        } else {
            candidate = original
        }
        let side: CGFloat = 768
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor(red: 0.965, green: 0.958, blue: 0.945, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let padding: CGFloat = 26
            let available = side - padding * 2
            let scale = min(available / candidate.size.width, available / candidate.size.height)
            let width = candidate.size.width * scale
            let height = candidate.size.height * scale
            candidate.draw(in: CGRect(x: (side - width) / 2, y: (side - height) / 2,
                                      width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.82)
    }
}
