import AVFoundation
@preconcurrency import Speech
import Observation
import OSLog

enum SpeechInputFailure: Error { case speechPermission, microphonePermission, unavailable, noInput, startFailed }

@MainActor
protocol SpeechInputBackend: AnyObject {
    func authorize() async throws
    func start(locale: Locale, receive: @escaping @MainActor (String?, Bool, Bool) -> Void) async throws
    func stop()
}

@MainActor @Observable
final class SpeechInputService {
    private(set) var isListening = false
    private(set) var isStarting = false
    private(set) var transcript = ""
    var errorMessage: String?
    private let backend: any SpeechInputBackend
    private var generation = UUID()
    private var limit: Task<Void, Never>?

    init(backend: any SpeechInputBackend = AppleSpeechInputBackend()) { self.backend = backend }

    static func locale(language: String = Bundle.main.preferredLocalizations.first ?? "en",
                       region: String = Locale.current.region?.identifier ?? "US") -> Locale {
        let identifier: String
        switch language {
        case "zh-Hans": identifier = "zh-CN"
        case "zh-Hant": identifier = region == "HK" ? "zh-HK" : "zh-TW"
        case "ja": identifier = "ja-JP"
        case "fr": identifier = region == "CA" ? "fr-CA" : "fr-FR"
        case "de": identifier = "de-DE"
        case "es": identifier = region == "MX" ? "es-MX" : "es-ES"
        default: identifier = ["GB", "AU", "CA", "IE"].contains(region) ? "en-\(region)" : "en-US"
        }
        return Locale(identifier: identifier)
    }

    func start() async {
        guard !isListening, !isStarting else { return }
        generation = UUID(); let token = generation
        isStarting = true; transcript = ""; errorMessage = nil
        defer { if token == generation { isStarting = false } }
        do {
            try await backend.authorize()
            guard token == generation else { return }
            try await backend.start(locale: Self.locale()) { [weak self] text, final, failed in
                guard let self, token == self.generation else { return }
                if let text { self.transcript = text }
                if final || failed {
                    self.stop()
                    if failed && self.transcript.isEmpty { self.errorMessage = L("speechUnavailable") }
                }
            }
            guard token == generation else { return }
            isListening = true
            limit = Task { [weak self] in
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, self?.generation == token else { return }
                self?.stop()
            }
        } catch {
            guard token == generation else { return }
            #if DEBUG
            let diagnostic = error as NSError
            Logger(subsystem: "com.tinyworm.AIWardrobe.Public", category: "Speech").error("Start failed: \(diagnostic.domain, privacy: .public) \(diagnostic.code)")
            #endif
            stop()
            let key = switch error as? SpeechInputFailure {
            case .speechPermission: "speechPermission"
            case .microphonePermission: "microphonePermission"
            case .noInput: "microphoneUnavailable"
            case .unavailable: "speechUnavailable"
            default: "speechStartFailed"
            }
            errorMessage = L(key)
        }
    }

    func stop() {
        generation = UUID(); limit?.cancel(); limit = nil
        backend.stop(); isListening = false; isStarting = false
    }
}

@MainActor
final class AppleSpeechInputBackend: SpeechInputBackend {
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var interruption: NSObjectProtocol?
    private var generation = UUID()
    private var sessionPendingOrActive = false

    func authorize() async throws {
        let speech = await Self.speechAuthorization()
        guard speech == .authorized else { throw SpeechInputFailure.speechPermission }
        guard await AVAudioApplication.requestRecordPermission() else { throw SpeechInputFailure.microphonePermission }
    }

    // Speech's legacy callback is not guaranteed to use the main queue. Creating it
    // outside MainActor prevents Swift 6's actor assertion from crashing on return.
    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
    }

    func start(locale: Locale, receive: @escaping @MainActor (String?, Bool, Bool) -> Void) async throws {
        stop()
        let token = generation
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { throw SpeechInputFailure.unavailable }
        do {
            sessionPendingOrActive = true
            try await SpeechAudioSession.activate()
            guard token == generation else { throw CancellationError() }
            let engine = AVAudioEngine(); self.engine = engine
            let input = engine.inputNode
            // Reading the input bus format can assert on simulator routes. Use the output bus only.
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate.isFinite, format.sampleRate > 0, format.channelCount > 0 else { throw SpeechInputFailure.noInput }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            #if targetEnvironment(simulator)
            // Simulator reports support even when the local model fails to load.
            // Exercise Apple's authorized network path instead of forcing that model.
            request.requiresOnDeviceRecognition = false
            #else
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            #endif
            self.request = request
            Self.installTap(input, format: format, request: request); tapInstalled = true
            engine.prepare(); try engine.start()
            task = Self.recognition(recognizer, request: request, receive: receive)
            interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in receive(nil, true, false) }
            }
        } catch {
            // A stopped start must never tear down a newer recording session.
            if token == generation { stop() }
            throw error
        }
    }

    private nonisolated static func installTap(_ input: AVAudioInputNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
    }
    private nonisolated static func recognition(_ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
                                              receive: @escaping @MainActor (String?, Bool, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            #if DEBUG
            if let error { let diagnostic = error as NSError; Logger(subsystem: "com.tinyworm.AIWardrobe.Public", category: "Speech").error("Recognition failed: \(diagnostic.domain, privacy: .public) \(diagnostic.code)") }
            #endif
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true; let failed = error != nil
            Task { @MainActor in receive(text, final, failed) }
        }
    }
    func stop() {
        generation = UUID()
        let shouldDeactivate = sessionPendingOrActive
        sessionPendingOrActive = false
        if let interruption { NotificationCenter.default.removeObserver(interruption); self.interruption = nil }
        engine?.stop()
        if tapInstalled { engine?.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil; engine = nil
        if shouldDeactivate { SpeechAudioSession.deactivate() }
    }
}

// Audio-route activation can block. Keep it off the UI actor and serialize start /
// stop requests so cancellation during activation cannot leave the microphone on.
private enum SpeechAudioSession {
    private static let queue = DispatchQueue(label: "com.tinyworm.AIWardrobe.Public.speech-audio")
    static func activate() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    static func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
