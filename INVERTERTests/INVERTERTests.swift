import Foundation
import Testing
@testable import INVERTER

@MainActor
struct INVERTERTests {
    private func makeStore() -> (AppStore, URL) {
        let url = URL.temporaryDirectory.appending(path: "inverter-test-\(UUID().uuidString)/store.json")
        let store = AppStore(fileURL: url)
        store.data.showDemo = false
        return (store, url)
    }
    private func event(personID: UUID? = nil, need: String = "清晰沟通") -> LifeEvent {
        LifeEvent(title: "测试经历", facts: "我主动提出调整分工。", feeling: .calm, interpretation: "清晰分工很重要。", need: need, nextStep: "下次提前确认。", personIDs: personID.map { [$0] } ?? [])
    }
    @Test func memoryRequiresBothCategoryAndPerEventConsent() {
        let (store, _) = makeStore()
        store.addEvent(event(), remember: true)
        #expect(store.data.memories.isEmpty)
        store.data.privacy.saveFacts = true
        store.addEvent(event(), remember: false)
        #expect(store.data.memories.isEmpty)
        store.addEvent(event(), remember: true)
        #expect(store.data.memories.count == 1)
        #expect(store.data.memories[0].kind == .fact)
        #expect(store.data.events.count == 3)
    }
    @Test func correctingEventInvalidatesMemoriesAndRecomputesEvidence() {
        let (store, _) = makeStore()
        store.data.privacy.saveFacts = true
        let original = event()
        store.addEvent(original, remember: true)
        store.addEvent(event(), remember: true)
        #expect(store.insights.count == 1)
        var correction = original
        correction.need = "独处"
        correction.facts = "修正后的事实"
        store.updateEvent(correction)
        #expect(store.insights.isEmpty)
        #expect(!store.data.memories.contains { $0.eventID == original.id })
        #expect(store.event(original.id)?.correctedAt != nil)
    }
    @Test func deletionCascadesWithoutRemovingUnrelatedHistory() {
        let (store, _) = makeStore()
        let person = Person(name: "朋友", group: .friend)
        store.addPerson(person)
        let record = event(personID: person.id)
        store.data.privacy.saveFacts = true
        store.addEvent(record, remember: true)
        store.saveGame(GameResult(gameID: "values", answers: ["自由"], reflection: "", eventID: record.id))
        store.deletePerson(person.id)
        #expect(store.data.events.count == 1)
        #expect(store.data.events[0].personIDs.isEmpty)
        #expect(store.data.relationships.isEmpty)
        store.deleteEvent(record.id)
        #expect(store.data.memories.isEmpty)
        #expect(store.data.gameResults[0].eventID == nil)
    }
    @Test func persistenceRoundTripAndDemoIsolation() {
        let (store, url) = makeStore()
        store.data.showDemo = true
        let exampleCount = store.events.count
        #expect(exampleCount > 0)
        #expect(store.data.events.isEmpty)
        let record = event()
        store.addEvent(record, remember: false)
        store.data.profile.name = "名字"
        store.save()
        let reopened = AppStore(fileURL: url)
        #expect(reopened.data.profile.name == "名字")
        #expect(reopened.data.events.count == 1)
        #expect(reopened.events.count == exampleCount + 1)
        reopened.data.showDemo = false
        #expect(reopened.events.map(\.id) == [record.id])
        reopened.eraseAll()
        #expect(AppStore(fileURL: url).events.isEmpty)
    }
    @Test func gameMemoryIsTemporaryInterpretationAndDeletionCascades() {
        let (store, _) = makeStore()
        store.data.privacy.saveGameResults = true
        let result = GameResult(gameID: "values", answers: ["自由", "公平"], reflection: "此刻我在意自由。")
        store.saveGame(result)
        #expect(store.data.memories.first?.kind == .interpretation)
        store.deleteGame(result.id)
        #expect(store.data.gameResults.isEmpty)
        #expect(store.data.memories.isEmpty)
    }
    @Test func challengeCompletionIsIdempotent() {
        let (store, _) = makeStore()
        store.completeTask(0, feedback: "已经尝试")
        store.completeTask(0, feedback: "再次点击")
        #expect(store.data.challenge.completed == [0])
        #expect(store.data.challenge.feedback.count == 1)
    }
    @Test func failedWriteDoesNotReportSuccessOrDuplicateRecords() throws {
        let parent = URL.temporaryDirectory.appending(path: "inverter-file-\(UUID().uuidString)")
        try Data("occupied".utf8).write(to: parent)
        let store = AppStore(fileURL: parent.appending(path: "store.json"))
        store.data.privacy.saveFacts = true
        #expect(!store.addEvent(event(), remember: true))
        #expect(store.data.events.isEmpty)
        #expect(store.data.memories.isEmpty)
        #expect(store.persistenceError != nil)
        let result = GameResult(gameID: "values", answers: ["自由"], reflection: "")
        #expect(!store.saveGame(result))
        #expect(store.data.gameResults.isEmpty)
    }
    @Test func corruptStoreDoesNotOverwriteOriginal() throws {
        let url = URL.temporaryDirectory.appending(path: "inverter-corrupt-\(UUID().uuidString).json")
        let bytes = Data("not-json".utf8)
        try bytes.write(to: url)
        let store = AppStore(fileURL: url)
        #expect(store.persistenceError != nil)
        store.addEvent(event(), remember: false)
        #expect(try Data(contentsOf: url) == bytes)
        store.eraseAll()
        #expect(AppStore(fileURL: url).persistenceError == nil)
    }
}
