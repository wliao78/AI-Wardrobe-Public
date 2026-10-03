import UIKit
import Vision

struct PreparedGarment {
    let photo: Data
    let catalog: Data
    let overlay: Data?
    let category: Category?
}

enum GarmentPreparation {
    /// Camera and photo-library imports share this local processing path.
    static func prepare(_ data: Data) -> PreparedGarment? {
        guard let photo = ImageUtilities.preparedGarmentJPEG(from: data) else { return nil }
        let transparent = GarmentCutoutService.transparentPNG(from: photo)
        guard let catalog = GarmentCatalogImageService.catalogJPEG(prepared: photo, cutout: transparent) else { return nil }
        return PreparedGarment(photo: photo, catalog: catalog,
                               overlay: transparent.flatMap(GarmentCutoutService.fittedPNG), category: category(photo))
    }
    private static func category(_ photo: Data) -> Category? {
        let request = VNClassifyImageRequest()
        guard (try? VNImageRequestHandler(data: photo).perform([request])) != nil else { return nil }
        for result in (request.results ?? []).prefix(12) where result.confidence > 0.15 {
            let label = result.identifier.lowercased()
            if ["shoe", "sneaker", "boot"].contains(where: label.contains) { return .shoes }
            if ["jacket", "coat", "blazer"].contains(where: label.contains) { return .outerwear }
            if ["trouser", "pants", "jean", "shorts"].contains(where: label.contains) { return .bottom }
            if ["shirt", "sweater", "blouse"].contains(where: label.contains) { return .top }
            if ["hat", "scarf", "handbag"].contains(where: label.contains) { return .accessory }
        }
        return nil
    }
}
