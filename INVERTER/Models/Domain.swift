import Foundation

struct UserProfile: Codable {
    var name = L("探索者")
    var intention = L("多一点理解，少一点预设。")
}

enum Emotion: String, CaseIterable, Codable, Identifiable {
    case calm = "平静", happy = "愉悦", hopeful = "期待", tired = "疲惫", anxious = "焦虑", sad = "失落"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .calm: "water.waves"
        case .happy: "sun.max"
        case .hopeful: "sparkle"
        case .tired: "moon.zzz"
        case .anxious: "wind"
        case .sad: "cloud.drizzle"
        }
    }
    // Self-reported feeling, never a clinical score.
    var plotValue: Double {
        switch self {
        case .happy: 3
        case .hopeful: 2
        case .calm: 1
        case .tired: -1
        case .anxious: -2
        case .sad: -3
        }
    }
}

enum RelationGroup: String, CaseIterable, Codable, Identifiable {
    case friend = "好友", family = "家人", partner = "伴侣", colleague = "同事", classmate = "同学", collaborator = "合作伙伴", other = "其他", uncategorized = "未分类"
    var id: String { rawValue }
}

struct Person: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var group: RelationGroup
    var note: String = ""
    var createdAt = Date()
    var isDemo = false
    // Optional for backward-compatible decoding of existing private archives.
    var spherePosition: SpherePosition? = nil
    var birthday: PersonBirthday? = nil
    var likes: String? = nil
    var dislikes: String? = nil
    var careNotes: String? = nil
    var organization: String? = nil
    var avatarData: Data? = nil
    var contactIdentifier: String? = nil
    var closeness: ConnectionCloseness? = nil
    var initials: String { String(name.prefix(1)) }
}

struct Relationship: Identifiable, Codable {
    var id = UUID()
    var personID: UUID
    var otherPersonID: UUID? // nil means the user
    var description: String
    var confirmedAt = Date()
}

struct LifeEvent: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var title: String
    var facts: String
    var feeling: Emotion
    var interpretation: String
    var need: String
    var nextStep: String
    var unknown = L("他人的真实想法，以及尚未核实的信息。")
    var personIDs: [UUID] = []
    var imageData: Data?
    var isFavorite = false
    var isDemo = false
    var correctedAt: Date?
}

enum MemoryKind: String, CaseIterable, Codable, Identifiable {
    case fact = "明确表达", feeling = "个人感受", interpretation = "个人解释", hypothesis = "待核对假设", correction = "已修正"
    var id: String { rawValue }
}

struct Memory: Identifiable, Codable {
    var id = UUID()
    var text: String
    var kind: MemoryKind
    var eventID: UUID?
    var gameResultID: UUID?
    var date = Date()
    var isDemo = false
}

struct Insight: Identifiable {
    var id: String
    var title: String
    var detail: String
    var evidenceIDs: [UUID]
    var isDemo: Bool
}

struct GameResult: Identifiable, Codable {
    var id = UUID()
    var gameID: String
    var date = Date()
    var answers: [String]
    var reflection: String
    var eventID: UUID?
}

struct ActionFeedback: Identifiable, Codable {
    var id = UUID()
    var taskID: Int
    var date = Date()
    var text: String
}

struct Challenge: Codable {
    var month = Date().formatted(.dateTime.year().month())
    var themeIndex = 0
    var completed: [Int] = []
    var feedback: [ActionFeedback] = []
    var skipped = false
    static var themes: [String] { [L("表达真实需求"), L("为自己留一点空间"), L("认真听见彼此")] }
    static var tasks: [[String]] { [
        [L("察觉一次没有说出口的需求"), L("写下你真正想表达的话"), L("在合适的时刻，表达一次"), L("回顾表达之后的感受")],
        [L("留意一件让你消耗的事"), L("给自己留出十分钟"), L("温和地拒绝一次额外请求"), L("记录边界带来的变化")],
        [L("想起一个想要了解的人"), L("提出一个开放的问题"), L("听完之后再表达自己的理解"), L("记下一个新的发现")]
    ] }
    var title: String { Self.themes[themeIndex % Self.themes.count] }
    var tasks: [String] { Self.tasks[themeIndex % Self.tasks.count] }
}

struct PrivacySettings: Codable {
    var saveFacts = false
    var saveFeelings = false
    var saveGameResults = false
    var allowCloud = false
    var endpoint = CloudService.productionURL
}

struct AppData: Codable {
    var schemaVersion = 1
    var firstLook: FirstLookState? = nil
    var conversationReports: [CompanionReport]? = nil
    var profile = UserProfile()
    var events: [LifeEvent] = []
    var people: [Person] = []
    var relationships: [Relationship] = []
    var memories: [Memory] = []
    var gameResults: [GameResult] = []
    var challenge = Challenge()
    var privacy = PrivacySettings()
    var showDemo = true
}
