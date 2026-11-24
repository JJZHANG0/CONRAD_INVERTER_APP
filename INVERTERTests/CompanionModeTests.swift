import Foundation
import Testing
@testable import INVERTER

@MainActor struct CompanionModeTests {
    @Test func requestCarriesModeAndLegacyReportsStillDecode() throws {
        for mode in CompanionMode.allCases {
            let request = CompanionChatRequest(messages: [], language: "en", action: "start", mode: mode)
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
            #expect(json["mode"] as? String == mode.rawValue)
        }
        let reflection = ConversationReflection(title: "A moment", summary: "A thought", pattern: "Perhaps", strengths: "Speaking", nextStep: "Pause", invitation: "Take time", evidence: ["A thought"])
        let legacy = CompanionReport(language: "en", reflection: reflection)
        let decoded = try JSONDecoder().decode(CompanionReport.self, from: JSONEncoder().encode(legacy))
        #expect(decoded.mode == nil)
        let modern = CompanionReport(language: "en", mode: .relationships, reflection: reflection)
        #expect(try JSONDecoder().decode(CompanionReport.self, from: JSONEncoder().encode(modern)).mode == .relationships)
    }
    @Test func switchingClearsOldContextButResetKeepsChosenMode() {
        let conversation = CompanionConversation()
        conversation.messages = [CompanionMessage(role: "user", content: "An old concern")]
        conversation.draft = "Unsent"; conversation.failure = "Failed"; conversation.safety = true
        conversation.selectMode(.action)
        #expect(conversation.mode == .action)
        #expect(conversation.messages.isEmpty && conversation.draft.isEmpty && conversation.failure == nil && !conversation.safety)
        conversation.reset()
        #expect(conversation.mode == .action)
        conversation.draft = "Keep this"
        conversation.selectMode(.action)
        #expect(conversation.draft == "Keep this")
    }
}
