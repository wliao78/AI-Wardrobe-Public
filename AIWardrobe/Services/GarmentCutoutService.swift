import CoreImage
import CoreML
import Foundation
import UIKit
import Vision

enum GarmentCutoutService {
    static func fittedTransparentPNG(from data: Data) -> Data? {
        guard let png = transparentPNG(from: data) else { return nil }
        return fittedPNG(png)
    }
    static func fittedPNG(_ png: Data) -> Data? {
        guard let image = UIImage(data: png)?.cgImage else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height)); return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = 0, maxY = 0
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX, minY <= maxY,
              let crop = image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) else { return nil }
        return UIImage(cgImage: crop).pngData()
    }
    /// Runs once per garment, off the UI thread. A failed mask simply leaves quick preview unavailable.
    static func transparentPNG(from data: Data) -> Data? {
        guard let image = UIImage(data: data)?.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            #if targetEnvironment(simulator)
            for (stage, devices) in try request.supportedComputeStageDevices {
                if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
            #endif
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
            #if DEBUG
            print("Garment foreground mask unavailable: \((error as NSError).domain) \((error as NSError).code) \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
