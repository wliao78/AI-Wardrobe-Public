import UIKit

/// Aligned, fully dressed studio references provide the offline approximation.
/// Product catalog photos are never substituted for a full-body model image.
@MainActor
enum OfflineOutfitPreview {
    private static var references: [String: UIImage] = [:]
    private static var upperMasks: [String: CGPath] = [:]
    private static var jacketLayers: [String: UIImage] = [:]
    private static let composites: NSCache<NSString, UIImage> = { let cache = NSCache<NSString, UIImage>(); cache.countLimit = 12; return cache }()
    static func clearCache() { composites.removeAllObjects() }

    static func reference(variant: String, gender: String, region: String) -> UIImage? {
        let region = region == "auto" ? LocalizedModels.region() : region
        let key = "worn-\(region)-\(variant)-\(gender)"
        if let cached = references[key] { return cached }
        guard let pair = UIImage(named: "worn-\(region)-\(variant)")?.cgImage else { return nil }
        let width = pair.width / 2
        guard let crop = pair.cropping(to: CGRect(x: gender == "female" ? width : 0, y: 0, width: width, height: pair.height)) else { return nil }
        let image = UIImage(cgImage: crop)
        references[key] = image
        return image
    }

    static func variant(for asset: String?) -> String? {
        switch asset {
        case "white-oxford", "charcoal-trousers", "brown-leather-shoes": "office"
        case "navy-polo", "beige-chinos", "white-sneakers": "weekend"
        case "gray-performance-top", "black-hiking-pants", "gray-hiking-shoes": "outdoor"
        case "navy-jacket": "jacket"
        default: nil
        }
    }

