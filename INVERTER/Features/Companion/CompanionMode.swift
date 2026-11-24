import SwiftUI

/// Stable wire IDs; each mode is a distinct server-owned guidance contract.
enum CompanionMode: String, Codable, CaseIterable, Identifiable {
    case emotions, relationships, understanding, action
    var id: String { rawValue }
    var title: String {
        switch self {
        case .emotions: L("情绪梳理")
        case .relationships: L("关系边界")
        case .understanding: L("自我理解")
        case .action: L("行动勇气")
        }
    }
    func title(language: String) -> String {
        switch self {
        case .emotions: language == "zh" ? "情绪梳理" : "Emotional clarity"
        case .relationships: language == "zh" ? "关系边界" : "Relationships"
        case .understanding: language == "zh" ? "自我理解" : "Self insight"
        case .action: language == "zh" ? "行动勇气" : "Courage to act"
        }
    }
    var detail: String {
        switch self {
        case .emotions: L("从一个具体片刻，听清感受与需要。")
        case .relationships: L("看清彼此的需要，找到自己的边界。")
        case .understanding: L("理解反复出现的反应，发现新的可能。")
        case .action: L("从困住你的顾虑，走向一个可行的小行动。")
        }
    }
    var color: Color {
        switch self {
        case .emotions: Color(red: 0.38, green: 0.68, blue: 0.83)
        case .relationships: Color(red: 0.85, green: 0.43, blue: 0.60)
        case .understanding: Color(red: 0.61, green: 0.52, blue: 0.78)
        case .action: Color(red: 0.80, green: 0.61, blue: 0.32)
        }
    }
}
