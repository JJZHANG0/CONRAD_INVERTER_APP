import SwiftUI
import Observation

@MainActor @Observable
final class AppPreferences {
    static let shared = AppPreferences()
    var language: String { didSet { UserDefaults.standard.set(language, forKey: "app.language") } }
    var appearance: String { didSet { UserDefaults.standard.set(appearance, forKey: "app.appearance") } }
    var locale: Locale { Locale(identifier: language == "zh" ? "zh-Hans" : "en") }
    var colorScheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    private init() {
        let args = ProcessInfo.processInfo.arguments
        language = args.contains("--language=zh") ? "zh" : args.contains("--language=en") ? "en" : UserDefaults.standard.string(forKey: "app.language") ?? "en"
        appearance = args.contains("--appearance=dark") ? "dark" : args.contains("--appearance=light") ? "light" : UserDefaults.standard.string(forKey: "app.appearance") ?? "system"
        UserDefaults.standard.set(language, forKey: "app.language")
    }
}

/// Typed interpolation keeps user text out of the translation lookup and preserves argument order.
struct AppCopy: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    var key: String
    var arguments: [String] = []
    init(stringLiteral value: String) { key = value }
    init(stringInterpolation: StringInterpolation) { key = stringInterpolation.key; arguments = stringInterpolation.arguments }
    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
        mutating func appendLiteral(_ literal: String) { key += literal }
        mutating func appendInterpolation<T>(_ value: T) { key += "{\(arguments.count)}"; arguments.append(String(describing: value)) }
    }
}

@MainActor
func L(_ copy: AppCopy) -> String {
    let template = AppPreferences.shared.language == "zh" ? copy.key : AppTranslations.english[copy.key] ?? copy.key
    // Replace placeholders in a single pass so user-entered {0} stays verbatim.
    let parts = template.components(separatedBy: "{")
    return parts.enumerated().map { index, part in
        guard index > 0 else { return part }
        if let end = part.firstIndex(of: "}"), let number = Int(part[..<end]), copy.arguments.indices.contains(number) {
            return copy.arguments[number] + part[part.index(after: end)...]
        }
        return "{" + part
    }.joined()
}

@MainActor enum AppTranslations {
    nonisolated static let english: [String: String] = {
        guard let url = Bundle.main.url(forResource: "English", withExtension: "json"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }()
    static func label(_ raw: String) -> String { L(AppCopy(stringLiteral: raw)) }
}

extension Emotion { var label: String { AppTranslations.label(rawValue) } }
extension RelationGroup { var label: String { AppTranslations.label(rawValue) } }
extension MemoryKind { var label: String { AppTranslations.label(rawValue) } }
extension AppTab { var label: String { AppTranslations.label(rawValue) } }

struct AppearanceSettingsView: View {
    @Bindable var preferences = AppPreferences.shared
    var body: some View {
        Form {
            Section {
                Picker(L("外观"), selection: $preferences.appearance) {
                    Text(L("跟随系统")).tag("system")
                    Text(L("浅色")).tag("light")
                    Text(L("深色")).tag("dark")
                }.pickerStyle(.inline).accessibilityIdentifier("settings.appearance")
            } header: { Text(L("黑白之间，留一点空间。")) }
            Section {
                Picker(L("语言"), selection: $preferences.language) {
                    Text("English").tag("en").accessibilityIdentifier("language.en")
                    Text(L("简体中文")).tag("zh").accessibilityIdentifier("language.zh")
                }.pickerStyle(.inline).accessibilityIdentifier("settings.language")
            } footer: { Text(L("语言立即生效。你写下的内容保留原文。")) }
        }.navigationTitle(L("外观与语言")).navigationBarTitleDisplayMode(.inline)
    }
}

nonisolated func localizedServiceError(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: "app.language") ?? "en"
    return language == "zh" ? key : AppTranslations.english[key] ?? key
}
