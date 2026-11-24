import SwiftUI

@main
struct INVERTERApp: App {
    @State private var store: AppStore
    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let testURL = URL.temporaryDirectory.appending(path: "inverter-uitest.json")
        if testing && !ProcessInfo.processInfo.arguments.contains("--preserve-ui-data") { try? FileManager.default.removeItem(at: testURL) }
        #if DEBUG
        if UITestCloudTransport.enabled {
            try? SessionVault.save(StoredSession(token: "ui-test-only", expiresAt: Date().addingTimeInterval(3600)), origin: CloudService.productionURL)
        }
        #endif
        _store = State(initialValue: AppStore(fileURL: testing ? testURL : nil))
    }
    var body: some Scene {
        WindowGroup {
            AppRootView().environment(store)
                .preferredColorScheme(AppPreferences.shared.colorScheme)
                .tint(.ink)
                .environment(\.locale, AppPreferences.shared.locale)
                .alert(L("本地存储需要处理"), isPresented: Binding(get: { store.persistenceError != nil }, set: { if !$0 { store.persistenceError = nil } })) {
                    Button(L("重试保存")) { store.save() }
                    Button(L("稍后处理"), role: .cancel) { }
                } message: { Text(store.persistenceError ?? "") }
        }
    }
}
