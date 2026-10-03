import Foundation
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Prepares only the public, fictional demo catalogue. No personal Photos library inputs.
let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let destination = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let names = ["white-oxford", "charcoal-trousers", "brown-leather-shoes", "navy-polo", "beige-chinos", "white-sneakers", "gray-performance-top", "black-hiking-pants", "gray-hiking-shoes", "navy-jacket"]
let context = CIContext()
for name in names {
    let folder = source.appendingPathComponent(name + ".imageset")
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
    let entries = manifest["images"] as! [[String: Any]]
    let filename = entries.compactMap { $0["filename"] as? String }.first!
    let input = folder.appendingPathComponent(filename)
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(url: input)
    try handler.perform([request])
    guard let observation = request.results?.first, !observation.allInstances.isEmpty else { fatalError("No mask: \(name)") }
    let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
    let original = CIImage(contentsOf: input)!
    let mask = CIImage(cvPixelBuffer: buffer)
    let blend = CIFilter(name: "CIBlendWithMask", parameters: [kCIInputImageKey: original, kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: original.extent), kCIInputMaskImageKey: mask])!.outputImage!
    let image = context.createCGImage(blend, from: original.extent)!
    let out = destination.appendingPathComponent("cutout-" + name + ".imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let pngURL = out.appendingPathComponent(name + ".png")
    let writer = CGImageDestinationCreateWithURL(pngURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { fatalError("PNG write: \(name)") }
    let result: [String: Any] = ["images": [["filename": name + ".png", "idiom": "universal"]], "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("Contents.json"))
    print("Prepared \(name)")
}
