import CoreImage
import Foundation
import UIKit
import Vision

enum GarmentCutoutService {
    /// Runs once per garment, off the UI thread. A failed mask simply leaves quick preview unavailable.
    static func transparentPNG(from data: Data) -> Data? {
        guard let image = UIImage(data: data)?.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            let mask = CIImage(cvPixelBuffer: buffer)
            let source = CIImage(cgImage: image)
            guard let blend = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: source,
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent),
                kCIInputMaskImageKey: mask
            ])?.outputImage,
                let cutout = CIContext().createCGImage(blend, from: source.extent) else { return nil }
            return UIImage(cgImage: cutout).pngData()
        } catch {
            return nil
        }
    }
}
