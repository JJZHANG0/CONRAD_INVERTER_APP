import Foundation
import Observation
import Security

@MainActor @Observable final class CloudSessionState {
    static let shared = CloudSessionState()
    var revision = 0
}

struct CloudToken: Codable {
    let accessToken: String
    let expiresInSeconds: Int
}
struct CloudAnalysis: Codable {
    let title: String
    let reason: String
    let briefAdvice: String
    let detailedAdvice: String
}
struct StoredSession: Codable {
    var token: String
    var expiresAt: Date
}

/// A separate, origin-scoped Keychain item; never part of the exported private archive.
@MainActor enum SessionVault {
    private static func query(_ origin: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "IKOOTECH.INVERTER.session", kSecAttrAccount as String: origin]
    }
    static func read(_ origin: String) -> StoredSession? {
        var query = query(origin); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }
    static func save(_ session: StoredSession, origin: String) throws {
        let data = try JSONEncoder().encode(session)
        defer { CloudSessionState.shared.revision += 1 }
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query(origin) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(origin); attributes.forEach { item[$0.key] = $0.value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CloudError.secureStorage }
        } else if status != errSecSuccess { throw CloudError.secureStorage }
    }
    static func delete(_ origin: String) { SecItemDelete(query(origin) as CFDictionary); CloudSessionState.shared.revision += 1 }
}

enum CloudError: LocalizedError {
    case invalidAddress, signIn, rejected(Int), unavailable, invalidResponse, secureStorage
    var errorDescription: String? {
        switch self {
        case .invalidAddress: localizedServiceError("请输入有效的 HTTPS 服务地址。")
        case .signIn: localizedServiceError("请先登录；登录过期后需要重新验证。")
        case .rejected(let code): code == 429 ? localizedServiceError("请求太频繁，请稍后再试。") : code == 400 || code == 422 ? localizedServiceError("请检查手机号、验证码或输入内容后重试。") : localizedServiceError("服务暂时不可用，请稍后重试。")
        case .unavailable: localizedServiceError("无法连接服务，请检查网络后重试。")
        case .invalidResponse: localizedServiceError("服务返回的内容无法读取，请重试。")
        case .secureStorage: localizedServiceError("无法安全保存登录状态，请解锁设备后重试。")
        }
    }
}

@MainActor struct CloudService {
    nonisolated static var productionURL: String {
        #if DEBUG
        if UITestCloudTransport.enabled { return "https://inverter-uitest.invalid" }
        #endif
        return "https://47-76-244-254.sslip.io"
    }
    let baseURL: URL
    private static let transport: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: CloudRedirectPolicy(), delegateQueue: nil)
    }()
    var session: URLSession
    var origin: String { baseURL.absoluteString }
    init(endpoint: String = productionURL, session: URLSession? = nil) throws {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { throw CloudError.invalidAddress }
        // Upgrade only the previous built-in origin, never a user-supplied custom server.
        let legacyOrigin = "https://8-146-228-143.sslip.io"
        baseURL = endpoint.trimmingCharacters(in: .whitespacesAndNewlines) == legacyOrigin ? URL(string: Self.productionURL)! : url
        if baseURL.absoluteString == Self.productionURL, SessionVault.read(baseURL.absoluteString) == nil,
           let previous = SessionVault.read(legacyOrigin), previous.expiresAt > Date() {
            try SessionVault.save(previous, origin: baseURL.absoluteString)
        }
        #if DEBUG
        self.session = session ?? (UITestCloudTransport.enabled ? UITestCloudTransport.session() : Self.transport)
        #else
        self.session = session ?? Self.transport
        #endif
    }
    func request(path: String, body: [String: String]? = nil, encodedBody: Data? = nil, authenticated: Bool = false) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = body == nil && encodedBody == nil ? "GET" : "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        if let encodedBody { request.httpBody = encodedBody }
        if authenticated {
            guard let stored = SessionVault.read(origin), stored.expiresAt > Date() else { throw CloudError.signIn }
            request.setValue("Bearer \(stored.token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { if Task.isCancelled { throw CancellationError() }; throw CloudError.unavailable }
        guard let http = response as? HTTPURLResponse else { throw CloudError.invalidResponse }
        if http.statusCode == 401 { SessionVault.delete(origin); throw CloudError.signIn }
        guard (200..<300).contains(http.statusCode) else { throw CloudError.rejected(http.statusCode) }
        return data
    }
    func sendCode(phone: String) async throws { _ = try await request(path: "api/v1/auth/phone/code", body: ["phone_number": phone]) }
    func signIn(phone: String, code: String) async throws {
        let data = try await request(path: "api/v1/auth/phone/login", body: ["phone_number": phone, "code": code])
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(CloudToken.self, from: data)
        guard !response.accessToken.isEmpty, response.expiresInSeconds > 0 else { throw CloudError.invalidResponse }
        try SessionVault.save(StoredSession(token: response.accessToken, expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresInSeconds))), origin: origin)
    }
    func analyze(_ text: String, purpose: String = "reflection") async throws -> CloudAnalysis {
        let data = try await request(path: "api/v1/inverter/analysis", body: ["purpose": purpose, "transcript": text, "language": AppPreferences.shared.language], authenticated: true)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let answer = try? decoder.decode(CloudAnalysis.self, from: data),
              [answer.title, answer.reason, answer.briefAdvice, answer.detailedAdvice].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              answer.title.count <= 120, answer.reason.count <= 4000, answer.briefAdvice.count <= 1000, answer.detailedAdvice.count <= 6000 else { throw CloudError.invalidResponse }
        return answer
    }
    var signedIn: Bool {
        _ = CloudSessionState.shared.revision
        return (SessionVault.read(origin)?.expiresAt ?? .distantPast) > Date() }
}

private final class CloudRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward login payloads or bearer tokens to a redirect target.
        completionHandler(nil)
    }
}
