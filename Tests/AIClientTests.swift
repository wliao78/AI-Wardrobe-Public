import Foundation

let imageFixture = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="

func L(_ key: String) -> String { key }

final class RecordedRequests: @unchecked Sendable {
    let lock = NSLock()
    private var values: [URLRequest] = []
    func append(_ value: URLRequest) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    var last: URLRequest? { lock.lock(); defer { lock.unlock() }; return values.last }
    var count: Int { lock.lock(); defer { lock.unlock() }; return values.count }
}

final class MockProtocol: URLProtocol, @unchecked Sendable {
    static let requests = RecordedRequests()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let path = request.url!.path
        let body: String
        if path.hasSuffix("/messages") { body = "{\"content\":[{\"type\":\"text\",\"text\":\"OK\"}]}" }
        else if path.contains("generateContent") { body = "{\"candidates\":[{\"content\":{\"parts\":[{\"inlineData\":{\"data\":\"\(imageFixture)\"}}]}}]}" }
        else if path.hasSuffix("/images/edits") { body = "{\"data\":[{\"b64_json\":\"\(imageFixture)\"}]}" }
        else { body = "{\"choices\":[{\"message\":{\"content\":\"OK\"}}]}" }
        let status = request.value(forHTTPHeaderField: "Authorization") == "Bearer invalid" ? 401 : 200
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct AIClientTests {
    static func require(_ value: Bool, _ message: String) { precondition(value, message) }
    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var result = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; result.append(buffer, count: n) }
        return result
    }
    static func main() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        var config = AIConfiguration()
        let count = MockProtocol.requests.count
        do { _ = try await AIClient(configuration: config, key: "test", session: session).text("PRIVATE", system: "test"); fatalError("Missing consent gate") }
        catch AIError.consent {}
        require(MockProtocol.requests.count == count, "Request sent without consent")
        for provider in AIProvider.allCases {
            config = AIConfiguration(provider: provider, endpoint: provider == .custom ? "https://example.invalid/v1" : provider.endpoint, model: "test-model")
            config.textConsent = true; config.approvedEndpoint = config.endpoint
            let reply = try await AIClient(configuration: config, key: "test", session: session).text("wardrobe", system: "style")
            require(reply == "OK", "Response parser: \(provider)")
            let request = MockProtocol.requests.last!
            require(request.httpMethod == "POST", "Expected POST")
            if provider == .anthropic {
                require(request.url!.path.hasSuffix("/messages"), "Claude route")
                require(request.value(forHTTPHeaderField: "x-api-key") == "test", "Claude authentication")
            } else { require(request.url!.path.hasSuffix("/chat/completions"), "Compatible route") }
        }
        config = AIConfiguration()
        _ = try await AIClient(configuration: config, key: "test", session: session).text("PRIVATE", system: "PRIVATE", testOnly: true)
        let testBody = String(data: body(MockProtocol.requests.last!), encoding: .utf8)!
        require(!testBody.contains("PRIVATE") && testBody.contains("Reply with OK"), "Test leaked user content")
        for endpoint in ["http://example.com/v1", "https://user:pass@example.com/v1", "https://example.com/v1?token=x"] {
            config.provider = .custom; config.endpoint = endpoint
            do { _ = try AIClient(configuration: config, key: "test").validateEndpoint(); fatalError("Unsafe endpoint accepted") }
            catch AIError.configuration {}
        }
        for provider in [AIProvider.openai, .gemini] {
            config = AIConfiguration(provider: provider, endpoint: provider.endpoint, model: provider.model, imageModel: provider.imageModel)
            config.textConsent = true; config.approvedEndpoint = config.endpoint
            let client = AIClient(configuration: config, key: "test", session: session)
            do { _ = try await client.image(person: Data(), garments: []); fatalError("Photo gate missing") }
            catch AIError.photoConsent {}
            config.photoConsent = true
            let result = try await AIClient(configuration: config, key: "test", session: session).image(person: Data("person".utf8), garments: [Data("clothing".utf8)])
            require(result == Data(base64Encoded: imageFixture), "Image decoding")
            require(MockProtocol.requests.last?.url?.query == nil, "Key leaked in URL")
        }
        for invalid in ["", "%%%", Data("not an image".utf8).base64EncodedString()] {
            do { _ = try AIClient.decodedImage(invalid); fatalError("Malformed image accepted") }
            catch AIError.invalidResponse {}
        }
        config = AIConfiguration(); config.textConsent = true; config.approvedEndpoint = "https://old.example/v1"
        do { _ = try await AIClient(configuration: config, key: "test", session: session).text("private", system: "test"); fatalError("Endpoint consent not invalidated") }
        catch AIError.consent {}
        config.approvedEndpoint = config.endpoint
        do { _ = try await AIClient(configuration: config, key: "invalid", session: session).text("test", system: "test"); fatalError("401 not surfaced") }
        catch AIError.http(let code) { require(code == 401, "Unexpected error") }
        print("PASS: 6 provider adapters, 2 image adapters, consent gates, endpoint validation, synthetic test privacy and HTTP errors")
    }
}
