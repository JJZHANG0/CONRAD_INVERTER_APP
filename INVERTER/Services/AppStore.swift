import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    var data: AppData
    var persistenceError: String?
    private let fileURL: URL
    private var canPersist = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory.appending(path: "INVERTER/private-space.json")
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: self.fileURL))
            } catch {
                data = AppData()
                canPersist = false
                persistenceError = L("本地档案暂时无法读取。原文件已保留，请先导出或备份文件后再重试，避免覆盖原有记录。")
            }
        } else {
            data = AppData()
        }
        let currentMonth = Date().formatted(.dateTime.year().month())
        if data.challenge.month != currentMonth {
            data.challenge = Challenge(month: currentMonth, themeIndex: data.challenge.themeIndex)
        }
    }

    var events: [LifeEvent] { (data.events + (data.showDemo ? DemoData.events : [])).sorted { $0.date > $1.date } }
    var people: [Person] { data.people + (data.showDemo ? DemoData.people : []) }
    var insights: [Insight] {
        // Only summarize explicit matching needs; do not invent a personality inference.
        let groups = Dictionary(grouping: events.filter { !$0.need.isEmpty }, by: { "\($0.isDemo)-\($0.need)" })
        return groups.values.filter { $0.count >= 2 }.map { records in
            let need = records[0].need
            return Insight(id: "\(records[0].isDemo)-\(need)", title: L("你不止一次提到「\(need)」"), detail: L("在 \(records.count) 次记录中，你明确写下了这一在意点。它在这些经历中对你意味着什么？"), evidenceIDs: records.map(\.id), isDemo: records[0].isDemo)
        }.sorted { $0.evidenceIDs.count > $1.evidenceIDs.count }
    }
    func event(_ id: UUID) -> LifeEvent? { events.first { $0.id == id } }
    func person(_ id: UUID) -> Person? { people.first { $0.id == id } }
    func events(for person: Person) -> [LifeEvent] { events.filter { $0.personIDs.contains(person.id) } }

    @discardableResult func save() -> Bool {
        guard canPersist else {
            persistenceError = L("本地档案无法读取，原文件已保留。请先备份，再通过隐私与数据页面清除损坏档案。")
            return false
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: [.atomic, .completeFileProtection])
            persistenceError = nil
            return true
        } catch {
            persistenceError = L("保存失败：\(error.localizedDescription)。请保留当前页面并重试。")
            return false
        }
    }

    @discardableResult func addEvent(_ event: LifeEvent, remember: Bool) -> Bool {
        let previous = data
        data.events.insert(event, at: 0)
        if remember {
            if data.privacy.saveFacts { data.memories.append(Memory(text: event.facts, kind: .fact, eventID: event.id)) }
            if data.privacy.saveFeelings { data.memories.append(Memory(text: "\(event.feeling.rawValue) · \(event.need)", kind: .feeling, eventID: event.id)) }
        }
        if save() { return true }
        data = previous
        return false
    }
    func updateEvent(_ event: LifeEvent) {
        guard let index = data.events.firstIndex(where: { $0.id == event.id }) else { return }
        var corrected = event
        corrected.correctedAt = Date()
        data.events[index] = corrected
        // Previously derived memories are invalidated, not silently retained as facts.
        data.memories.removeAll { $0.eventID == event.id }
        save()
    }
    func deleteEvent(_ id: UUID) {
        data.events.removeAll { $0.id == id }
        data.memories.removeAll { $0.eventID == id }
        for index in data.gameResults.indices where data.gameResults[index].eventID == id { data.gameResults[index].eventID = nil }
        save()
    }
    func toggleFavorite(_ id: UUID) {
        guard let index = data.events.firstIndex(where: { $0.id == id }) else { return }
        data.events[index].isFavorite.toggle()
        save()
    }
    @discardableResult func addPerson(_ person: Person) -> Bool {
        let previous = data
        data.people.append(person)
        data.relationships.append(Relationship(personID: person.id, description: person.group.rawValue))
        if save() { return true }; data = previous; return false
    }
    @discardableResult func updatePerson(_ person: Person) -> Bool {
        guard let index = data.people.firstIndex(where: { $0.id == person.id }) else { return false }
        let previous = data
        data.people[index] = person
        for index in data.relationships.indices where data.relationships[index].personID == person.id {
            data.relationships[index].description = person.group.rawValue
            data.relationships[index].confirmedAt = Date()
        }
        if save() { return true }; data = previous; return false
    }
    func deletePerson(_ id: UUID) {
        data.people.removeAll { $0.id == id }
        data.relationships.removeAll { $0.personID == id || $0.otherPersonID == id }
        for index in data.events.indices { data.events[index].personIDs.removeAll { $0 == id } }
        save()
    }
    @discardableResult func saveGame(_ result: GameResult) -> Bool {
        let previous = data
        data.gameResults.insert(result, at: 0)
        if data.privacy.saveGameResults {
            data.memories.append(Memory(text: L("本次探索（\(DiscoveryGame.title(for: result.gameID))）：\(result.answers.joined(separator: "；"))。\(result.reflection)"), kind: .interpretation, gameResultID: result.id))
        }
        if save() { return true }
        data = previous
        return false
    }
    func deleteGame(_ id: UUID) {
        data.gameResults.removeAll { $0.id == id }
        data.memories.removeAll { $0.gameResultID == id }
        save()
    }
    func completeTask(_ index: Int, feedback: String) {
        guard !data.challenge.completed.contains(index) else { return }
        data.challenge.completed.append(index)
        data.challenge.feedback.append(ActionFeedback(taskID: index, text: feedback))
        save()
    }
    func eraseAll() {
        // Explicit destructive action also recovers an unreadable local store.
        if let api = try? CloudService(endpoint: data.privacy.endpoint.isEmpty ? CloudService.productionURL : data.privacy.endpoint) { SessionVault.delete(api.origin) }
        canPersist = true
        data = AppData()
        data.showDemo = false
        persistenceError = nil
        save()
    }
}