    static func image(garments: [Garment], store: WardrobeStore) -> UIImage? {
        let gender = store.data.gender
        let region = store.data.modelRegion == "auto" ? LocalizedModels.region() : store.data.modelRegion
        let signature = garments.map { "\($0.id)-\($0.category.rawValue)-\($0.asset ?? "")-\($0.quickOverlay?.hashValue ?? 0)" }.joined(separator: "|")
        let key = "\(store.epoch)-\(region)-\(gender)-\(store.usesDefaultAvatar)-\(store.data.bodyPhotos["front"]?.hashValue ?? 0)-\(signature)" as NSString
        if let cached = composites.object(forKey: key) { return cached }
        let top = garments.first { $0.category == .top }
        let baseVariant = variant(for: top?.asset) ?? "weekend"
        let base = store.usesDefaultAvatar && (top == nil || variant(for: top?.asset) != nil)
            ? reference(variant: baseVariant, gender: gender, region: region) ?? store.avatar
            : store.avatar
        guard let base else { return nil }
        let size = base.size
        let bounds = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            base.draw(in: bounds)
            if !store.usesDefaultAvatar {
                drawImported(garments, size: size)
                return
            }
            let context = renderer.cgContext
            if let bottom = garments.first(where: { $0.category == .bottom }),
               let bottomVariant = variant(for: bottom.asset), bottomVariant != baseVariant,
               let trousers = reference(variant: bottomVariant, gender: gender, region: region) {
                trousers.draw(in: bounds)
                alignTrouserWaist(trousers, variant: bottomVariant, to: base, topVariant: baseVariant)
                context.saveGState()
                let maskKey = "\(region)-\(gender)-\(baseVariant)"
                let mask = upperMasks[maskKey] ?? upperMask(image: base, variant: baseVariant)
                upperMasks[maskKey] = mask
                context.addPath(mask); context.clip(); base.draw(in: bounds); context.restoreGState()
            }
            // The upper reference already contains the selected sleeves and hands.
            // Keep those intact when exchanging the trousers below the shirt hem.
            for category in [Category.shoes, .outerwear] {
                guard let garment = garments.first(where: { $0.category == category }),
                      let variant = variant(for: garment.asset),
                      let donor = reference(variant: variant, gender: gender, region: region) else { continue }
                context.saveGState()
                let path = CGMutablePath()
                if category == .shoes {
                    let ankle: CGFloat = ["gb", "fr", "de", "es"].contains(region) ? 0.868 : 0.848
                    context.addPath(shoeMask(donor, variant: variant, defaultAnkle: ankle))
                    context.clip(); donor.draw(in: bounds); context.restoreGState()
                    continue
                } else {
                    let layerKey = "\(region)-\(gender)"
                    let layer = jacketLayers[layerKey] ?? jacketLayer(donor)
                    jacketLayers[layerKey] = layer
                    layer?.draw(in: bounds)
                    context.restoreGState()
                    continue
                }
                context.addPath(path); context.clip(); donor.draw(in: bounds); context.restoreGState()
            }
            drawImported(garments.filter { variant(for: $0.asset) == nil }, size: size)
        }
        composites.setObject(rendered, forKey: key)
        return rendered
    }

    /// White sneakers come from a reference wearing beige chinos. Follow each
    /// column's actual cuff rather than copying a horizontal strip of those chinos.
    /// The already composed, selected trousers remain above this boundary.
    static func shoeMask(_ image: UIImage, variant: String, defaultAnkle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard variant == "weekend", let source = image.cgImage else {
            path.addRect(CGRect(x: 0, y: image.size.height * defaultAnkle, width: image.size.width,
                                height: image.size.height * (1 - defaultAnkle)))
            return path
        }
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            context?.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var boundaries = [Int](repeating: Int(CGFloat(height) * defaultAnkle), count: width)
        for x in 0..<width {
            var boundary = Int(CGFloat(height) * defaultAnkle)
            for y in boundary..<Int(Double(height) * 0.90) {
                let offset = (y * width + x) * 4
                let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
                if r > 90 && r - b > 30 && g - b > 10 && r >= g {
                    boundary = y + 1
                }
            }
            boundaries[x] = boundary
        }
        let rawBoundaries = boundaries
        for x in 0..<width {
            let neighbors = rawBoundaries[max(0, x - 5)...min(width - 1, x + 5)].sorted()
            boundaries[x] = neighbors[neighbors.count / 2]
        }
        // One continuous outline avoids antialiased vertical seams between
        // adjacent one-pixel clipping rectangles.
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: boundaries[0]))
        for x in 0..<width {
            path.addLine(to: CGPoint(x: x, y: boundaries[x]))
            path.addLine(to: CGPoint(x: x + 1, y: boundaries[x]))
        }
        path.addLine(to: CGPoint(x: width, y: height)); path.closeSubpath()
        return path
    }

    /// These bundled references use one navy jacket over a neutral gray shirt.
    /// Extract its actual silhouette instead of rectangular panels that would
    /// leak the donor trousers or slice through the shoulders.
    private static func jacketLayer(_ image: UIImage) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let buffer = bytes.bindMemory(to: UInt8.self)
            var mask = [Double](repeating: 0, count: width * height)
            for y in 0..<height {
                for x in 0..<width {
                    let p = (y * width + x) * 4
                    let r = Double(buffer[p]), b = Double(buffer[p + 2])
                    let blue = (b - r) / max(1, b)
                    let alpha = y > Int(Double(height) * 0.12) && y < Int(Double(height) * 0.53) ? min(1, max(0, (blue - 0.16) * 18)) : 0
                    mask[y * width + x] = alpha
                }
            }
            // Retain neutral zipper teeth, seams and highlights inside the navy
            // silhouette. Color selection alone leaves pinholes over light shirts.
            for y in 0..<height {
                var previous: Int?
                for x in 0..<width where mask[y * width + x] > 0.9 {
                    if let start = previous, x - start > 1, x - start <= 13 {
                        for fill in (start + 1)..<x { mask[y * width + fill] = 1 }
                    }
                    previous = x
                }
            }
            for y in 0..<height {
                for x in 0..<width {
                    let p = (y * width + x) * 4
                    let alpha = mask[y * width + x]
                    for channel in 0..<3 { buffer[p + channel] = UInt8(Double(buffer[p + channel]) * alpha) }
                    buffer[p + 3] = UInt8(255 * alpha)
                }
            }
            return context.makeImage().map { UIImage(cgImage: $0) }
        }
    }

    private static func drawImported(_ garments: [Garment], size: CGSize) {
        let order: [Category: Int] = [.bottom: 0, .top: 1, .outerwear: 2, .shoes: 3, .accessory: 4]
        for garment in garments.sorted(by: { order[$0.category, default: 0] < order[$1.category, default: 0] }) {
            let bytes = garment.quickOverlay ?? garment.asset.flatMap { UIImage(named: "cutout-" + $0)?.pngData() }
            guard let bytes, let cutout = UIImage(data: bytes) else { continue }
            let normalized: CGRect
            switch garment.category {
            case .top: normalized = CGRect(x: 0.235, y: 0.16, width: 0.53, height: 0.32)
            case .bottom: normalized = CGRect(x: 0.32, y: 0.465, width: 0.36, height: 0.405)
            case .outerwear: normalized = CGRect(x: 0.22, y: 0.15, width: 0.56, height: 0.35)
            case .shoes: normalized = CGRect(x: 0.32, y: 0.86, width: 0.36, height: 0.07)
            case .accessory: normalized = CGRect(x: 0.36, y: 0.03, width: 0.28, height: 0.10)
            }
            let area = CGRect(x: normalized.minX * size.width, y: normalized.minY * size.height,
                              width: normalized.width * size.width, height: normalized.height * size.height)
            let scale = min(area.width / cutout.size.width, area.height / cutout.size.height)
            let fitted = CGSize(width: cutout.size.width * scale, height: cutout.size.height * scale)
            cutout.draw(in: CGRect(x: area.midX - fitted.width / 2, y: area.minY, width: fitted.width, height: fitted.height))
        }
    }

    /// References have slightly different shirt lengths. Extend only the donor
    /// trousers up to the selected shirt's hem, keeping the knees/ankles fixed.
    /// Otherwise a shorter T-shirt exposes a strip of the donor's navy polo.
    private static func alignTrouserWaist(_ donor: UIImage, variant: String, to base: UIImage, topVariant: String) {
        guard let cg = donor.cgImage else { return }
        let sourceHems = shirtHems(image: donor, variant: variant)
        let targetHems = shirtHems(image: base, variant: topVariant)
        let stop = Int(Double(cg.height) * 0.59)
        for column in 32..<68 {
            guard let source = sourceHems[column], let target = targetHems[column],
                  source > target + 1, source + 2 < stop else { continue }
            let left = Int(Double(cg.width) * Double(column) / 100)
            let right = Int(Double(cg.width) * Double(column + 1) / 100)
            guard let strip = cg.cropping(to: CGRect(x: left, y: source + 2, width: right - left, height: stop - source - 2)) else { continue }
            UIImage(cgImage: strip).draw(in: CGRect(x: left, y: target, width: right - left, height: stop - target))
        }
    }

    private static func shirtHems(image: UIImage, variant: String) -> [Int: Int] {
        guard let cg = image.cgImage else { return [:] }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var hems: [Int: Int] = [:]
        for column in 31...69 {
            let x = Int(Double(width) * Double(column) / 100)
            var hem = Int(Double(height) * 0.46)
            for y in Int(Double(height) * 0.42)..<Int(Double(height) * 0.51) {
                let offset = (y * width + x) * 4
                let r = Double(pixels[offset]) / 255, g = Double(pixels[offset + 1]) / 255, b = Double(pixels[offset + 2]) / 255
                let light = (r + g + b) / 3
                let isShirt: Bool
                switch variant {
                case "office": isShirt = light > 0.74 && max(r, g, b) - min(r, g, b) < 0.15
                case "weekend": isShirt = b > r * 1.14 && light < 0.40
                default: isShirt = light > 0.32 && light < 0.64 && max(r, g, b) - min(r, g, b) < 0.12
                }
                if isShirt { hem = y + 1 }
            }
            hems[column] = hem
        }
        // At the sides, background or trouser highlights can satisfy the shirt
        // color rule. Bound those outliers by the actual central hem instead of
        // preserving triangular pieces of the previous trousers.
        let center = (42...58).compactMap { hems[$0] }.sorted()
        if !center.isEmpty {
            let median = center[center.count / 2]
            let tolerance = variant == "office" ? 10 : 3
            for column in 31...69 {
                hems[column] = min(hems[column] ?? median, median + tolerance)
            }
        }
        return hems
    }

    /// Follow each reference's real shirt hem so trouser exchanges do not leave
    /// a strip of the previous trouser color at the waist.
    private static func upperMask(image: UIImage, variant: String) -> CGPath {
        let size = image.size, path = CGMutablePath()
        guard let cg = image.cgImage else { path.addRect(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.47)); return path }
        let height = cg.height
        let hems = shirtHems(image: image, variant: variant)
        path.move(to: .zero); path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
        path.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.62))
        for column in stride(from: 65, through: 35, by: -1) {
            let hem = hems[column] ?? Int(Double(height) * 0.46)
            path.addLine(to: CGPoint(x: CGFloat(column) / 100 * size.width, y: CGFloat(hem) / CGFloat(height) * size.height))
        }
        path.addLine(to: CGPoint(x: size.width * 0.35, y: size.height * 0.62))
        path.addLine(to: CGPoint(x: 0, y: size.height * 0.62)); path.closeSubpath()
        return path
    }
}
