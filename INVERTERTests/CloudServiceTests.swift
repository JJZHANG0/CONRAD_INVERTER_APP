import Foundation
import Testing
@testable import INVERTER

private final class CloudURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    nonisolated override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    nonisolated override func stopLoading() {}
}

@Suite(.serialized) @MainActor
struct CloudServiceTests {
    private func api() throws -> CloudService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CloudURLProtocol.self]
        return try CloudService(endpoint: "https://inverter-test.invalid", session: URLSession(configuration: configuration))
    }
    @Test func rejectsUnsafeEndpoints() {
        for endpoint in ["http://example.com", "https://user:password@example.com", "https://example.com?token=x", "https://example.com#fragment"] {
            #expect(throws: CloudError.self) { _ = try CloudService(endpoint: endpoint) }
        }
    }
    @Test func analysisRequiresLoginBeforeAnyNetworkRequest() async throws {
        let api = try api(); SessionVault.delete(api.origin)
        CloudURLProtocol.handler = { _ in Issue.record("Unauthorized request must not be sent"); return (500, Data()) }
        await #expect(throws: CloudError.self) { _ = try await api.analyze("Test text") }
    }
    @Test func smsContractAndTokenExpiry() async throws {
        let api = try api(); defer { SessionVault.delete(api.origin) }
        CloudURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/phone/code")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.httpMethod == "POST")
            return (202, Data(#"{"message":"sent"}"#.utf8))
        }
        try await api.sendCode(phone: "13800000000") // Intercepted locally; never sends an SMS.
        CloudURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/auth/phone/login")
            return (200, Data(#"{"access_token":"test-only","expires_in_seconds":3600}"#.utf8))
        }
        try await api.signIn(phone: "13800000000", code: "123456")
        #expect(api.signedIn)
        #expect(SessionVault.read(api.origin)?.token == "test-only")
        try SessionVault.save(StoredSession(token: "expired", expiresAt: .distantPast), origin: api.origin)
        #expect(!api.signedIn)
    }
    @Test func analysisDecodesRealContractAndClearsRejectedSession() async throws {
        let api = try api(); defer { SessionVault.delete(api.origin) }
        try SessionVault.save(StoredSession(token: "test-only", expiresAt: Date().addingTimeInterval(60)), origin: api.origin)
        CloudURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/inverter/analysis")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
            return (200, Data(#"{"title":"A conversation","score":75,"reason":"I asked clearly.","brief_advice":"I can listen.","detailed_advice":"I can ask an open question."}"#.utf8))
        }
        let result = try await api.analyze("Synthetic test")
        #expect(result.briefAdvice == "I can listen.")
        CloudURLProtocol.handler = { _ in (401, Data()) }
        await #expect(throws: CloudError.self) { _ = try await api.analyze("Test") }
        #expect(!api.signedIn)
    }
    @Test func unavailableAIIsAnErrorNotGeneratedCopy() async throws {
        let api = try api(); defer { SessionVault.delete(api.origin) }
        try SessionVault.save(StoredSession(token: "test", expiresAt: Date().addingTimeInterval(60)), origin: api.origin)
        CloudURLProtocol.handler = { _ in (502, Data(#"{"error":{"code":"review_ai_connection_failed"}}"#.utf8)) }
        await #expect(throws: CloudError.self) { _ = try await api.analyze("Test") }
    }
    @Test func interpolatedUserContentIsNeverTranslatedOrReinterpreted() {
        let previous = AppPreferences.shared.language; defer { AppPreferences.shared.language = previous }
        AppPreferences.shared.language = "en"
        #expect(L("与 \("{0} 张三") 的一次经历") == "A moment with {0} 张三")
        #expect(Emotion.calm.label == "Calm")
        AppPreferences.shared.language = "zh"
        #expect(Emotion.calm.label == "平静")
        #expect(Emotion.calm.rawValue == "平静")
    }
}
