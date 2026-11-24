import Foundation
import Testing
import UIKit
@testable import INVERTER

@MainActor struct FirstLookTests {
    private func answers(_ offset: Int = 0) -> [String: String] {
        Dictionary(uniqueKeysWithValues: FirstLookQuestion.all.map { ($0.id, $0.options[offset].id) })
    }
    @Test func tenQuestionsHaveStableUniqueBilingualChoices() {
        #expect(FirstLookQuestion.all.count == 10)
        #expect(Set(FirstLookQuestion.all.map(\.id)).count == 10)
        #expect(FirstLookQuestion.all.map(\.number) == Array(1...10))
        for q in FirstLookQuestion.all {
            #expect(q.options.count == 4)
            #expect(Set(q.options.map(\.id)).count == 4)
            #expect(!q.question.en.isEmpty && !q.question.zh.isEmpty)
            #expect(q.options.allSatisfy { !$0.text.en.isEmpty && !$0.text.zh.isEmpty })
        }
    }
    @Test func incompleteOrUnknownAnswersCannotProduceAReport() {
        var draft = answers(); draft.removeValue(forKey: "arrival")
        #expect(FirstLookComposer.makeReport(answers: draft, language: "en") == nil)
        draft = answers(); draft["arrival"] = "invented"
        #expect(!FirstLookComposer.isComplete(draft))
        draft = answers(); draft["unknown"] = "extra"
        #expect(!FirstLookComposer.isComplete(draft))
    }
    @Test func changedChoicesChangeReportWithoutChangingSourceData() throws {
        let first = try #require(FirstLookComposer.makeReport(answers: answers(), language: "zh"))
        let second = try #require(FirstLookComposer.makeReport(answers: answers(2), language: "zh"))
        #expect(first.paragraph != second.paragraph)
        #expect(first.source == "local")
        #expect(first.answers == answers())
        #expect(first.evidenceQuestionIDs.allSatisfy { first.answers[$0] != nil })
    }
    @Test func draftsReportsAndDeferralSurviveReloadAndLegacyArchivesDecode() throws {
        let url = URL.temporaryDirectory.appending(path: "firstlook-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        let q = try #require(FirstLookQuestion.all.first)
        #expect(store.answerFirstLook(question: q, option: q.options[1]))
        let reopened = AppStore(fileURL: url)
        #expect(reopened.data.firstLook?.answers[q.id] == q.options[1].id)
        var state = FirstLookState(answers: answers(), currentIndex: 9, deferred: true)
        state.report = FirstLookComposer.makeReport(answers: answers(), language: "en")
        #expect(reopened.updateFirstLook(state))
        #expect(AppStore(fileURL: url).data.firstLook?.report == state.report)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppData())) as? [String: Any])
        legacy.removeValue(forKey: "firstLook")
        #expect(try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: legacy)).firstLook == nil)
    }
    @Test func failedSaveDoesNotFinishOnboardingOrReplaceReport() {
        let url = URL.temporaryDirectory.appending(path: "firstlook-unwritable-\(UUID())")
        try? Data("blocking file".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url.appending(path: "archive.json"))
        #expect(!store.updateFirstLook(FirstLookState(answers: answers(), deferred: true)))
        #expect(store.data.firstLook == nil)
    }
    @Test func reportImagesHaveExportResolutionInBothLanguages() throws {
        for language in ["en", "zh"] {
            let report = try #require(FirstLookComposer.makeReport(answers: answers(), language: language))
            let image = try #require(FirstLookImageRenderer.render(report))
            #expect(image.cgImage?.width == 1080)
            #expect((image.cgImage?.height ?? 0) > 1600)
            let png = try #require(image.pngData())
            try png.write(to: URL.temporaryDirectory.appending(path: "firstlook-preview-\(language).png"))
        }
    }
}
