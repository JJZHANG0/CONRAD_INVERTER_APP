import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "首页", inner = "对内", connections = "对外", profile = "我的"
    var icon: String {
        switch self {
        case .home: "square.grid.2x2"
        case .inner: "circle.dotted.circle"
        case .connections: "point.3.connected.trianglepath.dotted"
        case .profile: "person.crop.circle"
        }
    }
    var caption: String {
        switch self {
        case .home: "HOME"
        case .inner: "INNER"
        case .connections: "CONNECT"
        case .profile: "PROFILE"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .home
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(tab: $tab) }.tag(AppTab.home)
            NavigationStack { InnerView() }.tag(AppTab.inner)
            NavigationStack { ConnectionsView() }.tag(AppTab.connections)
            NavigationStack { ProfileView() }.tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { item in
                    Button {
                        tab = item
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon).font(.system(size: 21, weight: tab == item ? .semibold : .regular))
                            Text(item.label).font(.system(size: 11, weight: tab == item ? .semibold : .regular))
                            Capsule().fill(tab == item ? Color.ink : .clear).frame(width: 14, height: 2)
                        }.foregroundStyle(tab == item ? Color.ink : Color.muted).frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 5)
                    }.accessibilityIdentifier("tab.\(item.caption)")
                }
            }.background(Color.surface).overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 0.5) }
        }
    }
}
