import Foundation
import SwiftUI
import UIKit

/// Gregorian month/day, with an optional birth year; unknown years stay unknown.
struct PersonBirthday: Codable, Hashable {
    var month: Int
    var day: Int
    var year: Int?
    var isValid: Bool {
        guard (1...12).contains(month), (1...31).contains(day), year == nil || (1...9999).contains(year!) else { return false }
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year ?? 2000, month: month, day: day)) else { return false }
        let result = calendar.dateComponents([.year, .month, .day], from: date)
        return result.year == (year ?? 2000) && result.month == month && result.day == day
    }
    var formatted: String {
        guard isValid, let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year ?? 2000, month: month, day: day)) else { return "—" }
        let formatter = DateFormatter(); formatter.locale = AppPreferences.shared.locale; formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate(year == nil ? "MMMMd" : "yMMMMd")
        return formatter.string(from: date)
    }
    /// Conventional Western sun-sign date ranges; never used for psychological inference.
    var zodiac: String? {
        guard isValid else { return nil }
        switch month * 100 + day {
        case 120...218: return L("水瓶座")
        case 219...320: return L("双鱼座")
        case 321...419: return L("白羊座")
        case 420...520: return L("金牛座")
        case 521...621: return L("双子座")
        case 622...722: return L("巨蟹座")
        case 723...822: return L("狮子座")
        case 823...922: return L("处女座")
        case 923...1023: return L("天秤座")
        case 1024...1122: return L("天蝎座")
        case 1123...1221: return L("射手座")
        default: return L("摩羯座")
        }
    }
}

enum ConnectionCloseness: Int, CaseIterable, Codable, Identifiable {
    case distant, occasional, familiar, close, intimate
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .distant: L("较淡")
        case .occasional: L("偶有联系")
        case .familiar: L("熟悉")
        case .close: L("亲近")
        case .intimate: L("很亲密")
        }
    }
    var color: Color { Color(uiColor: uiColor) }
    var uiColor: UIColor {
        // Ice blue → lilac → vivid warm pink. Contrast adapts to light/dark backgrounds.
        let light: [(CGFloat, CGFloat, CGFloat)] = [(0.25,0.66,0.87),(0.38,0.60,0.88),(0.64,0.49,0.83),(0.89,0.35,0.65),(0.96,0.20,0.52)]
        let dark: [(CGFloat, CGFloat, CGFloat)] = [(0.47,0.82,1),(0.57,0.72,1),(0.76,0.64,0.98),(1,0.52,0.78),(1,0.32,0.65)]
        let index = rawValue
        return UIColor { traits in
            let rgb = (traits.userInterfaceStyle == .dark ? dark : light)[index]
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
}
