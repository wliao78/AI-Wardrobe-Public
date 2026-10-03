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
