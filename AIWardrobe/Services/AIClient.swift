import Foundation
import Security
import ImageIO

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openai, gemini, anthropic, deepseek, qwen, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .openai: "OpenAI"
        case .gemini: "Google Gemini"
        case .anthropic: "Anthropic Claude"
        case .deepseek: "DeepSeek"
        case .qwen: "Alibaba Qwen"
        case .custom: L("customProvider")
        }
    }
    var endpoint: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/openai"
        case .anthropic: "https://api.anthropic.com/v1"
        case .deepseek: "https://api.deepseek.com"
        case .qwen: "https://dashscope-us.aliyuncs.com/compatible-mode/v1"
        case .custom: ""
        }
    }
    var model: String {
        switch self {
        case .openai: "gpt-4.1-mini"
        case .gemini: "gemini-3.8-flash"
        case .anthropic: "claude-sonnet-5-5"
        case .deepseek: "deepseek-flash"
        case .qwen: "qwen-plus"
        case .custom: ""
        }
    }
    var supportsImages: Bool { self == .openai || self == .gemini }
    var imageModel: String { self == .gemini ? "gemini-3.1-flash-image" : "gpt-image-2.5-flare" }
    var privacyURL: URL {
        let address = switch self {
        case .openai: "https://openai.com/policies/privacy-policy/"
        case .gemini: "https://ai.google.dev/gemini-api/terms"
        case .anthropic: "https://www.anthropic.com/legal/privacy"
        case .deepseek: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html"
        case .qwen: "https://www.alibabacloud.com/help/en/legal/latest/alibaba-cloud-international-website-privacy-policy"
        case .custom: "https://wliao78.github.io/AI-Wardrobe-Support/"
        }
        return URL(string: address)!
    }
}

struct AIConfiguration: Codable, Sendable, Equatable {
    var provider: AIProvider = .openai
    var endpoint = AIProvider.openai.endpoint
    var model = AIProvider.openai.model
    var imageModel = AIProvider.openai.imageModel
    var textConsent = false
    var photoConsent = false
    var approvedEndpoint = ""
    var validTextConsent: Bool { textConsent && approvedEndpoint == endpoint }
    var validPhotoConsent: Bool { photoConsent && validTextConsent }
    static var current: Self {
        guard let data = UserDefaults.standard.data(forKey: "publicAIConfiguration"),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "publicAIConfiguration") }
    static func eraseAll() throws {
        for provider in AIProvider.allCases { try KeyVault.save("", provider: provider) }
        UserDefaults.standard.removeObject(forKey: "publicAIConfiguration")
    }
}

enum KeyVault {
    private static func query(_ provider: AIProvider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.aiwardrobe.public.keys",
         kSecAttrAccount as String: provider.rawValue]
    }
    static func read(_ provider: AIProvider) -> String {
        var query = query(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ key: String, provider: AIProvider) throws {
        let query = query(provider)
        if key.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AIError.keyStorage }
            return
        }
        let update = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw AIError.keyStorage }
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AIError.keyStorage }
    }
}

