import Foundation
import Observation

struct CompanionMessage: Identifiable, Codable {
    var id = UUID()
    var role: String
    var content: String
}
struct ConversationReflection: Codable, Equatable {
    let title: String
    let summary: String
    let pattern: String
    let strengths: String
    let nextStep: String
    let invitation: String
    let evidence: [String]
}
struct CompanionReport: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var language: String
    var mode: CompanionMode? = nil
    var reflection: ConversationReflection
}
struct CompanionChatRequest: Codable { let messages: [ReflectionTurn]; let language: String; let action: String; var mode: CompanionMode = .understanding }
struct CompanionChatResponse: Codable {
    let mode: CompanionMode?
    let reply: String
    let stage: String?
    let complete: Bool?
    let safety: Bool?
    let report: ConversationReflection?
}
@MainActor @Observable final class CompanionConversation {
    private(set) var mode: CompanionMode = .understanding
    var messages: [CompanionMessage] = []
    var draft = ""
    var sending = false
    var failure: String?
    var stage = "connecting"
    var report: CompanionReport?
    var safety = false
    var lastAction = "start"
    private var requestTask: Task<Void, Never>?
    private var requestID = UUID()
    var needsReply: Bool { messages.last?.role == "user" }
    var userCount: Int { messages.filter { $0.role == "user" }.count }
    var stageTitle: String {
        switch stage {
        case "experience": L("回到那个片刻")
        case "meaning": L("听见你的在意")
        case "pattern": L("看见反复的线索")
        case "choice": L("留一个新的可能")
        case "closing": L("把理解带回生活")
        default: L("从此刻开始")
        }
    }
    func selectMode(_ selected: CompanionMode) {
        guard selected != mode else { return }
        reset(); mode = selected
    }
    func begin(api: CloudService) { if messages.isEmpty && !sending { request(api: api, action: "start") } }
    func send(api: CloudService) {
        guard !sending, report == nil else { return }
        if !needsReply {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 4000 else { return }
            messages.append(CompanionMessage(role: "user", content: text)); draft = ""
        }
        request(api: api, action: "reply")
    }
    func finish(api: CloudService) { if userCount > 0 && !sending { request(api: api, action: "finish") } }
    func retry(api: CloudService) { request(api: api, action: lastAction) }
    func reset() { cancel(); messages = []; draft = ""; failure = nil; report = nil; safety = false; stage = "connecting" }
    /// A finish request may return a safety response after an assistant question.
    /// Keep the latest guidance in the request while preserving the full UI transcript.
    static func requestTurns(from messages: [CompanionMessage]) -> [CompanionMessage] {
        var turns: [CompanionMessage] = []
        for message in messages {
            if turns.last?.role == message.role { turns[turns.count - 1] = message }
            else { turns.append(message) }
        }
        turns = Array(turns.suffix(41))
        while turns.reduce(0, { $0 + $1.content.count }) > 36000 && turns.count > 2 { turns.removeFirst(2) }
        return turns
    }
    private func request(api: CloudService, action: String) {
        guard !sending else { return }
        let turns = Self.requestTurns(from: messages)
        let payload = CompanionChatRequest(messages: turns.map { ReflectionTurn(role: $0.role, content: $0.content) }, language: AppPreferences.shared.language, action: action, mode: mode)
        sending = true; failure = nil; lastAction = action
        let id = UUID(); requestID = id
        requestTask = Task {
            do {
                let data = try await api.request(path: "api/v1/inverter/chat", encodedBody: JSONEncoder().encode(payload), authenticated: true)
                try Task.checkCancellation()
                guard requestID == id else { return }
                let response = try JSONDecoder().decode(CompanionChatResponse.self, from: data)
                guard response.mode == payload.mode, !response.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, response.reply.count <= 6000 else { throw CloudError.invalidResponse }
                if response.complete == true {
                    guard let reflection = response.report, !reflection.title.isEmpty, !reflection.summary.isEmpty, !reflection.evidence.isEmpty,
                          reflection.evidence.allSatisfy({ quote in !quote.isEmpty && turns.contains { $0.role == "user" && $0.content.contains(quote) } }) else { throw CloudError.invalidResponse }
                    report = CompanionReport(language: payload.language, mode: payload.mode, reflection: reflection)
                }
                stage = response.stage ?? "experience"; safety = response.safety ?? false
                messages.append(CompanionMessage(role: "assistant", content: response.reply))
            } catch { if !Task.isCancelled && requestID == id { failure = L("这一句暂时没有收到回应。你的话还在，可以再试一次。") } }
            if !Task.isCancelled && requestID == id { sending = false }
        }
    }
    func cancel() {
        requestID = UUID(); requestTask?.cancel(); requestTask = nil
        if sending { failure = L("这一句暂时没有收到回应。你的话还在，可以再试一次。") }
        sending = false
    }
}
extension AppStore {
    @discardableResult func keepConversationReport(_ report: CompanionReport) -> Bool {
        if data.conversationReports?.contains(where: { $0.id == report.id }) == true { return true }
        let previous = data.conversationReports
        data.conversationReports = [report] + (previous ?? [])
        if save() { return true }
        data.conversationReports = previous; return false
    }
}
