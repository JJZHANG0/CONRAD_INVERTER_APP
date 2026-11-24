import Foundation

struct FirstLookCopy: Codable {
    let zh: String
    let en: String
    var text: String { text(in: AppPreferences.shared.language) }
    func text(in language: String) -> String { language == "zh" ? zh : en }
}
struct FirstLookOption: Codable, Identifiable {
    let id: String
    let text: FirstLookCopy
    let echo: FirstLookCopy
}
struct FirstLookQuestion: Codable, Identifiable {
    let id: String
    let number: Int
    let question: FirstLookCopy
    let options: [FirstLookOption]
    static let all: [FirstLookQuestion] = {
        guard let url = Bundle.main.url(forResource: "FirstLookQuestions", withExtension: "json"),
              let data = try? Data(contentsOf: url), let questions = try? JSONDecoder().decode([Self].self, from: data), questions.count == 10 else { return [] }
        return questions
    }()
}
struct FirstLookState: Codable {
    var answers: [String: String] = [:]
    var currentIndex = 0
    var deferred = false
    var isRetaking = false
    var report: FirstLookReport?
}
struct FirstLookReport: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var language: String
    var title: String
    var paragraph: String
    var invitation: String
    var source: String // "local" or "ai", retained in every exported image
    var evidenceQuestionIDs: [String]
    var answers: [String: String]
    var promptVersion = "first-look-v1"
}

@MainActor enum FirstLookComposer {
    static func isComplete(_ answers: [String: String]) -> Bool {
        answers.count == 10 && FirstLookQuestion.all.count == 10 && FirstLookQuestion.all.allSatisfy { q in q.options.contains { $0.id == answers[q.id] } }
    }
    static func makeReport(answers: [String: String], language: String) -> FirstLookReport? {
        guard isComplete(answers) else { return nil }
        func choice(_ id: String) -> FirstLookOption {
            let question = FirstLookQuestion.all.first { $0.id == id }!
            return question.options.first { $0.id == answers[id] }!
        }
        let titles: [String: (String, String)] = [
            "effort": ("你说，你已经很努力了。\n这句话值得被听见。", "You have been trying.\nLet that be heard."),
            "need": ("你也可以，\n是被照顾的那个人。", "Care can be\nsomething you receive, too."),
            "pace": ("你的节奏，\n也值得被认真对待。", "Your own pace\ndeserves a little room."),
            "real": ("你不必把自己解释完，\n才值得被理解。", "You do not have to explain\nevery part of yourself to be heard.")
        ]
        let selectedTitle = titles[answers["seen"]!]!
        let title = language == "zh" ? selectedTitle.0 : selectedTitle.1
        let seen = choice("seen").text.text(in: language).trimmingCharacters(in: CharacterSet(charactersIn: "“”。. "))
        let paragraph: String
        if language == "zh" {
            paragraph = "在这十个选择里，你让我们看见了一些此刻的自己。你选择了“\(seen)”，也选择了\(choice("unseen").text.zh)——也许这两句话之间，就藏着你最近想留给自己的一点空间。\(choice("closeness").echo.zh)。而\(choice("needs").echo.zh)。这些选择不需要拼成一个永远正确的你，它们只是提醒：你如何靠近别人，和你希望怎样被对待，都值得被认真听见。今天，\(choice("invitation").echo.zh)，不必一次做到很多。"
        } else {
            paragraph = "These ten choices offer a glimpse of you today. One answer was “\(seen).” You would also allow yourself to \(choice("unseen").text.en.prefix(1).lowercased() + choice("unseen").text.en.dropFirst()). Perhaps there is a little space you have been hoping to make between those two thoughts. \(choice("closeness").echo.en). \(choice("needs").echo.en). Your choices do not have to form one permanent version of you. How you reach toward others, and how you hope to be met, both deserve to be heard. Today, \(choice("invitation").echo.en.prefix(1).lowercased() + choice("invitation").echo.en.dropFirst()). One small moment is enough."
        }
        return FirstLookReport(language: language, title: title, paragraph: paragraph, invitation: choice("invitation").echo.text(in: language), source: "local", evidenceQuestionIDs: ["seen", "unseen", "closeness", "needs", "invitation"], answers: answers)
    }
}

extension AppStore {
    @discardableResult func updateFirstLook(_ value: FirstLookState) -> Bool {
        let previous = data.firstLook
        data.firstLook = value
        guard save() else { data.firstLook = previous; return false }
        return true
    }
    @discardableResult func answerFirstLook(question: FirstLookQuestion, option: FirstLookOption) -> Bool {
        guard question.options.contains(where: { $0.id == option.id }) else { return false }
        var state = data.firstLook ?? FirstLookState()
        state.answers[question.id] = option.id
        state.currentIndex = question.number - 1
        return updateFirstLook(state)
    }
}
