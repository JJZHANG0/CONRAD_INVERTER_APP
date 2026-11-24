import Foundation
import Testing
import UIKit
@testable import INVERTER

@MainActor struct CompanionReportTests {
    private func sample(_ language: String = "zh", long: Bool = false) -> CompanionReport {
        let zh = language == "zh"
        let summary = zh ? "你想让自己的想法被认真听见，又不希望关系因此变得紧张。这两种在意可以同时存在。你开始把原本藏起来的话说出口，也在试着给自己的需要一个位置。" : "You want your thoughts to be heard, while also caring about the relationship. Both wishes can coexist. Beginning to put your experience into words makes a little more room for your own needs."
        return CompanionReport(language: language, reflection: ConversationReflection(
            title: zh ? "你也可以，为自己留一点位置。" : "There is room for you, too.",
            summary: long ? String(repeating: summary, count: 5) : summary,
            pattern: zh ? "也许你有时会先照顾别人的感受，再问自己想要什么。这只是从这段对话里看见的一条线索，还需要更多真实的片刻来确认。" : "You may sometimes attend to others before asking what you need. This is one possibility from a brief exchange, not a conclusion about who you are.",
            strengths: zh ? "你愿意停下来辨认自己的感受，也尝试表达不同的想法。这份觉察和行动，都是已经发生的改变。" : "You paused to notice your feelings and put them into words. That willingness is a resource you can return to.",
            nextStep: zh ? "下一次想把话收回去时，可以先写下：此刻，我希望被听见的是哪一句？再决定是否向对方说出这一句。" : "Before holding a thought back, write one sentence you wish could be heard. Then decide whether, and when, to share it.",
            invitation: zh ? "不必一次说完，先让自己被自己听见。" : "You do not have to say everything at once.",
            evidence: ["This private source quote must not be on the poster."]))
    }
    @Test func followupAfterSafetyClosingKeepsValidHistory() {
        let messages = [CompanionMessage(role: "user", content: "I need help now."), CompanionMessage(role: "assistant", content: "An earlier question."), CompanionMessage(role: "assistant", content: "Let’s focus on your immediate safety."), CompanionMessage(role: "user", content: "I can contact someone.")]
        let turns = CompanionConversation.requestTurns(from: messages)
        #expect(turns.map(\.role) == ["user", "assistant", "user"])
        #expect(turns[1].content == "Let’s focus on your immediate safety.")
        #expect(messages.count == 4)
    }
    @Test func reportsPersistOnceAndLegacyArchivesStillOpen() throws {
        let url = URL.temporaryDirectory.appending(path: "companion-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url); let report = sample()
        #expect(store.keepConversationReport(report)); #expect(store.keepConversationReport(report))
        #expect(AppStore(fileURL: url).data.conversationReports == [report])
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppData())) as? [String: Any])
        old.removeValue(forKey: "conversationReports")
        #expect(try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: old)).conversationReports == nil)
    }
    @Test func failedArchiveDoesNotPretendToSaveReport() throws {
        let url = URL.temporaryDirectory.appending(path: "companion-block-\(UUID())")
        try Data("blocked".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url.appending(path: "data.json"))
        #expect(!store.keepConversationReport(sample())); #expect(store.data.conversationReports == nil)
    }
    @Test func bilingualPostersGrowToFitLongReports() throws {
        for language in ["zh", "en"] {
            let image = try #require(ConversationReportRenderer.render(sample(language)))
            let long = try #require(ConversationReportRenderer.render(sample(language, long: true)))
            #expect(image.cgImage?.width == 1170)
            #expect(long.size.height > image.size.height + 300)
            try image.pngData()?.write(to: URL.temporaryDirectory.appending(path: "conversation-preview-\(language).png"))
            try long.pngData()?.write(to: URL.temporaryDirectory.appending(path: "conversation-long-\(language).png"))
        }
    }
}