enum AIError: LocalizedError {
    case configuration, consent, photoConsent, invalidResponse, unsupported, keyStorage, http(Int)
    var errorDescription: String? {
        switch self {
        case .configuration: L("configureAI")
        case .consent: L("needTextConsent")
        case .photoConsent: L("needPhotoConsent")
        case .invalidResponse: L("invalidAIResponse")
        case .unsupported: L("imageUnsupported")
        case .keyStorage: L("keyStorageError")
        case .http(let code): "\(L("serviceError")) (\(code))"
        }
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

struct AIClient: Sendable {
    let configuration: AIConfiguration
    let key: String
    var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()

    func validateEndpoint() throws -> URL {
        guard let url = URL(string: configuration.endpoint), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !configuration.model.isEmpty else { throw AIError.configuration }
        if configuration.provider == .qwen {
            guard host.hasSuffix(".aliyuncs.com") else { throw AIError.configuration }
        } else if configuration.provider != .custom && configuration.endpoint != configuration.provider.endpoint {
            throw AIError.configuration
        }
        return url
    }

    func text(_ prompt: String, system: String, testOnly: Bool = false) async throws -> String {
        guard testOnly || configuration.validTextConsent else { throw AIError.consent }
        let base = try validateEndpoint()
        let claude = configuration.provider == .anthropic
        var request = URLRequest(url: base.appending(path: claude ? "messages" : "chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["model": configuration.model]
        // A connection test has a fixed synthetic payload and never contains user content.
        let userText = testOnly ? "Reply with OK." : prompt
        let instruction = testOnly ? "This is a connection test." : system
        if claude {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            payload["max_tokens"] = testOnly ? 32 : 1200
            payload["system"] = instruction
            payload["messages"] = [["role": "user", "content": userText]]
        } else {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            payload["messages"] = [["role": "system", "content": instruction], ["role": "user", "content": userText]]
            if configuration.provider == .openai { payload["store"] = false }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let json = try await send(request)
        if claude, let content = json["content"] as? [[String: Any]],
           let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String { return text }
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any], let text = message["content"] as? String { return text }
        throw AIError.invalidResponse
    }

    func image(person: Data, garments: [Data]) async throws -> Data {
        guard configuration.validPhotoConsent else { throw AIError.photoConsent }
        guard configuration.provider.supportsImages else { throw AIError.unsupported }
        let base = try validateEndpoint()
        let prompt = "Create a photorealistic full-body fashion try-on. First image is the person: preserve their identity, body proportions, pose, face and background. Remaining images are garments: dress this person in exactly those garments, preserving color, cut, sleeves and details. Replace previous clothes completely; no duplicate sleeves. Keep head and shoes fully in frame. No words. This is a visual approximation, not a measurement."
        var request: URLRequest
        if configuration.provider == .gemini {
            let model = configuration.imageModel
            guard model.range(of: "^[a-zA-Z0-9._-]+$", options: .regularExpression) != nil else { throw AIError.configuration }
            request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let parts: [[String: Any]] = [["text": prompt]] + ([person] + garments).map { ["inline_data": ["mime_type": "image/jpeg", "data": $0.base64EncodedString()]] }
            request.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["parts": parts]], "generationConfig": ["responseModalities": ["TEXT", "IMAGE"], "imageConfig": ["aspectRatio": "2:3"]]])
        } else {
            request = URLRequest(url: base.appending(path: "images/edits"))
            let boundary = UUID().uuidString
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            func append(_ s: String) { body.append(Data(s.utf8)) }
            for (name, value) in [("model", configuration.imageModel), ("prompt", prompt), ("size", "1024x1536")] {
                append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
            }
            for (i, image) in ([person] + garments).enumerated() {
                append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image[]\"; filename=\"photo\(i).jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
                body.append(image); append("\r\n")
            }
            append("--\(boundary)--\r\n"); request.httpBody = body
        }
        request.httpMethod = "POST"; request.timeoutInterval = 180
        let json = try await send(request)
        if configuration.provider == .gemini,
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any],
                   let encoded = inline["data"] as? String { return try Self.decodedImage(encoded) }
            }
        }
        if let images = json["data"] as? [[String: Any]], let encoded = images.first?["b64_json"] as? String {
            return try Self.decodedImage(encoded)
        }
        throw AIError.invalidResponse
    }

    static func decodedImage(_ encoded: String) throws -> Data {
        // A valid Base64 string is not necessarily a displayable photograph.
        // Reject malformed or unreasonably large images before saving a look.
        guard encoded.utf8.count <= 40_000_000,
              let data = Data(base64Encoded: encoded), !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 12_000, height <= 12_000,
              width * height <= 24_000_000,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw AIError.invalidResponse }
        return data
    }

    private func send(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw AIError.http(response.statusCode) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AIError.invalidResponse }
        return json
    }
}
