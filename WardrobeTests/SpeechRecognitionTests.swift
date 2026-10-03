import XCTest
@preconcurrency import Speech
@testable import AIWardrobe

// These fixtures contain only synthetic styling phrases, never user recordings.
// This tests Apple's real recognizer, separately from microphone-route UI tests.
final class SpeechRecognitionTests: XCTestCase {
    @MainActor func testSevenLanguageRealTranscription() async throws {
        let backend = AppleSpeechInputBackend()
        try await backend.authorize()
        for (language, region, keyword) in [
            ("en", "US", "casual"), ("zh-Hans", "CN", "休闲"),
            ("zh-Hant", "TW", "休閒"), ("ja", "JP", "服"),
            ("fr", "FR", "tenue"), ("de", "DE", "outfit"), ("es", "ES", "ropa")
        ] {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: language, withExtension: "aiff"))
            let locale = SpeechInputService.locale(language: language, region: region)
            let recognizer = try XCTUnwrap(SFSpeechRecognizer(locale: locale))
            print("Speech fixture \(language): available=\(recognizer.isAvailable), onDeviceSupported=\(recognizer.supportsOnDeviceRecognition)")
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = false
            request.shouldReportPartialResults = true
            let done = expectation(description: language + " real transcription")
            var transcript = ""
            var failure: String?
            var finished = false
            let task = RecognitionFixture.start(recognizer, request: request) { text, final, error in
                guard !finished else { return }
                if let text { transcript = text }
                if final || error != nil {
                    finished = true; failure = error; done.fulfill()
                }
            }
            await fulfillment(of: [done], timeout: 45)
            finished = true; task.cancel()
            XCTAssertNil(failure, language + " recognizer: " + (failure ?? ""))
            XCTAssertTrue(transcript.lowercased().contains(keyword), language + " synthetic fixture keyword missing")
        }
    }
}

private enum RecognitionFixture {
    nonisolated static func start(_ recognizer: SFSpeechRecognizer, request: SFSpeechURLRecognitionRequest,
                                  receive: @escaping @MainActor (String?, Bool, String?) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            let diagnostic = error.map { error in
                var diagnostic = ""; var current: NSError? = error as NSError
                for _ in 0..<3 {
                    guard let issue = current else { break }
                    diagnostic += "\(issue.domain) \(issue.code): \(issue.localizedDescription); "
                    current = issue.userInfo[NSUnderlyingErrorKey] as? NSError
                }
                return diagnostic
            }
            Task { @MainActor in receive(text, final, diagnostic) }
        }
    }
}
