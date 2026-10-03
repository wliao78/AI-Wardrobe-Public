import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AIWardrobe

@MainActor
final class FakeSpeechBackend: SpeechInputBackend {
    var error: SpeechInputFailure?
    var starts = 0
    var stops = 0
    var pending: CheckedContinuation<Void, Error>?
    var suspendAuthorization = false
    var finishImmediately = false
    var receive: (@MainActor (String?, Bool, Bool) -> Void)?
    func authorize() async throws {
        if let error { throw error }
        if suspendAuthorization { try await withCheckedThrowingContinuation { pending = $0 } }
    }
    func start(locale: Locale, receive: @escaping @MainActor (String?, Bool, Bool) -> Void) async throws {
        starts += 1; self.receive = receive
        if finishImmediately { receive("completed", true, false) }
    }
    func stop() { stops += 1 }
}

final class WardrobeTests: XCTestCase {
    func testAIImageResponseRequiresDisplayablePhoto() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 24), format: format).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
        }
        let jpeg = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        XCTAssertEqual(try AIClient.decodedImage(jpeg.base64EncodedString()), jpeg)
        for invalid in ["", "%%%", Data("not a photo".utf8).base64EncodedString()] {
            XCTAssertThrowsError(try AIClient.decodedImage(invalid)) { error in
                guard case AIError.invalidResponse = error else { return XCTFail("Unexpected error: \(error)") }
            }
        }
    }
    @MainActor func testRegionalWornReferencesAndComposedPreviews() throws {
        for region in ["us", "cn", "jp", "gb", "fr", "de", "es"] {
            for gender in ["male", "female"] {
                for variant in ["office", "weekend", "outdoor", "jacket"] {
                    let image = try XCTUnwrap(OfflineOutfitPreview.reference(variant: variant, gender: gender, region: region), "\(region) \(gender) \(variant)")
                    XCTAssertEqual(image.size.height / image.size.width, 1.5, accuracy: 0.02)
                }
            }
        }
        let store = WardrobeStore(folder: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), resetAI: {})
        let sets = [["white-oxford", "charcoal-trousers", "brown-leather-shoes"],
                    ["navy-polo", "black-hiking-pants", "gray-hiking-shoes"],
                    ["white-oxford", "beige-chinos", "white-sneakers", "navy-jacket"],
                    ["gray-performance-top", "charcoal-trousers", "brown-leather-shoes", "navy-jacket"],
                    ["gray-performance-top", "beige-chinos", "white-sneakers"],
                    ["white-oxford", "black-hiking-pants", "white-sneakers"],
                    ["navy-polo", "charcoal-trousers", "white-sneakers"]]
        for region in ["us", "cn", "jp", "gb", "fr", "de", "es"] {
            for gender in ["male", "female"] {
                store.data.modelRegion = region; store.data.gender = gender
                var encoded = Set<Data>()
                for (index, assets) in sets.enumerated() {
                    let garments = store.data.garments.filter { assets.contains($0.asset ?? "") }
                    let image = try XCTUnwrap(OfflineOutfitPreview.image(garments: garments, store: store))
                    XCTAssertTrue(encoded.insert(try XCTUnwrap(image.pngData())).inserted, "A changed outfit must change the offline image")
                    let attachment = XCTAttachment(image: image); attachment.name = "worn-\(region)-\(gender)-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
    }
    @MainActor func testWhiteSneakerMaskDoesNotCopyDonorChinoCuffs() {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 150), format: format).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 150))
            UIColor(red: 0.75, green: 0.68, blue: 0.55, alpha: 1).setFill()
            UIRectFill(CGRect(x: 30, y: 120, width: 15, height: 12))
        }
        let mask = OfflineOutfitPreview.shoeMask(image, variant: "weekend", defaultAnkle: 0.848)
        XCTAssertFalse(mask.contains(CGPoint(x: 35.5, y: 130.5)), "Beige donor cuff must remain outside the shoe layer")
        XCTAssertTrue(mask.contains(CGPoint(x: 35.5, y: 133.5)), "The sneaker below the cuff must remain visible")
        XCTAssertTrue(mask.contains(CGPoint(x: 20.5, y: 130.5)), "Background outside the cuff still replaces old shoe edges")
    }
    @MainActor func testBundledCatalogOfflineMasks() async {
        for asset in ["white-oxford", "navy-polo", "charcoal-trousers", "navy-jacket", "brown-leather-shoes"] {
            let image = UIImage(named: "cutout-" + asset)!
            let bytes = image.pngData()!
            let mask = await Task.detached { GarmentCutoutService.fittedPNG(bytes) }.value
            XCTAssertNotNil(mask, asset)
        }
    }
    func testExistingWardrobeDecodesWithoutNewMeasurements() throws {
        let old = Data(#"{"garments":[],"looks":[],"messages":[],"bodyPhotos":{},"gender":"male","modelRegion":"auto","initialized":true}"#.utf8)
        var decoded = try JSONDecoder().decode(WardrobeData.self, from: old)
        XCTAssertNil(decoded.heightCM); XCTAssertNil(decoded.weightKG)
        decoded.heightCM = 175; decoded.weightKG = 70.5
        let restored = try JSONDecoder().decode(WardrobeData.self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(restored.heightCM, 175); XCTAssertEqual(restored.weightKG, 70.5)
    }
    func testRegionalBodyMeasurementUnitsAndConversions() throws {
        let us = Locale(identifier: "en_US"), uk = Locale(identifier: "en_GB"), fr = Locale(identifier: "fr_FR")
        XCTAssertEqual(BodyMeasurementUnits(locale: us), .us)
        XCTAssertEqual(BodyMeasurementUnits(locale: uk), .uk)
        for identifier in ["zh_CN", "zh_TW", "ja_JP", "fr_FR", "de_DE", "es_ES", "en_CA", "en_AU"] {
            XCTAssertEqual(BodyMeasurementUnits(locale: Locale(identifier: identifier)), .metric, identifier)
        }
        // Region/measurement preferences, not the interface's language.
        XCTAssertEqual(BodyMeasurementUnits(locale: Locale(identifier: "zh_US")), .us)
        XCTAssertEqual(BodyMeasurementUnits(locale: Locale(identifier: "en_US@measure=metric")), .metric)
        let height = BodyMeasurementUnits.us.heightFields(175, locale: us)
        XCTAssertEqual(height.main, "5"); XCTAssertEqual(height.secondary, "8.9")
        XCTAssertEqual(BodyMeasurementUnits.us.weightFields(70.5, locale: us).main, "155.4")
        let britishWeight = BodyMeasurementUnits.uk.weightFields(70.5, locale: uk)
        XCTAssertEqual(britishWeight.main, "11"); XCTAssertEqual(britishWeight.secondary, "1.4")
        XCTAssertEqual(try XCTUnwrap(BodyMeasurementUnits.us.heightCM("5", secondary: "9", locale: us)), 175.26, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(BodyMeasurementUnits.us.weightKG("155.4", secondary: "", locale: us)), 70.488254298, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(BodyMeasurementUnits.uk.weightKG("11", secondary: "1.4", locale: uk)), 70.488254298, accuracy: 0.00001)
        XCTAssertEqual(BodyMeasurementUnits.metric.weightFields(70.5, locale: fr).main, "70,5")
        XCTAssertEqual(BodyMeasurementUnits.metric.weightKG("70,5", secondary: "", locale: fr), 70.5)
        XCTAssertNil(BodyMeasurementUnits.us.heightCM("5", secondary: "12", locale: us))
        XCTAssertNil(BodyMeasurementUnits.uk.weightKG("11", secondary: "14", locale: uk))
        XCTAssertNil(BodyMeasurementUnits.metric.heightCM("175abc", secondary: "", locale: us))
        XCTAssertNil(BodyMeasurementUnits.us.weightKG("-1", secondary: "", locale: us))
    }
    @MainActor func testWeatherUsesOneDecimalAndRegionalUnits() {
        let expected: [(String, String)] = [
            ("en_US", "68.2"), ("en_GB", "20.1"), ("zh_CN", "20.1"),
            ("zh_TW", "20.1"), ("ja_JP", "20.1"), ("fr_FR", "20,1"),
            ("de_DE", "20,1"), ("es_ES", "20,1")
        ]
        for (identifier, number) in expected {
            let result = PublicWeather.formattedTemperature(20.123456, locale: Locale(identifier: identifier))
            XCTAssertTrue(result.contains(number), "\(identifier): \(result)")
            XCTAssertFalse(result.contains("123456"))
        }
        XCTAssertTrue(PublicWeather.formattedTemperature(20, locale: Locale(identifier: "zh_CN")).contains("20.0"))
        XCTAssertTrue(PublicWeather.formattedTemperature(-3.456, locale: Locale(identifier: "zh_CN")).contains("-3.5"))
    }
    @MainActor func testHEICOrientationCatalogAndPixelLimits() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let fixture = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 2048), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 2048))
            UIColor.blue.setFill(); context.fill(CGRect(x: 200, y: 100, width: 600, height: 1800))
        }
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, UTType.heic.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(fixture.cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let prepared = try XCTUnwrap(ImageUtilities.preparedGarmentJPEG(from: encoded as Data))
        let image = try XCTUnwrap(UIImage(data: prepared)?.cgImage)
        XCTAssertEqual(image.width, 768); XCTAssertEqual(image.height, 384)
        let catalog = try XCTUnwrap(GarmentCatalogImageService.catalogJPEG(from: encoded as Data))
        let catalogImage = try XCTUnwrap(UIImage(data: catalog)?.cgImage)
        XCTAssertEqual(catalogImage.width, 768); XCTAssertEqual(catalogImage.height, 768)
        let compressed = try XCTUnwrap(ImageUtilities.compressedJPEG(from: encoded as Data, maxDimension: 512))
        let compressedImage = try XCTUnwrap(UIImage(data: compressed)?.cgImage)
        XCTAssertEqual(max(compressedImage.width, compressedImage.height), 512)
        XCTAssertNil(ImageUtilities.preparedGarmentJPEG(from: Data("not an image".utf8)))
        XCTAssertNil(GarmentCatalogImageService.catalogJPEG(from: Data()))
    }

    @MainActor func testSpeechPartialFinalAndRepeatedStart() async {
        let backend = FakeSpeechBackend()
        let speech = SpeechInputService(backend: backend)
        await speech.start(); await speech.start()
        XCTAssertEqual(backend.starts, 1); XCTAssertTrue(speech.isListening)
        backend.receive?("Hello", false, false)
        XCTAssertEqual(speech.transcript, "Hello")
        backend.receive?("Hello wardrobe", true, false)
        XCTAssertFalse(speech.isListening); XCTAssertFalse(speech.isStarting)
        XCTAssertEqual(speech.transcript, "Hello wardrobe")
        await speech.start(); XCTAssertTrue(speech.isListening)
        XCTAssertEqual(speech.transcript, "")
        speech.stop(); XCTAssertFalse(speech.isListening)
    }

    @MainActor func testStoppedSessionIgnoresLateTranscript() async {
        let backend = FakeSpeechBackend()
        let active = SpeechInputService(backend: backend)
        await active.start(); let old = backend.receive
        active.stop(); await active.start()
        old?("stale private words", true, false)
        XCTAssertEqual(active.transcript, ""); XCTAssertTrue(active.isListening)
        active.stop()
    }

    @MainActor func testStopDuringAuthorizationDoesNotStartEngine() async {
        let backend = FakeSpeechBackend(); backend.suspendAuthorization = true
        let speech = SpeechInputService(backend: backend)
        let start = Task { await speech.start() }
        await Task.yield()
        XCTAssertTrue(speech.isStarting)
        speech.stop(); backend.pending?.resume(); await start.value
        XCTAssertEqual(backend.starts, 0); XCTAssertFalse(speech.isStarting)
    }

    @MainActor func testAuthorizationFailuresResetState() async {
        for failure in [SpeechInputFailure.speechPermission, .microphonePermission, .noInput, .unavailable, .startFailed] {
            let backend = FakeSpeechBackend(); backend.error = failure
            let speech = SpeechInputService(backend: backend)
            await speech.start()
            XCTAssertFalse(speech.isListening); XCTAssertFalse(speech.isStarting)
            XCTAssertNotNil(speech.errorMessage); XCTAssertEqual(backend.starts, 0)
        }
    }

    @MainActor func testSynchronousCompletionDoesNotLeaveListeningState() async {
        let backend = FakeSpeechBackend(); backend.finishImmediately = true
        let speech = SpeechInputService(backend: backend)
        await speech.start()
        XCTAssertFalse(speech.isListening); XCTAssertFalse(speech.isStarting)
    }

    @MainActor func testSpeechLocales() {
        for (language, region, expected) in [("en","US","en-US"),("en","GB","en-GB"),("zh-Hans","CN","zh-CN"),("zh-Hant","TW","zh-TW"),("zh-Hant","HK","zh-HK"),("ja","JP","ja-JP"),("fr","FR","fr-FR"),("fr","CA","fr-CA"),("de","DE","de-DE"),("es","ES","es-ES"),("es","MX","es-MX")] {
            XCTAssertEqual(SpeechInputService.locale(language: language, region: region).identifier, expected)
        }
    }

    @MainActor func testDemoPersistenceAndRemoval() {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = WardrobeStore(folder: folder)
        XCTAssertEqual(store.data.garments.count, 10); XCTAssertEqual(store.data.looks.count, 3)
        XCTAssertTrue(store.usesDefaultAvatar); XCTAssertNotNil(store.avatar)
        store.addDemo(); XCTAssertEqual(store.data.garments.count, 10)
        let item = store.data.garments[0]; store.remove(item)
        XCTAssertFalse(store.data.looks.contains { $0.items.contains(item.id) })
        let restored = WardrobeStore(folder: folder)
        XCTAssertEqual(restored.data.garments.count, 9)
        XCTAssertNil(restored.error)
    }

    @MainActor func testUnreadableStoreIsNotOverwritten() throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "wardrobe.json"), bytes = Data("corrupt but preserve".utf8)
        try bytes.write(to: file)
        let store = WardrobeStore(folder: folder)
        XCTAssertNotNil(store.error); store.save()
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    @MainActor func testErasePersistsEmptyStoreWithoutReseedingDemo() {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        var resetCalls = 0
        let store = WardrobeStore(folder: folder, resetAI: { resetCalls += 1 })
        store.data.messages.append(Chat(user: true, text: "Synthetic test message"))
        store.data.bodyPhotos["front"] = Data([1, 2, 3])
        store.data.gender = "female"; store.data.modelRegion = "jp"
        let oldEpoch = store.epoch
        store.erase()
        XCTAssertEqual(resetCalls, 1); XCTAssertNotEqual(oldEpoch, store.epoch)
        XCTAssertTrue(store.data.garments.isEmpty); XCTAssertTrue(store.data.looks.isEmpty)
        XCTAssertTrue(store.data.messages.isEmpty); XCTAssertTrue(store.data.bodyPhotos.isEmpty)
        let restored = WardrobeStore(folder: folder, resetAI: {})
        XCTAssertTrue(restored.data.garments.isEmpty); XCTAssertTrue(restored.data.initialized)
        XCTAssertNil(restored.error)
    }

    @MainActor func testFailedCredentialEraseDoesNotClaimDataWasDeleted() {
        let store = WardrobeStore(folder: URL.temporaryDirectory.appending(path: UUID().uuidString),
                                  resetAI: { throw SpeechInputFailure.startFailed })
        let oldEpoch = store.epoch
        store.erase()
        XCTAssertNotNil(store.error); XCTAssertEqual(store.data.garments.count, 10)
        XCTAssertEqual(store.epoch, oldEpoch)
    }
}
