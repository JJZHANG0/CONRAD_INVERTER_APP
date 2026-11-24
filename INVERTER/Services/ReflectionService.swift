import Foundation

struct ReflectionTurn: Codable {
    var role: String
    var content: String
}
struct ReflectionRequest: Codable {
    var turns: [ReflectionTurn]
    var locale: String
    var nextFocus: String
}
struct ReflectionResponse: Codable { var question: String }
protocol ReflectionService {
    func nextQuestion(turns: [ReflectionTurn], endpoint: URL) async throws -> String
}
/// Uses the same authenticated model gateway as reports and insights.
struct BackendReflectionService: ReflectionService {
    func nextQuestion(turns: [ReflectionTurn], endpoint: URL) async throws -> String {
        let api = try CloudService(endpoint: endpoint.absoluteString)
        let focus = ["feeling", "interpretation", "need", "action"][min(max(turns.filter { $0.role == "user" }.count - 1, 0), 3)]
        let payload = ReflectionRequest(turns: turns, locale: AppPreferences.shared.language, nextFocus: focus)
        let data = try await api.request(path: "api/v1/inverter/reflections/next", encodedBody: JSONEncoder().encode(payload), authenticated: true)
        let answer = try JSONDecoder().decode(ReflectionResponse.self, from: data).question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, answer.count <= 1200 else { throw CloudError.invalidResponse }
        return answer
    }
}
