import Foundation

struct FirstLookAIRequest: Encodable {
    let answers: [String: String]
    let language: String
    let questionVersion = "first-look-v1"
}
struct FirstLookAIResponse: Codable {
    let title: String
    let paragraph: String
    let invitation: String
    let evidenceQuestionIDs: [String]
}
@MainActor struct FirstLookService {
    let api: CloudService
    func generate(answers: [String: String], language: String) async throws -> FirstLookAIResponse {
        guard FirstLookComposer.isComplete(answers), ["en", "zh"].contains(language) else { throw CloudError.invalidResponse }
        let body = try JSONEncoder().encode(FirstLookAIRequest(answers: answers, language: language))
        let data = try await api.request(path: "api/v1/inverter/first-look", encodedBody: body, authenticated: true)
        let response = try JSONDecoder().decode(FirstLookAIResponse.self, from: data)
        let validIDs = Set(FirstLookQuestion.all.map(\.id))
        guard !response.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, response.title.count <= 100,
              !response.paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, response.paragraph.count <= 2400,
              !response.invitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, response.invitation.count <= 180,
              response.evidenceQuestionIDs.count >= 2, Set(response.evidenceQuestionIDs).count == response.evidenceQuestionIDs.count,
              Set(response.evidenceQuestionIDs).isSubset(of: validIDs) else { throw CloudError.invalidResponse }
        return response
    }
}
