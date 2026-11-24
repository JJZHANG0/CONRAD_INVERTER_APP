import SwiftUI

struct ReflectionLoadingView: View {
    let title: String
    let detail: String
    var cancel: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            BotAvatar(state: "working").frame(width: 220, height: 220)
            Text(title).font(.system(size: 25, weight: .medium)).multilineTextAlignment(.center)
            Text(detail).font(.subheadline).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(5)
            ProgressView().tint(Color.ink).padding(.top, 8)
            Spacer()
            if let cancel { Button(L("返回回答"), action: cancel).font(.subheadline).padding(.bottom, 28) }
        }.padding(.horizontal, 36).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.paper.ignoresSafeArea()).accessibilityIdentifier("reflection.loading")
    }
}
